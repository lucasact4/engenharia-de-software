require "rails_helper"

# Prova que o banco protege as regras fundamentais mesmo quando as validações do model são
# ignoradas (save(validate: false), update_columns ou concorrência).
RSpec.describe "Database constraints" do
  def violation
    raise_error(ActiveRecord::StatementInvalid)
  end

  let(:user) { create(:user) }
  let(:category) { create(:category) }

  describe "alerts" do
    let(:alert) { create(:alert, author: user, category: category) }

    it "rejects an occurrence without required fields" do
      expect { alert.update_columns(title: nil) }.to violation
      expect { alert.update_columns(category_id: nil) }.to violation
      expect { alert.update_columns(location_source: "unavailable", latitude: nil, longitude: nil) }.to violation
    end

    it "rejects public or inconsistent operational visibility" do
      expect { alert.update_columns(visibility: "public_external") }.to violation
      expect { alert.update_columns(requested_visibility: "public_external") }.to violation
    end

    it "rejects invalid coordinates and incomplete pairs" do
      expect { alert.update_columns(latitude: 95) }.to violation
      expect { alert.update_columns(longitude: nil) }.to violation
      expect { alert.update_columns(location_accuracy_meters: -3) }.to violation
    end

    it "keeps panic restricted and with a client key" do
      panic = create(:alert, :panic, author: user)

      expect { panic.update_columns(requested_visibility: "internal", visibility: "internal") }.to violation
      expect { panic.update_columns(client_request_id: nil) }.to violation
    end

    it "enforces closure consistency and duplicate references" do
      expect { alert.update_columns(status: "closed") }.to violation
      expect { alert.update_columns(status: "resolved") }.to violation
      expect { alert.update_columns(closure_reason: "invalid") }.to violation
      expect { alert.update_columns(status: "closed", closed_at: Time.current, closure_reason: "duplicate") }.to violation
      expect { alert.update_columns(status: "closed", closed_at: Time.current, closure_reason: "duplicate", duplicate_of_id: alert.id) }.to violation
    end

    it "rejects unknown enum values" do
      expect { alert.update_columns(status: "archived") }.to violation
      expect { alert.update_columns(priority: "medium") }.to violation
      expect { alert.update_columns(kind: "incident") }.to violation
    end

    it "keeps protocol and client request keys unique" do
      other = create(:alert, author: user)
      expect { other.update_columns(protocol: alert.protocol) }.to raise_error(ActiveRecord::RecordNotUnique)

      first = create(:alert, :panic, author: user)
      second = build(:alert, :panic, author: user, client_request_id: first.client_request_id, protocol: "SGU-AAAAA-BBBBB")
      expect { second.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      expect(build(:alert, :panic, client_request_id: first.client_request_id).save).to be(true)
    end

    it "enforces foreign keys" do
      expect { alert.update_columns(category_id: 999_999) }.to raise_error(ActiveRecord::InvalidForeignKey)
      expect { alert.update_columns(author_id: 999_999) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe "publications" do
    it "allows at most one publication per alert" do
      alert = create(:alert, :public_request)
      create(:publication, kind: "occurrence", alert: alert)
      second = build(:publication, kind: "occurrence", alert: alert, author: create(:user, :admin))

      second[:title] = second[:body] = nil
      expect { second.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects published content without approval of the current version" do
      publication = create(:publication)

      expect { publication.update_columns(state: "published", published_at: Time.current) }.to violation

      approved = create(:publication, :approved)
      expect { approved.update_columns(content_version: 2, state: "published", published_at: Time.current) }.to violation
    end

    it "requires expiration for published notices and an alert only for occurrence kind" do
      notice = create(:publication, :approved, kind: "notice")

      expect { notice.update_columns(state: "published", published_at: Time.current) }.to violation
      expect { create(:publication).update_columns(alert_id: create(:alert).id) }.to violation
      expect { create(:publication).update_columns(kind: "occurrence") }.to violation
    end
  end

  describe "social tables" do
    let(:publication) { create(:publication, :published) }

    it "keeps likes, bookmarks, subscriptions and follows unique" do
      PublicationLike.create!(user: user, publication: publication)
      PublicationBookmark.create!(user: user, publication: publication)
      PublicationSubscription.create!(user: user, publication: publication)
      followed = create(:user, :public_profile)
      UserFollow.create!(follower: user, followed: followed)

      expect { PublicationLike.new(user: user, publication: publication).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      expect { PublicationBookmark.new(user: user, publication: publication).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      expect { PublicationSubscription.new(user: user, publication: publication).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      expect { UserFollow.new(follower: user, followed: followed).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects self follow" do
      expect { UserFollow.new(follower: user, followed: user).save!(validate: false) }.to violation
    end

    it "requires exactly one report target and deduplicates per reporter" do
      comment = create(:comment, publication: publication)

      expect { ContentReport.new(reporter: user, reason: "spam").save!(validate: false) }.to violation
      expect { ContentReport.new(reporter: user, reason: "spam", publication: publication, comment: comment).save!(validate: false) }.to violation
      expect { ContentReport.new(reporter: user, reason: "other", publication: publication).save!(validate: false) }.to violation

      ContentReport.create!(reporter: user, reason: "spam", publication: publication)
      expect { ContentReport.new(reporter: user, reason: "privacy", publication: publication).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects blank comments and self parent" do
      comment = create(:comment, publication: publication)

      expect { comment.update_columns(body: "   ") }.to violation
      expect { comment.update_columns(parent_id: comment.id) }.to violation
    end
  end

  describe "roles and users" do
    it "keeps role grants unique and usernames lowercase" do
      role = create(:role)
      UserRole.create!(user: user, role: role)

      expect { UserRole.new(user: user, role: role).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      expect {
        ActiveRecord::Base.connection.execute("UPDATE users SET username = 'MAIUSCULO' WHERE id = #{user.id}")
      }.to violation
    end
  end

  it "requires an actor for non-technical audit events" do
    expect {
      AuditEvent.insert_all([ { action: "alert.status_changed", subject_type: "Alert", subject_id: 1,
                                changeset: {}, metadata: {}, created_at: Time.current } ])
    }.to violation
  end
end
