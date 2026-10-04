require "rails_helper"

RSpec.describe Alerts::CreateOccurrence do
  let(:author) { create(:user) }

  it "creates an internal occurrence with audit and without operational fields from the client" do
    result = described_class.call(
      actor: author,
      attributes: occurrence_attributes(status: "closed", priority: "urgent", visibility: "internal",
                                        assessed_severity: "critical", author_id: create(:user).id, reported_severity: "moderate")
    )
    alert = result.alert

    expect(result).to be_created
    expect(alert).to be_persisted.and have_attributes(
      kind: "occurrence", author: author, status: "received", priority: nil, assessed_severity: nil,
      reported_severity: "moderate", visibility: "internal"
    )
    expect(AuditEvent.for_subject(alert).pluck(:action)).to eq([ "alert.created" ])
  end

  it "keeps a public external request restricted until an approved publication exists" do
    alert = described_class.call(actor: author, attributes: occurrence_attributes(requested_visibility: "public_external")).alert

    expect(alert.visibility).to eq("restricted")
    expect(alert.publication).to have_attributes(state: "published", visibility: "internal", review_status: "pending")
    expect(PublicationPolicy::Scope.new(nil, Publication.all).resolve).to be_empty
  end

  it "accepts manual location and optional photos" do
    location = create(:location)
    alert = described_class.call(
      actor: author,
      attributes: occurrence_attributes(location_source: "manual", location_id: location.id, latitude: nil, longitude: nil),
      photos: [ uploaded_photo ]
    ).alert

    expect(alert.location).to eq(location)
    expect(alert.photos.count).to eq(1)
    expect(alert.photos.first.blob.content_type).to eq("image/png")
  end

  it "rejects invalid input with friendly errors and no partial records" do
    expect {
      described_class.call(actor: author, attributes: occurrence_attributes(title: nil, latitude: "200"))
    }.to raise_error(ActiveRecord::RecordInvalid)
    expect(Alert.count).to eq(0)
    expect(AuditEvent.count).to eq(0)
  end

  it "denies deactivated or anonymous actors" do
    expect { described_class.call(actor: create(:user, :inactive), attributes: occurrence_attributes) }
      .to raise_error(Pundit::NotAuthorizedError)
    expect { described_class.call(actor: nil, attributes: occurrence_attributes) }
      .to raise_error(Pundit::NotAuthorizedError)
  end

  it "rejects a fake PNG upload" do
    expect {
      described_class.call(actor: author, attributes: occurrence_attributes,
                           photos: [ uploaded_photo(bytes: "não é imagem", filename: "x.png") ])
    }.to raise_error(ActiveRecord::RecordInvalid, /PNG ou JPEG/)
  end
end
