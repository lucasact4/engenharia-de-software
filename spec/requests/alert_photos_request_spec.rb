require "rails_helper"

RSpec.describe "Alert photos", type: :request do
  let(:author) { create(:user) }
  let(:alert) do
    Alerts::CreateOccurrence.call(actor: author, attributes: occurrence_attributes, photos: [ photo ]).alert
  end
  let(:attachment) { alert.photos_attachments.first }
  let(:path) { alert_photo_path(alert_id: alert.id, id: attachment.id) }

  it "delivers the photo to the author with private cache headers" do
    sign_in(author)
    get path

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/png")
    expect(response.body.b).to eq(SguSupport::PNG_BYTES)
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
  end

  it "delivers the photo to an active admin" do
    sign_in(create(:user, :admin))
    get path

    expect(response).to have_http_status(:ok)
  end

  it "returns 404 to an unrelated user, even for an internal alert they can read" do
    sign_in(create(:user))
    get path

    expect(response).to have_http_status(:not_found)
    expect(response.body).to be_empty
  end

  it "redirects anonymous requests to login without serving the file" do
    get path

    expect(response).to redirect_to(new_session_path(locale: I18n.locale))
  end

  it "rechecks access on every request after revocation" do
    coordinator = create(:user).tap { |user| grant_role(user, :coordination) }
    sign_in(coordinator)
    get path
    expect(response).to have_http_status(:ok)

    coordinator.roles.update_all(active: false)
    get path
    expect(response).to have_http_status(:not_found)
  end

  it "does not expose attachments of another alert through the URL" do
    other = Alerts::CreateOccurrence.call(actor: create(:user), attributes: occurrence_attributes, photos: [ photo ]).alert
    sign_in(author)
    get alert_photo_path(alert_id: alert.id, id: other.photos_attachments.first.id)

    expect(response).to have_http_status(:not_found)
  end

  it "keeps the default Active Storage routes disabled" do
    blob = attachment.blob
    sign_in(create(:user, :admin))

    [
      "/rails/active_storage/blobs/redirect/#{blob.signed_id}/#{blob.filename}",
      "/rails/active_storage/blobs/proxy/#{blob.signed_id}/#{blob.filename}",
      "/rails/active_storage/blobs/#{blob.signed_id}/#{blob.filename}",
      "/rails/active_storage/representations/redirect/#{blob.signed_id}/x/#{blob.filename}",
      "/rails/active_storage/disk/abc/#{blob.filename}"
    ].each do |url|
      get url
      expect(response).to have_http_status(:not_found), url
    end

    post "/rails/active_storage/direct_uploads", params: { blob: { filename: "x.png", byte_size: 1, checksum: "x", content_type: "image/png" } }
    expect(response).to have_http_status(:not_found)
    expect { blob.url }.to raise_error(StandardError)
  end
end
