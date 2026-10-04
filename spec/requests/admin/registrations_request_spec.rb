require "rails_helper"

RSpec.describe "Registration review", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:registration) { create(:user, display_name: "Pessoa Fictícia", registration_status: "pending", registration_role_code: "student", email_address: "pessoa@ufrpe.br") }

  it "shows the public registrations, filters and details only to an administrator" do
    sign_in(admin)
    get admin_registrations_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pessoa Fictícia", "Aguardando revisão")
    get admin_registrations_path(status: "rejected")
    expect(response.body).not_to include("pessoa@ufrpe.br")
    get admin_registration_path(registration)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Não implementada", "Reprovar cadastro")
  end

  it "approves pending accounts without granting administration or confirming e-mail" do
    sign_in(admin)
    patch approve_admin_registration_path(registration)
    expect(response).to redirect_to(admin_registration_path(registration, locale: I18n.locale))
    expect(registration.reload).to be_active
    expect(registration.registration_reviewed_by).to eq(admin)
    expect(registration.email_verified_at).to be_nil
    expect(registration.admin).to be(false)
    expect(AuditEvent.for_subject(registration).last.action).to eq("user.registration_reviewed")
  end

  it "requires a rejection reason without changing status or ending sessions on failure" do
    registration.update!(registration_status: "approved")
    session = registration.sessions.create!
    sign_in(admin)
    patch reject_admin_registration_path(registration), params: { reason: " " }
    expect(response).to have_http_status(:unprocessable_content)
    expect(registration.reload).to be_registration_approved
    expect(Session.exists?(session.id)).to be(true)
  end

  it "rejects and revokes every active session, preserves authored content, and can approve again" do
    registration.update!(registration_status: "approved")
    alert = create(:alert, author: registration)
    2.times { registration.sessions.create! }
    sign_in(admin)
    patch reject_admin_registration_path(registration), params: { reason: "Vínculo requer revisão" }
    expect(registration.reload).to be_registration_rejected
    expect(registration.sessions).to be_empty
    expect(alert.reload.author).to eq(registration)
    expect(registration.registration_review_reason).to eq("Vínculo requer revisão")
    sign_out
    post session_path, params: { email_address: registration.email_address, password: "123" }
    expect(registration.sessions).to be_empty
    sign_in(admin)
    patch approve_admin_registration_path(registration)
    expect(registration.reload).to be_active
    expect(registration.registration_review_reason).to be_nil
  end

  it "denies review requests to ordinary users and does not expose the queue" do
    sign_in(create(:user))
    get admin_registrations_path
    expect(response).to redirect_to(panel_path(locale: I18n.locale))
    patch approve_admin_registration_path(registration), as: :json
    expect(response).to have_http_status(:forbidden)
    expect(registration.reload).to be_registration_pending
  end

  it "does not permit an administrator to reject their own registration or review a legacy account" do
    admin.update!(registration_role_code: "professor")
    sign_in(admin)
    patch reject_admin_registration_path(admin), params: { reason: "Não pode" }
    expect(response).to have_http_status(:forbidden)
    expect(admin.reload).to be_active
    get admin_registration_path(create(:user))
    expect(response).to have_http_status(:not_found)
  end

  it "renders pending users in the existing admin account page without a deleted timestamp" do
    sign_in(admin)
    get admin_user_path(registration)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Aguardando aprovação")
  end
end
