require "rails_helper"
require "open3"

# Migrações reais em SQLite temporário; o teste confirma o destino antes de alterar dados.
RSpec.describe "Card #6 migrations on a legacy database" do
  let(:dir) { Rails.root.join("tmp/migration_spec_#{SecureRandom.hex(4)}") }
  let(:db_path) { dir.join("legacy.sqlite3") }
  let(:env) { { "RAILS_ENV" => "test", "DATABASE_URL" => "sqlite3:#{db_path}", "SCHEMA" => dir.join("schema.rb").to_s } }
  let(:before_encryption) { "20261107120000" }

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

  def normalize_schema(source)
    source.gsub(/(  create_table .*? do \|t\|\n)(.*?)(  end)/m) do
      header, body, footer = Regexp.last_match.captures
      declarations, remaining_lines = body.lines.partition { |line| line.match?(/^\s+t\./) }
      "#{header}#{declarations.sort.join}#{remaining_lines.join}#{footer}"
    end
  end

  it "recovers previous administrative restrictions without undoing a later release" do
    rails("db:migrate", "VERSION=20261001120700", schema: dir.join("before_block.rb"))
    rails("runner", <<~RUBY)
      ActiveRecord::Encryption.without_encryption do
      author, admin = User.insert_all!([ { email_address: "historico@example.test", password_digest: "digest", admin: false },
                                         { email_address: "admin@example.test", password_digest: "digest", admin: true } ], returning: %w[id]).rows.flatten.map { |id| User.find(id) }
      attributes = { kind: "occurrence", author: author, title: "Ocorrência histórica", description: "Texto válido da ocorrência histórica.",
                     category: Category.first, location_source: "gps", latitude: -8, longitude: -34, reported_severity: "low",
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
      # Fixture histórica anterior à caixa de notificações, sem callbacks da aplicação atual.
      Comment.insert_all!([{ publication_id: publication_id, author_id: author.id, body: "Comentário histórico" }])
      PublicationLike.insert_all!([{ publication_id: publication_id, user_id: author.id }])
      legacy_events = [
        *[blocked, released].map do |alert|
          { actor_id: admin.id, action: "alert.restricted", subject_type: "Alert", subject_id: alert.id,
            reason: "Dados pessoais", changeset: {}, metadata: {}, created_at: Time.current }
        end,
        { actor_id: admin.id, action: "alert.audience_changed", subject_type: "Alert", subject_id: released.id,
          reason: "Revisado", changeset: {}, metadata: {}, created_at: Time.current }
      ]
      AuditEvent.insert_all!(legacy_events)
      end
    RUBY

    # A criptografia de dados pessoais é irreversível; o teste de ida e volta para antes dela.
    rails("db:migrate", "VERSION=#{before_encryption}", schema: dir.join("after_block.rb"))
    expect(query("SELECT publication_blocked FROM alerts ORDER BY id")).to eq([ [ 1 ], [ 0 ], [ 0 ] ])
    expect(query("SELECT state FROM publications")).to eq([ [ "withdrawn" ] ])
    expect(query("SELECT title, body FROM publications")).to eq([ [ nil, nil ] ])
    expect(query("SELECT count(*) FROM audit_events WHERE action = 'system.occurrence_unified'")).to eq([ [ 1 ] ])
    expect(query("SELECT count(*) FROM comments")).to eq([ [ 1 ] ])
    expect(query("SELECT count(*) FROM publication_likes")).to eq([ [ 1 ] ])
    expect(rails("runner", "print PublicationPolicy::Scope.new(nil, Publication.all).resolve.count").strip).to eq("0")
    expect(query("PRAGMA integrity_check")).to eq([ [ "ok" ] ])
    expect(query("PRAGMA foreign_key_check")).to be_empty

    # Volta a uma versão explícita: migrações posteriores (ex.: perfis da apresentação) também são desfeitas.
    rails("db:migrate", "VERSION=20261001120700", schema: dir.join("before_block_again.rb"))
    expect(query("SELECT count(*) FROM alerts")).to eq([ [ 3 ] ])
    expect(query("SELECT count(*) FROM publications")).to eq([ [ 1 ] ])
    expect(query("SELECT count(*) FROM comments")).to eq([ [ 1 ] ])
    expect(query("SELECT count(*) FROM publication_likes")).to eq([ [ 1 ] ])
    expect(query("SELECT title, body, author_id, state FROM publications")).to eq([ [ "Publicação histórica", "Conteúdo editorial histórico.", 2, "published" ] ])
    expect(dir.join("before_block_again.rb").read).to eq(dir.join("before_block.rb").read)
  end

  it "preserves legacy accounts and sessions, removes the example table and matches the clean schema" do
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

    # Ida e volta até a última versão antes da criptografia, que é irreversível.
    rails("db:migrate", "VERSION=#{before_encryption}", schema: dir.join("before_encryption.rb"))

    expect(query(snapshot)).to eq(before_users)
    expect(query("SELECT * FROM sessions")).to eq(before_sessions)
    expect(query("SELECT name FROM sqlite_master WHERE type = 'table'").flatten).not_to include("dogs")
    expect(query("SELECT registration_status, registration_role_code, email_verified_at FROM users").uniq).to eq([ [ "approved", nil, nil ] ])
    expect(query("SELECT display_name, username, bio, public_profile FROM users").uniq).to eq([ [ nil, nil, nil, 0 ] ])
    expect(query("SELECT count(*) FROM user_roles")).to eq([ [ 0 ] ])
    expect(query("SELECT count(*) FROM roles")).to eq([ [ 7 ] ])
    expect(query("SELECT count(*) FROM categories")).to eq([ [ 7 ] ])
    expect(query("SELECT count(*) FROM alerts")).to eq([ [ 0 ] ])
    expect(query("PRAGMA foreign_key_check")).to be_empty

    rails("db:migrate", "VERSION=20260914150000", schema: dir.join("rolled_back.rb"))
    tables = query("SELECT name FROM sqlite_master WHERE type = 'table'").flatten
    expect(tables).not_to include("alerts", "roles", "active_storage_blobs", "presentation_profiles")
    expect(query(snapshot)).to eq(before_users)
    strip_version = ->(text) { text.sub(/define\(version: [\d_]+\)/, "") }
    expect(strip_version.call(dir.join("rolled_back.rb").read)).to eq(strip_version.call(file_fixture("schema_before_card6.txt").read))

    # Na versão atual, contas e sessões ficam criptografadas.
    rails("db:migrate", schema: dir.join("after.rb"))
    expect(normalize_schema(dir.join("after.rb").read)).to eq(normalize_schema(Rails.root.join("db/schema.rb").read))
    expect(query("SELECT email_address FROM users").flatten).to all(start_with("{"))
    plain = "SELECT id, password_digest, admin, deleted_at, created_at, updated_at FROM users ORDER BY id"
    expect(query(plain)).to eq(before_users.map { |row| row.values_at(0, 2, 3, 4, 5, 6) })
    decrypted = rails("runner", "print User.order(:id).pluck(:email_address).join(','), ';', Session.pluck(:ip_address, :user_agent).flatten.join(',')")
    expect(decrypted.strip.lines.last).to eq("#{before_users.map(&:second).join(',')};127.0.0.1,Teste")

    output, status = Open3.capture2e(env, "bin/rails", "db:migrate", "VERSION=#{before_encryption}", chdir: Rails.root.to_s)
    expect(status).not_to be_success
    expect(output).to include("IrreversibleMigration")
    # A migração reversível do Google é desfeita antes de atingir a barreira.
    expect(query("SELECT name FROM pragma_table_info('users') WHERE name = 'google_subject'")).to be_empty
    expect(query("SELECT email_address FROM users").flatten).to all(start_with("{"))
  end
  it "refuses a rollback with descriptive locations before changing the database" do
    rails("db:migrate", "VERSION=#{before_encryption}", schema: dir.join("current.rb"))
    rails("runner", <<~RUBY)
      ActiveRecord::Encryption.without_encryption do
        user = User.find(User.insert_all!([ { email_address: "rollback@example.test", password_digest: "digest" } ], returning: %w[id]).rows.first.first)
        alert = Alert.create!(author: user, kind: "occurrence", title: "Relato para rollback", description: "Relato de teste para o rollback seguro.",
          category: Category.where(requires_details: false).first, location_source: "manual", location_description: "Biblioteca, térreo",
          reported_severity: "low", requested_visibility: "internal", visibility: "internal")
        Publication.insert_all!([{ alert_id: alert.id, author_id: user.id, kind: "occurrence", visibility: "internal",
                                   state: "published", review_status: "not_submitted", content_version: 1, comments_enabled: true,
                                   published_at: Time.current, created_at: Time.current, updated_at: Time.current }])
      end
    RUBY
    output, status = Open3.capture2e(env, "bin/rails", "db:migrate", "VERSION=20261003100100", chdir: Rails.root.to_s)
    expect(status).not_to be_success
    expect(output).to include("há locais descritivos")
    expect(query("SELECT max(version) FROM schema_migrations")).to eq([ [ "20261003120000" ] ])
    expect(query("SELECT location_description FROM alerts")).to eq([ [ "Biblioteca, térreo" ] ])
    expect(query("SELECT state, title, body FROM publications")).to eq([ [ "published", nil, nil ] ])
    expect(query("PRAGMA integrity_check")).to eq([ [ "ok" ] ])
  end
  it "refuses map rollback before changing the schema or losing photo order" do
    rails("db:migrate", "VERSION=#{before_encryption}")
    rails("runner", <<~RUBY)
      ActiveRecord::Encryption.without_encryption do
        author = User.find(User.insert_all!([ { email_address: "mapa@example.test", password_digest: "digest" } ], returning: %w[id]).rows.first.first)
        Alert.create!(author: author, kind: "occurrence", title: "Ponto no mapa", description: "Local escolhido manualmente no mapa.",
                      category: Category.first, location_source: "map", latitude: -8, longitude: -34, reported_severity: "low",
                      requested_visibility: "restricted", visibility: "restricted")
      end
    RUBY
    output, status = Open3.capture2e(env, "bin/rails", "db:migrate", "VERSION=20261003120000", chdir: Rails.root.to_s)
    expect(status).not_to be_success
    expect(output).to include("há pontos selecionados no mapa")
    expect(query("SELECT location_source, photo_order FROM alerts")).to eq([ [ "map", "[]" ] ])
    expect(query("SELECT max(version) FROM schema_migrations")).to eq([ [ "20261003180000" ] ])
    expect(query("PRAGMA integrity_check")).to eq([ [ "ok" ] ])
  end
end
