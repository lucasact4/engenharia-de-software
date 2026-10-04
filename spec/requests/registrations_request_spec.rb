require "rails_helper"

RSpec.describe "Institutional registration", type: :request do
  let(:attributes) { { display_name: "Pessoa Fictícia", email_address: "pessoa@ufrpe.br", role_code: "student", password: "Senha123!", password_confirmation: "Senha123!" } }
  before { Role.create!(code: "student", name: "Estudante", active: true) }

  around do |example|
    previous = Rails.configuration.x.registration.auto_approve
    Rails.configuration.x.registration.auto_approve = true
    example.run
  ensure
    Rails.configuration.x.registration.auto_approve = previous
  end

  it "links the public registration from both landing and login with development warnings" do
    [ root_path, new_session_path ].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).css("a").map { |link| link["href"] }).to include(new_registration_path(locale: nil))
    end
    get new_registration_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("confirmação de e-mail ainda não foi implementada", "aprovados automaticamente")
  end

  it "creates a private ordinary account with only the chosen role, audits and starts a session" do
    post registration_path, params: { registration: attributes.merge(admin: true, registration_status: "approved", public_profile: true, role_ids: [ 123 ]) }
    user = User.find_by!(email_address: "pessoa@ufrpe.br")
    expect(response).to redirect_to(panel_path(locale: I18n.locale))
    expect(user).to be_active
    expect(user.admin).to be(false)
    expect(user.public_profile).to be(false)
    expect(user.roles.pluck(:code)).to eq([ "student" ])
    expect(user.email_verified_at).to be_nil
    expect(user.sessions.count).to eq(1)
    audit = AuditEvent.for_subject(user).last
    expect(audit.action).to eq("user.registered")
    expect(audit.metadata).to include("decision" => "automatic_approval", "role_code" => "student")
    expect(audit.attributes.to_json).not_to include("Senha123!", "password_digest")
    get panel_path
    expect(response).to have_http_status(:ok)
    get admin_path
    expect(response).to redirect_to(panel_path(locale: I18n.locale))
  end

  it "keeps manual-review accounts pending and unable to log in" do
    Rails.configuration.x.registration.auto_approve = false
    post registration_path, params: { registration: attributes }
    user = User.find_by!(email_address: attributes[:email_address])
    expect(user).to be_registration_pending
    expect(user.sessions).to be_empty
    expect(response).to redirect_to(new_session_path(locale: I18n.locale))
    post session_path, params: { email_address: user.email_address, password: attributes[:password] }
    expect(user.sessions).to be_empty
    get panel_path
    expect(response).to redirect_to(new_session_path(locale: I18n.locale))
  end

  it "rejects invalid registration and never renders submitted passwords" do
    expect do
      post registration_path, params: { registration: attributes.merge(email_address: "fora@example.com") }
    end.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("domínio exatamente @ufrpe.br")
    expect(response.body).not_to include("Senha123!")
    expect(Session.count).to eq(0)
  end

  it "handles an inactive catalogue role without creating a partial account" do
    Role.find_by!(code: "student").update!(active: false)
    expect { post registration_path, params: { registration: attributes } }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("não está disponível para cadastro")
  end

  it "rolls the account and role assignment back if auditing fails" do
    allow(AuditEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid.new(AuditEvent.new))
    expect { post registration_path, params: { registration: attributes } }.not_to change(User, :count)
    expect(UserRole.count).to eq(0)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "does not allow the current user to create another account in the same session" do
    sign_in(create(:user))
    expect { post registration_path, params: { registration: attributes } }.not_to change(User, :count)
    expect(response).to redirect_to(panel_path(locale: I18n.locale))
  end
end
