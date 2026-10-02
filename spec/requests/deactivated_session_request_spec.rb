require "rails_helper"

RSpec.describe "Sessions of deactivated accounts", type: :request do
  it "does not resume a session after the account is deactivated outside the admin screen" do
    user = create(:user, :admin)
    sign_in(user)
    get admin_path
    expect(response).to have_http_status(:ok)

    user.update_columns(deleted_at: Time.current)
    get admin_path

    expect(response).to redirect_to(new_session_path(locale: I18n.locale))
  end

  it "audits deactivation done through the admin screen" do
    admin = create(:user, :admin)
    target = create(:user)
    sign_in(admin)

    delete admin_user_path(target)

    expect(target.reload.deleted_at).to be_present
    expect(AuditEvent.for_subject(target).last).to have_attributes(action: "user.deactivated", actor: admin)
  end
end
