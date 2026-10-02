require "rails_helper"

RSpec.describe "Role and account services" do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:role) { create(:role, code: "coordination", name: "Coordenação") }

  it "grants and revokes roles with audit" do
    Roles::Grant.call(actor: admin, user: user, role: role, reason: "Designação")

    expect(user.role?(:coordination)).to be(true)
    expect(user.user_roles.first.granted_by).to eq(admin)
    expect(AuditEvent.for_subject(user).last).to have_attributes(action: "user.role_granted", metadata: { "role_code" => "coordination" })

    Roles::Revoke.call(actor: admin, user: user, role: role, reason: "Fim do mandato")
    expect(user.role?(:coordination)).to be(false)
    expect(AuditEvent.for_subject(user).pluck(:action)).to eq(%w[user.role_granted user.role_revoked])
  end

  it "denies self grant, non-admins and inactive or unknown roles" do
    expect { Roles::Grant.call(actor: admin, user: admin, role: role) }.to raise_error(Pundit::NotAuthorizedError)
    expect { Roles::Grant.call(actor: user, user: user, role: role) }.to raise_error(Pundit::NotAuthorizedError)
    coordinator = create(:user).tap { |u| grant_role(u, :coordination) }
    expect { Roles::Grant.call(actor: coordinator, user: user, role: role) }.to raise_error(Pundit::NotAuthorizedError)

    expect { Roles::Grant.call(actor: admin, user: user, role: create(:role, active: false, code: "security")) }
      .to raise_error(ActiveRecord::RecordInvalid)
    expect { Roles::Grant.call(actor: admin, user: user, role: create(:role, code: "zelador")) }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  it "keeps the admin boolean as the only administrative source" do
    Roles::Grant.call(actor: admin, user: user, role: role)

    expect(user.reload.admin?).to be(false)
    expect(PublicationPolicy.new(user, Publication).create?).to be(false)
  end

  it "offers role options to admins only, without an admin option" do
    create(:role, code: "student", name: "Estudante")
    options = RoleOptionsPresenter.new(actor: admin, user: user).options

    expect(options.map { |option| option[:value] }).to include("student")
    expect(options.map { |option| option[:value] }).not_to include("admin")
    expect(RoleOptionsPresenter.new(actor: user, user: user).options).to be_empty
  end

  describe Users::Deactivate do
    it "ends sessions, keeps authorship and records an audit event" do
      alert = create(:alert, author: user)
      user.sessions.create!(ip_address: "127.0.0.1", user_agent: "RSpec")

      described_class.call(actor: admin, user: user, reason: "Desligamento")

      expect(user.reload.deleted_at).to be_present
      expect(user.sessions).to be_empty
      expect(alert.reload.author).to eq(user)
      expect(AuditEvent.for_subject(user).last).to have_attributes(action: "user.deactivated", actor: admin)
    end

    it "blocks every authenticated action afterwards" do
      described_class.call(actor: admin, user: user)

      expect { Alerts::CreatePanic.call(actor: user.reload, client_request_id: SecureRandom.uuid) }.to raise_error(Pundit::NotAuthorizedError)
      expect(AlertPolicy::Scope.new(user, Alert.all).resolve).to be_empty
    end
  end
end
