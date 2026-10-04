require "rails_helper"

RSpec.describe "Social occurrence flow and protected media", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:student) { create(:user, :public_profile, display_name: "Autora UFRPE") }
  let(:category) { create(:category) }

  def create_post(audience = "public_external")
    Alerts::CreateOccurrence.call(actor: student, attributes: occurrence_attributes(category: category, requested_visibility: audience), photos: [ photo ]).alert
  end

  def decide(post, decision, reason: nil)
    Publications::Review.call(actor: admin, publication: post, decision: decision, reason: reason, reviewed_content_version: post.content_version)
  end

  it "keeps an old occurrence private until its author confirms the audience" do
    alert = create(:alert, author: student, requested_visibility: "public_external", visibility: "restricted")
    sign_in(student)
    expect { get alert_path(alert) }.not_to change(Publication, :count)
    expect(response.body).to include("Registro anterior ao novo mural")

    patch audience_alert_path(alert), params: { requested_visibility: "public_external", lock_version: alert.lock_version }

    expect(response).to have_http_status(:see_other)
    expect(alert.reload.publication).to have_attributes(state: "published", visibility: "internal", review_status: "pending")
    expect(alert.visibility).to eq("restricted")
  end

  it "accepts a simple post without a separate title or GPS" do
    sign_in(student)
    expect do
      post alerts_path, params: { client_request_id: SecureRandom.uuid, alert: { description: "Iluminação apagada na entrada da biblioteca.", category_id: category.id,
        location_source: "manual", location_description: "Biblioteca, entrada", requested_visibility: "internal" } }
    end.to change(Publication, :count).by(1)
    expect(response).to have_http_status(:see_other)
    expect(Alert.last.publication).to have_attributes(state: "published", visibility: "internal", author: student)
  end

  it "shows rejection only to the author, who can edit and resubmit the same post" do
    alert = create_post
    publication = alert.publication
    decide(publication, "reject", reason: "Retire o número pessoal do relato.")
    sign_in(create(:user))
    get publication_path(publication)
    expect(response.body).not_to include("Retire o número pessoal do relato.")
    sign_in(student)
    get alert_path(alert)
    expect(response.body).to include("Retire o número pessoal do relato.")
    patch alert_path(alert), params: { lock_version: alert.reload.lock_version, alert: { description: "Relato atualizado sem dados pessoais de terceiros." } }
    expect(response).to have_http_status(:see_other)
    expect(publication.reload).to have_attributes(review_status: "pending", visibility: "internal", content_version: 2)
    expect(Publication.count).to eq(1)
  end

  it "grants and removes verification in the administrator's profile screen" do
    sign_in(admin)
    get admin_user_path(student)
    expect(response.body).to include("Conceder selo")
    patch verification_admin_user_path(student), params: { verified: "1" }
    expect(response).to have_http_status(:see_other)
    expect(student.reload).to have_attributes(verified_by_id: admin.id)
    expect(student).to be_verified
    patch verification_admin_user_path(student), params: { verified: "0" }
    expect(student.reload).not_to be_verified
    expect(AuditEvent.for_subject(student).count).to eq(2)
  end

  it "does not grant verification through ordinary or administrative mass assignment" do
    sign_in(student)
    patch profile_path, params: { user: { display_name: "Novo nome", verified_at: Time.current, verified_by_id: admin.id, admin: true } }
    expect(student.reload).not_to be_verified
    expect(student).not_to be_admin
    patch verification_admin_user_path(student), params: { verified: "1" }
    expect(student.reload).not_to be_verified
    sign_in(admin)
    patch admin_user_path(student), params: { user: { email_address: student.email_address, verified_at: Time.current, verified_by_id: admin.id } }
    expect(student.reload).not_to be_verified
  end

  it "does not expose a pending internal photo anonymously or mix attachment IDs" do
    alert = create_post
    publication = alert.publication
    attachment = alert.photos.first
    get publication_media_path(publication_id: publication.id, id: attachment.id)
    expect(response).to have_http_status(:not_found)
    sign_in(student)
    get publication_media_path(publication_id: publication.id, id: attachment.id)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/jpeg")
    foreign = create_post("internal").photos.first
    get publication_media_path(publication_id: publication.id, id: foreign.id)
    expect(response).to have_http_status(:not_found)
  end

  it "serves processed JPEG photos after approval and rechecks revocation every time" do
    alert = create_post
    publication = alert.publication
    attachment = alert.photos.first
    decide(publication, "approve")
    get publication_media_path(publication_id: publication.id, id: attachment.id)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/jpeg")
    expect(response.body.b).to start_with("\xFF\xD8\xFF".b)
    expect(response.body.b).not_to eq(SguSupport::PNG_BYTES)
    expect(response.headers["Cache-Control"]).to include("private", "no-store")
    Alerts::ChangeAudience.call(actor: student, alert: alert, requested_visibility: "restricted")
    get publication_media_path(publication_id: publication.id, id: attachment.id)
    expect(response).to have_http_status(:not_found)
  end

  it "strips image metadata rather than forwarding original evidence to the feed" do
    alert = create_post
    attachment = alert.photos.first
    tagged = Vips::Image.new_from_buffer(SguSupport::PNG_BYTES, "")
    tagged.set_type(GObject::GSTR_TYPE, "exif-ifd0-Artist", "PRIVATE GPS MARKER")
    original = tagged.jpegsave_buffer
    attachment.blob.upload(StringIO.new(original))
    attachment.blob.save!
    decide(alert.publication, "approve")
    get publication_media_path(publication_id: alert.publication.id, id: attachment.id)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("PRIVATE GPS MARKER")
    decoded = Vips::Image.new_from_buffer(response.body.b, "")
    expect(decoded.get_fields.grep(/exif|gps/i)).to be_empty
  end

  it "returns 404 for a missing or corrupt image without exposing the original" do
    alert = create_post
    attachment = alert.photos.first
    decide(alert.publication, "approve")
    attachment.blob.upload(StringIO.new("not an image"))
    get publication_media_path(publication_id: alert.publication.id, id: attachment.id)
    expect(response).to have_http_status(:not_found)
  end

  it "stores a profile photo and only shares it after the owner's public opt-in" do
    student.update!(public_profile: false)
    sign_in(student)
    patch profile_path, params: { user: { avatar: uploaded_photo } }
    expect(response).to have_http_status(:see_other)
    expect(student.reload.avatar).to be_attached
    get profile_photo_path(student)
    expect(response).to have_http_status(:ok)
    delete session_path
    get profile_photo_path(student)
    expect(response).to have_http_status(:not_found)
    Users::UpdateProfile.call(actor: student, user: student, attributes: { public_profile: true })
    get profile_photo_path(student)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/jpeg")
    Users::UpdateProfile.call(actor: student, user: student, attributes: { public_profile: false })
    get profile_photo_path(student)
    expect(response).to have_http_status(:not_found)
  end

  it "rejects forged profile images and signed blobs from other users" do
    sign_in(student)
    patch profile_path, params: { user: { avatar: uploaded_photo(bytes: "GIF89a", filename: "false.png") } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(student.reload.avatar).not_to be_attached
    other = create_post.photos.first.blob
    patch profile_path, params: { user: { avatar: other.signed_id } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(student.reload.avatar).not_to be_attached
  end
end
