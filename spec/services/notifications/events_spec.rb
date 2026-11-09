require "rails_helper"

RSpec.describe Notifications::Events do
  let(:author) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:reader) { create(:user) }

  it "persists each real status transition for its author without text-edit duplicates" do
    alert = create(:alert, author: author)
    %w[triaging in_progress resolved closed].each do |status|
      Alerts::Transition.call(actor: admin, alert: alert, to: status)
    end
    notices = author.notifications.where(kind: "alert_status")
    expect(notices.count).to eq(4)
    expect(notices.last.message).to include("Encerrada", alert.protocol)
    expect(notices.last.read_at).to be_nil
    alert.update!(description: "Descrição corrigida sem mudança na situação.")
    expect(notices.count).to eq(4)
    described_class.alert_updated(alert)
    expect(notices.count).to eq(4)
  end

  it "keeps reopened and repeated statuses as separate events" do
    alert = create(:alert, author: author, status: "in_progress")
    Alerts::Transition.call(actor: admin, alert: alert, to: "resolved")
    Alerts::Transition.call(actor: admin, alert: alert, to: "in_progress", reason: "Novo problema")
    Alerts::Transition.call(actor: admin, alert: alert, to: "resolved")
    described_class.alert_updated(alert)
    expect(author.notifications.where(kind: "alert_status").count).to eq(3)
  end

  it "does not persist notifications when the enclosing action rolls back" do
    admin
    expect do
      Alert.transaction do
        create(:alert, :panic, author: author)
        raise ActiveRecord::Rollback
      end
    end.not_to change(Notification, :count)
    expect(Alert.panic).to be_empty
  end

  it "rolls back the domain action when notification persistence fails" do
    admin
    allow(Notification).to receive(:create_or_find_by!).and_raise(ActiveRecord::RecordInvalid)
    expect { create(:alert, :panic, author: author) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(Alert.panic).to be_empty
  end

  it "notifies only active administrators and active security, once per panic replay" do
    admin
    security = create(:user)
    grant_role(security, :security)
    grant_role(admin, :security)
    coordinator = create(:user)
    grant_role(coordinator, :coordination)
    inactive = create(:user, :admin, :inactive)
    disabled_role = create(:user)
    role = grant_role(disabled_role, :security)
    role.update!(active: false)
    role.update!(active: true)
    disabled_role.user_roles.destroy_all
    request_id = SecureRandom.uuid
    2.times { Alerts::CreatePanic.call(actor: author, client_request_id: request_id) }
    expect(Notification.where(kind: "panic").pluck(:user_id)).to contain_exactly(admin.id, security.id)
    expect(inactive.notifications).to be_empty
    expect(coordinator.notifications).to be_empty
    expect(disabled_role.notifications).to be_empty
  end

  it "deduplicates repeat fanout with a database uniqueness constraint" do
    admin
    panic = create(:alert, :panic, author: author)
    expect { described_class.alert_created(panic) }.not_to change(Notification, :count)
    original = admin.notifications.sole
    expect { Notification.insert_all!([ original.attributes.except("id") ]) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "sends comments and replies to unique conversation authors, excluding the actor" do
    publication = create(:publication, :published, author: author)
    root = Comments::Create.call(actor: reader, publication: publication, body: "Uma observação")
    expect(author.notifications.where(kind: "comment").count).to eq(1)
    expect(reader.notifications).to be_empty
    Comments::Create.call(actor: admin, publication: publication, body: "Uma resposta", parent: root)
    expect(author.notifications.where(kind: "comment").count).to eq(2)
    expect(reader.notifications.where(kind: "comment").count).to eq(1)
    Comments::Create.call(actor: author, publication: publication, body: "Resposta própria", parent: root)
    expect(author.notifications.where(kind: "comment").count).to eq(2)
  end

  it "notifies likes on publications and comments without self-notices or re-like spam" do
    publication = create(:publication, :published, author: author)
    comment = create(:comment, publication: publication, author: author)
    Social::Interactions.add_to_publication(actor: author, publication: publication, kind: :like)
    Social::Interactions.like_comment(actor: author, comment: comment)
    expect(author.notifications).to be_empty
    2.times do
      Social::Interactions.add_to_publication(actor: reader, publication: publication, kind: :like)
      Social::Interactions.like_comment(actor: reader, comment: comment)
    end
    Social::Interactions.remove_from_publication(actor: reader, publication: publication, kind: :like)
    Social::Interactions.unlike_comment(actor: reader, comment: comment)
    Social::Interactions.add_to_publication(actor: reader, publication: publication, kind: :like)
    Social::Interactions.like_comment(actor: reader, comment: comment)
    expect(author.notifications.where(kind: "like").count).to eq(2)
  end

  it "notifies admins about submissions, new source versions and later resubmissions" do
    admin
    alert = create(:alert, :public_request, author: author)
    publication = Publications::SyncOccurrence.call(actor: author, alert: alert)
    expect(admin.notifications.where(kind: "publication_pending").count).to eq(1)
    Publications::SyncOccurrence.call(actor: author, alert: alert)
    expect(admin.notifications.where(kind: "publication_pending").count).to eq(1)
    Publications::SyncOccurrence.call(actor: author, alert: alert, content_changed: true)
    expect(admin.notifications.where(kind: "publication_pending").count).to eq(2)
    publication.reload
    Publications::Review.call(actor: admin, publication: publication, decision: "reject", reviewed_content_version: publication.content_version, reason: "Revisar conteúdo")
    Publications::SyncOccurrence.call(actor: author, alert: alert, request_external: true)
    expect(admin.notifications.where(kind: "publication_pending").count).to eq(3)
    expect(author.notifications.where(kind: "publication_status").count).to be >= 1
  end

  it "notifies admins of reports and reopenings without exposing details to security" do
    admin
    security = create(:user)
    grant_role(security, :security)
    publication = create(:publication, :published, author: author)
    report = ContentReports::Create.call(actor: reader, target: publication, reason: "spam")
    expect(admin.notifications.where(kind: "content_report").count).to eq(1)
    described_class.report_saved(report)
    expect(admin.notifications.where(kind: "content_report").count).to eq(1)
    ContentReports::Review.call(actor: admin, report: report, decision: "dismissed", notes: "Sem infração")
    freeze_time do
      ContentReports::Reopen.call(actor: reader, report: report, details: "Nova informação sobre o conteúdo")
      ContentReports::Review.call(actor: admin, report: report, decision: "dismissed", notes: "Sem infração")
      ContentReports::Reopen.call(actor: reader, report: report, details: "Outra informação sobre o conteúdo")
    end
    expect(admin.notifications.where(kind: "content_report").count).to eq(3)
    expect(security.notifications).to be_empty
    expect(author.notifications.where(kind: "content_report")).to be_empty
  end

  it "does not notify pending, rejected or deactivated accounts" do
    inactive = create(:user, :inactive)
    pending = create(:user, registration_status: "pending")
    rejected = create(:user, registration_status: "rejected")
    [ inactive, pending, rejected ].each do |user|
      publication = create(:publication, :published, author: user)
      create(:comment, publication: publication)
    end
    expect(Notification).not_to exist
  end

  it "does not deliver panic to a disabled security role or duplicate an administrator with both roles" do
    security = create(:user)
    role = grant_role(security, :security)
    grant_role(admin, :security)
    role.update!(active: false)
    create(:alert, :panic, author: author)
    expect(security.notifications).to be_empty
    expect(admin.notifications.where(kind: "panic").count).to eq(1)
  end
end
