require "rails_helper"

RSpec.describe "Admin user roles and profiles", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:user, display_name: "Pessoa Gerida") }

  before do
    Catalogs::Bootstrap.call
    sign_in(admin)
  end

  it "grants and revokes recognized roles with audit" do
    post admin_user_roles_path(person), params: { code: "coordination" }
    expect(person.reload.role?(:coordination)).to be(true)
    expect(AuditEvent.where(subject: person, action: "user.role_granted")).to exist

    delete admin_user_role_path(person, code: "coordination")
    expect(person.reload.role?(:coordination)).to be(false)
    expect(AuditEvent.where(subject: person, action: "user.role_revoked")).to exist
  end

  it "refuses unknown codes, admin as a role and self-grants" do
    post admin_user_roles_path(person), params: { code: "admin" }
    expect(response).to have_http_status(:not_found)

    post admin_user_roles_path(admin), params: { code: "security" }
    expect(response).to have_http_status(:forbidden)
    expect(admin.reload.roles).to be_empty
  end

  it "shows roles on the account page without any admin toggle" do
    get admin_user_path(person)

    expect(response.body).to include("Papéis institucionais", "Coordenação", "Conceder")
    expect(response.body).not_to include('name="user[admin]"')
  end

  it "edits profile fields with audit but never turns a profile public on someone's behalf" do
    patch admin_user_path(person), params: { user: { email_address: person.email_address, display_name: "Nome Corrigido", public_profile: "1", admin: "1" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(person.reload).to have_attributes(display_name: "Pessoa Gerida", public_profile: false, admin: false)

    patch admin_user_path(person), params: { user: { email_address: person.email_address, display_name: "Nome Corrigido", admin: "1" } }
    expect(person.reload).to have_attributes(display_name: "Nome Corrigido", public_profile: false, admin: false)
    expect(AuditEvent.where(subject: person, action: "user.profile_updated")).to exist
  end

  it "can take a public profile offline" do
    person.update!(public_profile: true, username: "pessoa_gerida")

    patch admin_user_path(person), params: { user: { email_address: person.email_address, public_profile: "0" } }

    expect(person.reload.public_profile).to be(false)
  end

  it "does not let a regular user elevate themselves" do
    user = create(:user)
    sign_in(user)

    patch admin_user_path(user), params: { user: { admin: "1" } }
    patch profile_path, params: { user: { admin: "1" } }
    post admin_user_roles_path(user), params: { code: "security" }

    expect(user.reload.admin).to be(false)
    expect(user.roles).to be_empty
  end
end
