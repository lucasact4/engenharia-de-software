require "rails_helper"

RSpec.describe "Occurrence posts and verification" do
  let(:admin) { create(:user, :admin) }
  let(:student) { create(:user, display_name: "Estudante", public_profile: true) }
  let(:category) { create(:category) }

  def occurrence(visibility = "internal")
    Alerts::CreateOccurrence.call(actor: student, attributes: { description: "A iluminação da biblioteca está apagada.", category_id: category.id,
      location_source: "manual", location_description: "Biblioteca, térreo", requested_visibility: visibility }, client_request_id: SecureRandom.uuid).alert
  end

  def review(post, decision, reason: nil)
    Publications::Review.call(actor: admin, publication: post, decision: decision, reason: reason,
                             reviewed_content_version: post.content_version, lock_version: post.lock_version)
  end

  def edit(alert)
    Alerts::UpdateContent.call(actor: student, alert: alert, attributes: { description: "Novo relato com informações atualizadas pelo estudante." })
  end

  it "publishes internally without review or duplicated content" do
    alert = occurrence
    post = alert.publication
    expect(post).to have_attributes(author_id: student.id, state: "published", visibility: "internal", review_status: "not_submitted")
    expect(post.body).to eq(alert.description)
    expect(post[:body]).to be_nil
    expect(post[:title]).to be_nil
    expect(PublicationPolicy.new(student, post).show?).to be(true)
    expect(PublicationPolicy.new(nil, post).show?).to be(false)
  end

  it "keeps a public request internal while waiting for approval" do
    post = occurrence("public_external").publication
    expect(post).to have_attributes(state: "published", visibility: "internal", review_status: "pending")
    expect(PublicationPolicy.new(student, post).show?).to be(true)
    expect(PublicationPolicy.new(nil, post).show?).to be(false)
  end

  it "approves the same post immediately without a separate publish step" do
    post = occurrence("public_external").publication
    comment = create(:comment, publication: post, author: student)
    review(post, "approve")
    expect(post.reload).to have_attributes(visibility: "public_external", state: "published", approval_method: "administrator")
    expect(PublicationPolicy.new(nil, post).show?).to be(true)
    expect(post.comments).to include(comment)
    expect(Publication.count).to eq(1)
  end

  it "requires a rejection reason and preserves internal visibility" do
    post = occurrence("public_external").publication
    expect { review(post, "reject", reason: " ") }.to raise_error(ActiveRecord::RecordInvalid)
    review(post.reload, "reject", reason: "Remova os dados pessoais.")
    expect(post.reload).to have_attributes(review_reason: "Remova os dados pessoais.", review_status: "rejected", visibility: "internal", state: "published")
  end

  it "edits the canonical content and resubmits the same identity with interactions preserved" do
    alert = occurrence("public_external")
    post = alert.publication
    student.publication_bookmarks.create!(publication: post)
    review(post, "reject", reason: "Ajuste a descrição.")
    edit(alert)
    expect(post.reload).to have_attributes(review_status: "pending", visibility: "internal", content_version: 2)
    expect(post.body).to eq(alert.reload.description)
    expect(student.publication_bookmarks.exists?(publication: post)).to be(true)
  end

  it "invalidates external approval on edits while keeping the post internal" do
    alert = occurrence("public_external")
    post = alert.publication
    review(post, "approve")
    edit(alert)
    expect(post.reload).to have_attributes(state: "published", visibility: "internal", review_status: "pending")
    expect(PublicationPolicy.new(nil, post).show?).to be(false)
  end

  it "rejects a stale review after the student edits" do
    alert = occurrence("public_external")
    post = alert.publication
    version = post.content_version
    edit(alert)
    expect { Publications::Review.call(actor: admin, publication: post.reload, decision: "approve", reviewed_content_version: version) }.to raise_error(Publications::Review::StaleReview)
  end

  it "publishes verified authors externally and keeps that rule on edits" do
    Users::ChangeVerification.call(actor: admin, user: student, verified: true)
    alert = occurrence("public_external")
    expect(alert.publication).to have_attributes(visibility: "public_external", review_status: "approved", approval_method: "verified_author", reviewed_by_id: nil)
    edit(alert)
    expect(alert.publication).to have_attributes(visibility: "public_external", content_version: 2, reviewed_content_version: 2)
  end

  it "uses the persisted verification state after revocation" do
    Users::ChangeVerification.call(actor: admin, user: student, verified: true)
    alert = occurrence("public_external")
    stale_user = User.find(student.id)
    Users::ChangeVerification.call(actor: admin, user: student, verified: false)
    Alerts::UpdateContent.call(actor: stale_user, alert: alert, attributes: { description: "Relato editado depois da remoção do selo de verificado." })
    expect(alert.publication).to have_attributes(visibility: "internal", review_status: "pending")
  end

  it "does not create a feed post for a private occurrence or a panic" do
    expect(occurrence("restricted").publication).to be_nil
    panic = Alerts::CreatePanic.call(actor: student, attributes: { location_source: "unavailable", location_unavailable_reason: "not_shared" }, client_request_id: SecureRandom.uuid).alert
    expect(panic.publication).to be_nil
  end

  it "lets the author change audience and preserve the same post" do
    alert = occurrence
    id = alert.publication.id
    Alerts::ChangeAudience.call(actor: student, alert: alert, requested_visibility: "public_external")
    expect(alert.publication).to have_attributes(id: id, review_status: "pending")
    Alerts::ChangeAudience.call(actor: student, alert: alert, requested_visibility: "restricted")
    expect(alert.publication).to be_withdrawn
    expect(PublicationPolicy.new(student, alert.publication).show?).to be(false)
  end

  it "does not let a verified author bypass administrative restrictions" do
    Users::ChangeVerification.call(actor: admin, user: student, verified: true)
    alert = occurrence("public_external")
    Alerts::Restrict.call(actor: admin, alert: alert, reason: "Proteção de dados pessoais")
    edit(alert)
    expect(alert.publication).to be_withdrawn
    expect { Alerts::ChangeAudience.call(actor: student, alert: alert, requested_visibility: "public_external") }.to raise_error(Pundit::NotAuthorizedError)
  end

  it "does not let editing reactivate a moderated post" do
    alert = occurrence("public_external")
    post = alert.publication
    Publications::Withdraw.call(actor: admin, publication: post, reason: "Conteúdo inadequado")
    edit(alert)
    expect(post.reload).to have_attributes(state: "withdrawn", moderation_blocked: true)
  end

  it "rolls back both records if publication persistence fails" do
    allow(AuditEvent).to receive(:record!).and_call_original
    allow(AuditEvent).to receive(:record!).with(hash_including(action: "publication.occurrence_synced")).and_raise("falha simulada")
    expect { occurrence }.to raise_error("falha simulada")
    expect(Alert.count).to eq(0)
    expect(Publication.count).to eq(0)
  end

  it "does not let the administrator duplicate or edit an occurrence post" do
    alert = occurrence
    expect { Publications::Create.call(actor: admin, alert: alert, attributes: { kind: "occurrence" }) }.to raise_error(Pundit::NotAuthorizedError)
    expect { Publications::Update.call(actor: admin, publication: alert.publication, attributes: { body: "Texto duplicado indevido." }) }.to raise_error(Pundit::NotAuthorizedError)
  end

  it "only administrators can grant the badge and never through ordinary profile updates" do
    expect { Users::ChangeVerification.call(actor: student, user: student, verified: true) }.to raise_error(Pundit::NotAuthorizedError)
    Users::UpdateProfile.call(actor: student, user: student, attributes: { verified_at: Time.current, admin: true, display_name: "Estudante atualizado" })
    expect(student.reload).not_to be_verified
    expect(student).not_to be_admin
  end
  it "invalidates external approval after removing a source photo" do
    alert = Alerts::CreateOccurrence.call(actor: student, attributes: occurrence_attributes(requested_visibility: "public_external"), photos: [ photo, photo ]).alert
    post = alert.publication
    review(post, "approve")
    Alerts::RemovePhoto.call(actor: student, alert: alert, attachment_id: alert.photos.first.id)
    expect(post.reload).to have_attributes(content_version: 2, visibility: "internal", review_status: "pending")
    expect(post.feed_photos.size).to eq(1)
  end
  it "keeps a description-derived title only for legacy callers that omit the title key" do
    alert = Alerts::CreateOccurrence.call(actor: student, attributes: occurrence_attributes(description: "a        b").except(:title)).alert
    expect(alert.publication.body).to eq("a        b")
    expect(alert.title.length).to be >= Alert::TITLE_LENGTH.min
    Alerts::UpdateContent.call(actor: student, alert: alert, attributes: { description: "b        c" })
    expect(alert.reload.description).to eq("b        c")
  end
end
