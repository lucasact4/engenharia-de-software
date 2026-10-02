require "rails_helper"

RSpec.describe "Publication editorial workflow" do
  let(:admin) { create(:user, :admin) }
  let(:reader) { create(:user) }
  let(:source) { create(:alert, :public_request) }

  def create_publication(**attributes)
    Publications::Create.call(
      actor: admin, alert: attributes.delete(:alert),
      attributes: { kind: "news", title: "Obra na entrada", body: "A entrada principal terá obras nesta semana.",
                    visibility: "public_external" }.merge(attributes)
    )
  end

  def approve(publication, version: publication.content_version)
    Publications::Submit.call(actor: admin, publication: publication)
    Publications::Review.call(actor: admin, publication: publication, decision: "approve", reviewed_content_version: version)
  end

  def public_scope
    PublicationPolicy::Scope.new(nil, Publication.all).resolve
  end

  it "requires submission, approval and a separate publish step" do
    publication = create_publication
    approve(publication)

    expect(publication).to be_review_approved
    expect(publication).to be_draft
    expect(public_scope).to be_empty

    Publications::Publish.call(actor: admin, publication: publication)
    expect(public_scope).to contain_exactly(publication)
    expect(AuditEvent.for_subject(publication).pluck(:action))
      .to eq(%w[publication.created publication.submitted publication.approved publication.published])
  end

  it "does not let coordination, security or regular users act editorially" do
    coordinator = create(:user).tap { |user| grant_role(user, :coordination) }
    guard = create(:user).tap { |user| grant_role(user, :security) }

    [ coordinator, guard, reader ].each do |actor|
      expect {
        Publications::Create.call(actor: actor, attributes: { kind: "news", title: "Título válido", body: "Texto editorial válido", visibility: "internal" })
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  it "invalidates approval and takes content offline when relevant fields change" do
    publication = create_publication
    approve(publication)
    Publications::Publish.call(actor: admin, publication: publication)

    Publications::Update.call(actor: admin, publication: publication, attributes: { body: "Texto alterado depois da aprovação." })

    expect(publication.reload).to have_attributes(state: "draft", review_status: "not_submitted", content_version: 2)
    expect(public_scope).to be_empty
    expect { Publications::Publish.call(actor: admin, publication: publication) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "never lets an old approval authorize new text (edit/review race)" do
    publication = create_publication
    Publications::Submit.call(actor: admin, publication: publication)
    version_read_by_reviewer = publication.content_version

    Publications::Update.call(actor: admin, publication: Publication.find(publication.id), attributes: { title: "Título trocado" })
    Publications::Submit.call(actor: admin, publication: publication.reload)

    expect {
      Publications::Review.call(actor: admin, publication: publication, decision: "approve",
                                reviewed_content_version: version_read_by_reviewer)
    }.to raise_error(Publications::Review::StaleReview)
  end

  it "detects concurrent writes through lock_version" do
    publication = create_publication
    stale = Publication.find(publication.id)
    Publications::Update.call(actor: admin, publication: publication, attributes: { title: "Primeira edição" })

    expect {
      Publications::Update.call(actor: admin, publication: stale, attributes: { title: "Edição concorrente" })
    }.to raise_error(ActiveRecord::StaleObjectError)
  end

  it "requires a compatible occurrence source and never accepts restricted alerts" do
    expect { create_publication(kind: "occurrence", alert: create(:alert, :restricted)) }
      .to raise_error(ActiveRecord::RecordInvalid)
    expect { create_publication(kind: "occurrence", alert: create(:alert), visibility: "public_external") }
      .to raise_error(ActiveRecord::RecordInvalid)

    publication = create_publication(kind: "occurrence", alert: source)
    expect(publication.body).not_to eq(source.description)
  end

  it "hides notices after expiration even without a scheduled job" do
    notice = create_publication(kind: "notice", expires_at: 2.hours.from_now)
    approve(notice)
    Publications::Publish.call(actor: admin, publication: notice)
    expect(public_scope).to include(notice)

    travel 3.hours do
      expect(public_scope).not_to include(notice)
      expect(PublicationPolicy.new(nil, notice).show?).to be(false)
    end
  end

  it "requires notices to expire in the future when published" do
    notice = create_publication(kind: "notice")
    approve(notice)

    expect { Publications::Publish.call(actor: admin, publication: notice) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "hides withdrawn and rejected publications; rejection keeps the alert untouched" do
    publication = create_publication(kind: "occurrence", alert: source)
    Publications::Submit.call(actor: admin, publication: publication)
    Publications::Review.call(actor: admin, publication: publication, decision: "reject", reason: "Texto expõe pessoas",
                              reviewed_content_version: publication.content_version)

    expect(source.reload.status).to eq("received")
    expect(public_scope).to be_empty

    other = create_publication
    approve(other)
    Publications::Publish.call(actor: admin, publication: other)
    Publications::Withdraw.call(actor: admin, publication: other, reason: "Informação desatualizada")
    expect(public_scope).to be_empty
  end

  it "revalidates the source link at query time" do
    publication = create_publication(kind: "occurrence", alert: source)
    approve(publication)
    Publications::Publish.call(actor: admin, publication: publication)
    expect(public_scope).to include(publication)

    source.update_columns(requested_visibility: "restricted")
    expect(public_scope).not_to include(publication)
  end
end
