require "rails_helper"
require "open3"

# Migrações reais em SQLite temporário; o teste confirma o destino antes de alterar dados.
RSpec.describe "Card #6 migrations on a legacy database" do
  let(:dir) { Rails.root.join("tmp/migration_spec_#{SecureRandom.hex(4)}") }
  let(:db_path) { dir.join("legacy.sqlite3") }
  let(:env) { { "RAILS_ENV" => "test", "DATABASE_URL" => "sqlite3:#{db_path}", "SCHEMA" => dir.join("schema.rb").to_s } }

  before { FileUtils.mkdir_p(dir) }
  after { FileUtils.rm_rf(dir) }

  def rails(*args, schema: nil)
    command_env = schema ? env.merge("SCHEMA" => schema.to_s) : env
    output, status = Open3.capture2e(command_env, "bin/rails", *args, chdir: Rails.root.to_s)
    raise "bin/rails #{args.join(' ')} falhou:\n#{output}" unless status.success?

    output
  end

  def query(sql)
    SQLite3::Database.new(db_path.to_s) { |db| return db.execute(sql) }
  end

  it "recovers previous administrative restrictions without undoing a later release" do
    rails("db:migrate", "VERSION=20261001120700", schema: dir.join("before_block.rb"))
    rails("runner", <<~RUBY)
      author = User.create!(email_address: "historico@example.test", password: "senha-ficticia")
      admin = User.create!(email_address: "admin@example.test", password: "senha-ficticia", admin: true)
      attributes = { kind: "occurrence", author: author, title: "Ocorrência histórica", description: "Texto válido da ocorrência histórica.",
                     category: Category.first, location_source: "gps", latitude: -8, longitude: -34,
                     requested_visibility: "public_external", visibility: "restricted" }
      blocked = Alert.create!(attributes)
      released = Alert.create!(attributes)
      Alert.create!(attributes)
      publication_id = Publication.insert_all!([{
        alert_id: blocked.id, author_id: admin.id, kind: "occurrence", title: "Publicação histórica",
        body: "Conteúdo editorial histórico.", visibility: "public_external", state: "published",
        review_status: "approved", content_version: 1, reviewed_content_version: 1,
        reviewed_by_id: admin.id, reviewed_at: Time.current, published_at: Time.current
      }], returning: %w[id]).rows.first.first
      Comment.create!(publication_id: publication_id, author: author, body: "Comentário histórico")
      [blocked, released].each do |alert|
        AuditEvent.record!(actor: admin, action: "alert.restricted", subject: alert, reason: "Dados pessoais")
      end
      AuditEvent.record!(actor: admin, action: "alert.audience_changed", subject: released, reason: "Revisado")
    RUBY

    rails("db:migrate", schema: dir.join("after_block.rb"))
    expect(query("SELECT publication_blocked FROM alerts ORDER BY id")).to eq([ [ 1 ], [ 0 ], [ 0 ] ])
    expect(query("SELECT state FROM publications")).to eq([ [ "published" ] ])
    expect(query("SELECT count(*) FROM comments")).to eq([ [ 1 ] ])
    expect(rails("runner", "print PublicationPolicy::Scope.new(nil, Publication.all).resolve.count").strip).to eq("0")
    expect(query("PRAGMA integrity_check")).to eq([ [ "ok" ] ])
    expect(query("PRAGMA foreign_key_check")).to be_empty

    # Volta a uma versão explícita: migrações posteriores (ex.: perfis da apresentação) também são desfeitas.
    rails("db:migrate", "VERSION=20261001120700", schema: dir.join("before_block_again.rb"))
    expect(query("SELECT count(*) FROM alerts")).to eq([ [ 3 ] ])
    expect(query("SELECT count(*) FROM publications")).to eq([ [ 1 ] ])
    expect(query("SELECT count(*) FROM comments")).to eq([ [ 1 ] ])
    expect(dir.join("before_block_again.rb").read).to eq(dir.join("before_block.rb").read)
  end

  it "preserves users, admin, deactivated accounts, sessions and dogs, and matches the clean schema" do
    target = rails("runner", "print ActiveRecord::Base.connection_db_config.database")
    expect(target.strip.lines.last).to eq(db_path.to_s)

    rails("db:schema:load", schema: file_fixture("schema_before_card6.txt"))
    legacy = <<~SQL
      INSERT INTO users (email_address, password_digest, admin, deleted_at, created_at, updated_at) VALUES
        ('admin.ficticio@example.test', 'digest-a', 1, NULL, '2026-09-01 10:00:00', '2026-09-01 10:00:00'),
        ('comum.ficticio@example.test', 'digest-b', 0, NULL, '2026-09-02 10:00:00', '2026-09-02 10:00:00'),
        ('desativado.ficticio@example.test', 'digest-c', 0, '2026-09-20 10:00:00', '2026-09-03 10:00:00', '2026-09-20 10:00:00');
      INSERT INTO sessions (user_id, ip_address, user_agent, created_at, updated_at) VALUES (1, '127.0.0.1', 'Teste', '2026-09-10', '2026-09-10');
      INSERT INTO dogs (name, age, deleted_at, created_at, updated_at) VALUES ('Rex', 3, NULL, '2026-09-15', '2026-09-15');
    SQL
    SQLite3::Database.new(db_path.to_s) { |db| db.execute_batch(legacy) }
    snapshot = "SELECT id, email_address, password_digest, admin, deleted_at, created_at, updated_at FROM users ORDER BY id"
    before_users = query(snapshot)
    before_sessions = query("SELECT * FROM sessions")
    before_dogs = query("SELECT * FROM dogs")

    rails("db:migrate", schema: dir.join("after.rb"))

    expect(query(snapshot)).to eq(before_users)
    expect(query("SELECT * FROM sessions")).to eq(before_sessions)
    expect(query("SELECT * FROM dogs")).to eq(before_dogs)
    expect(query("SELECT display_name, username, bio, public_profile FROM users").uniq).to eq([ [ nil, nil, nil, 0 ] ])
    expect(query("SELECT count(*) FROM user_roles")).to eq([ [ 0 ] ])
    expect(query("SELECT count(*) FROM roles")).to eq([ [ 7 ] ])
    expect(query("SELECT count(*) FROM categories")).to eq([ [ 7 ] ])
    expect(query("SELECT count(*) FROM alerts")).to eq([ [ 0 ] ])
    expect(query("PRAGMA foreign_key_check")).to be_empty
    expect(dir.join("after.rb").read).to eq(Rails.root.join("db/schema.rb").read)

    rails("db:migrate", "VERSION=20260914150000", schema: dir.join("rolled_back.rb"))
    tables = query("SELECT name FROM sqlite_master WHERE type = 'table'").flatten
    expect(tables).not_to include("alerts", "roles", "active_storage_blobs", "presentation_profiles")
    expect(query(snapshot)).to eq(before_users)
    strip_version = ->(text) { text.sub(/define\(version: [\d_]+\)/, "") }
    expect(strip_version.call(dir.join("rolled_back.rb").read)).to eq(strip_version.call(file_fixture("schema_before_card6.txt").read))
  end
end
