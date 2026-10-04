require "rails_helper"

RSpec.describe "Occurrence photo editing" do
  let(:author) { create(:user) }

  def with_photos(count: 3, public_request: false)
    Alerts::CreateOccurrence.call(actor: author, attributes: occurrence_attributes(
      title: "Fotos da ocorrência", requested_visibility: public_request ? "public_external" : "internal"
    ), photos: Array.new(count) { uploaded_photo }).alert
  end

  it "persists cover and order on the same post and invalidates public approval" do
    alert = with_photos(public_request: true)
    post = alert.publication
    Publications::Review.call(actor: create(:user, :admin), publication: post, decision: "approve", reviewed_content_version: 1)
    ids = alert.ordered_photos.map(&:id)
    Alerts::UpdateContent.call(actor: author, alert: alert, photo_order: [ ids[2], ids[0], ids[1] ].map { |id| "existing_#{id}" })
    expect(alert.reload.ordered_photos.map(&:id)).to eq([ ids[2], ids[0], ids[1] ])
    expect(post.reload).to have_attributes(content_version: 2, visibility: "internal", review_status: "pending")
    card = PublicationProjection.collection([ post ], viewer: author).first
    expect(card[:photos].first[:id]).to eq(ids[2])
  end

  it "removes, adds and reorders photos in one save while keeping the uploaded bytes" do
    alert = with_photos(count: 5)
    ids = alert.ordered_photos.map(&:id)
    order = [ "new_0" ] + ids.drop(1).map { |id| "existing_#{id}" }
    Alerts::UpdateContent.call(actor: author, alert: alert, photos: [ uploaded_photo ], removed_photo_ids: [ ids.first ], photo_order: order)
    expect(alert.reload.photos.count).to eq(5)
    expect(alert.photo_order.drop(1)).to eq(ids.drop(1))
    expect(alert.photos_attachments.exists?(ids.first)).to be(false)
    expect(alert.ordered_photos.first.blob.download).to start_with("\x89PNG".b)
  end

  it "rejects another occurrence's photo without changing either record" do
    alert = with_photos
    foreign = with_photos(count: 1).photos.first
    old_ids = alert.photos.map(&:id)
    expect { Alerts::UpdateContent.call(actor: author, alert: alert, removed_photo_ids: [ foreign.id ]) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(alert.reload.photos.map(&:id)).to eq(old_ids)
    expect(foreign.reload).to be_persisted
  end

  it "rejects omitted, duplicated, forged or unknown order tokens" do
    alert = with_photos(count: 2)
    tokens = alert.photos.map { |photo| "existing_#{photo.id}" }
    [ tokens.take(1), [ tokens.first, tokens.first ], [ tokens.first, "new_99" ], [ tokens.first, "existing_999999" ] ].each do |order|
      expect { Alerts::UpdateContent.call(actor: author, alert: alert.reload, photo_order: order) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(alert.reload.photo_order).to eq([])
    end
  end

  it "rolls back photo removals and order when the content is invalid" do
    alert = with_photos(count: 2)
    ids = alert.photos.map(&:id)
    expect { Alerts::UpdateContent.call(actor: author, alert: alert, attributes: { title: "x" }, removed_photo_ids: [ ids.first ]) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(alert.reload.photos.map(&:id)).to eq(ids)
    expect(alert.title).to eq("Fotos da ocorrência")
  end

  it "rejects a stale photo edit without removing the attachment" do
    alert = with_photos(count: 2)
    ids = alert.photos.map(&:id)
    alert.update!(description: "Outro texto salvo antes desta edição.")
    expect { Alerts::UpdateContent.call(actor: author, alert: alert, removed_photo_ids: [ ids.first ], lock_version: 0) }.to raise_error(ActiveRecord::StaleObjectError)
    expect(alert.reload.photos.map(&:id)).to eq(ids)
  end

  it "does not rewrite the author's title when only the description changes" do
    alert = with_photos
    Alerts::UpdateContent.call(actor: author, alert: alert, attributes: { description: "Detalhes complementares escritos pelo autor." })
    expect(alert.reload.title).to eq("Fotos da ocorrência")
  end

  it "refuses a photo order edit from another user" do
    alert = with_photos(count: 2)
    expect { Alerts::UpdateContent.call(actor: create(:user), alert: alert, photo_order: []) }.to raise_error(Pundit::NotAuthorizedError)
  end
end
