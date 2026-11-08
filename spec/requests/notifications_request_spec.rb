require "rails_helper"

RSpec.describe "Private notification inbox", type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  def status_notice(author = user)
    alert = create(:alert, author: author)
    Alerts::Transition.call(actor: admin, alert: alert, to: "triaging")
    author.notifications.find_by!(kind: "alert_status")
  end

  it "requires authentication for listing and writing" do
    notice = status_notice
    get notifications_path(format: :json)
    expect(response).to redirect_to(new_session_path(locale: I18n.locale))
    patch read_notification_path(notice), as: :json
    expect(response).to redirect_to(new_session_path(locale: I18n.locale))
    expect(notice.reload.read_at).to be_nil
  end

  it "lists only the recipient and does not mark messages on GET or preview" do
    own = status_notice
    other = status_notice(create(:user))
    sign_in(user)
    get notifications_path(format: :json), params: { user_id: other.user_id }
    expect(response).to have_http_status(:ok)
    data = response.parsed_body
    expect(data["unread_count"]).to eq(1)
    expect(data["list_html"]).to include(own.message)
    expect(data["list_html"]).not_to include(other.message)
    expect(data["urgent_id"]).to be_nil
    expect(response.headers["Cache-Control"]).to include("no-store", "private")
    expect(own.reload.read_at).to be_nil
    get notifications_path
    expect(response.body).to include("Suas notificações", "Não lida")
    expect(own.reload.read_at).to be_nil
  end

  it "rejects changing another recipient's notification, even for an admin" do
    notice = status_notice
    sign_in(admin)
    patch read_notification_path(notice), as: :json
    expect(response).to have_http_status(:not_found)
    expect(notice.reload.read_at).to be_nil
  end

  it "records first reading once and ignores submitted recipient and message fields" do
    notice = status_notice
    sign_in(user)
    patch read_notification_path(notice), params: { user_id: admin.id, message: "alterada" }, as: :json
    expect(response).to have_http_status(:no_content)
    first_read = notice.reload.read_at
    travel 1.minute do
      patch read_notification_path(notice), as: :json
      expect(response).to have_http_status(:no_content)
    end
    expect(notice.reload.read_at).to eq(first_read)
    expect(notice.user_id).to eq(user.id)
    expect(notice.message).not_to eq("alterada")
  end

  it "keeps panic acknowledgements individual and out of bulk reading" do
    admin
    create(:alert, :panic, author: user)
    common = status_notice(admin)
    sign_in(admin)
    patch read_all_notifications_path
    expect(common.reload.read_at).to be_present
    panic = admin.notifications.find_by!(kind: "panic")
    expect(panic.read_at).to be_nil
    patch read_notification_path(panic), as: :json
    expect(panic.reload.read_at).to be_present
  end

  it "keeps other recipients' panic acknowledgement independent" do
    security = create(:user)
    grant_role(security, :security)
    admin
    panic = create(:alert, :panic, author: user)
    sign_in(admin)
    patch read_notification_path(admin.notifications.find_by!(alert: panic)), as: :json
    expect(security.notifications.find_by!(alert: panic).read_at).to be_nil
  end

  it "lets new common messages reappear after older panic alerts have been acknowledged" do
    admin
    10.times { create(:alert, :panic, author: user) }
    admin.notifications.update_all(read_at: Time.current)
    common = status_notice(admin)
    sign_in(admin)
    get notifications_path(format: :json)
    expect(response.parsed_body["list_html"]).to include(common.message)
    expect(response.parsed_body["urgent_id"]).to be_nil
  end

  it "prioritizes panic older than the latest ten ordinary messages and drains oldest first" do
    admin
    older = create(:alert, :panic, author: user)
    newer = create(:alert, :panic, author: user)
    12.times { status_notice(admin) }
    sign_in(admin)
    get notifications_path(format: :json)
    first = admin.notifications.find_by!(alert: older)
    expect(response.parsed_body["urgent_id"]).to eq(first.id)
    expect(response.parsed_body["list_html"]).to include(older.protocol, newer.protocol)
    patch read_notification_path(first), as: :json
    get notifications_path(format: :json)
    expect(response.parsed_body["urgent_id"]).to eq(admin.notifications.find_by!(alert: newer).id)
  end

  it "revokes panic visibility immediately when the security role is removed" do
    grant_role(user, :security)
    create(:alert, :panic, author: create(:user))
    notice = user.notifications.sole
    sign_in(user)
    get notifications_path(format: :json)
    expect(response.parsed_body["urgent_id"]).to eq(notice.id)
    user.user_roles.destroy_all
    get notifications_path(format: :json)
    expect(response.parsed_body["urgent_id"]).to be_nil
    expect(response.parsed_body["unread_count"]).to eq(0)
    patch read_notification_path(notice), as: :json
    expect(response).to have_http_status(:not_found)
  end

  it "hides administrative notifications when admin access is revoked" do
    user.update!(admin: true)
    create(:publication, review_status: "pending")
    publication = create(:publication, :published)
    ContentReports::Create.call(actor: create(:user), target: publication, reason: "spam")
    expect(user.notifications.count).to eq(2)
    sign_in(user)
    user.update!(admin: false)
    get notifications_path(format: :json)
    expect(response.parsed_body["unread_count"]).to eq(0)
  end

  it "does not leak expired, withdrawn or hidden social targets" do
    publication = create(:publication, :published, author: user)
    comment = create(:comment, publication: publication)
    sign_in(user)
    get notifications_path(format: :json)
    expect(response.parsed_body["unread_count"]).to eq(1)
    comment.update!(deleted_at: Time.current)
    get notifications_path(format: :json)
    expect(response.parsed_body["unread_count"]).to eq(0)
    comment.update!(deleted_at: nil)
    publication.update!(expires_at: 1.second.ago)
    get notifications_path(format: :json)
    expect(response.parsed_body["unread_count"]).to eq(0)
    expect(Notification.visible_to(user)).to be_empty
  end

  it "preserves security users' common author and social notifications" do
    grant_role(user, :security)
    status_notice
    publication = create(:publication, :published, author: user)
    create(:comment, publication: publication)
    sign_in(user)
    get notifications_path(format: :json)
    expect(response.parsed_body["unread_count"]).to eq(2)
    expect(response.parsed_body["list_html"]).to include("novo comentário", "Em triagem")
  end

  it "rejects deactivated sessions and hides all their persisted notifications" do
    status_notice
    sign_in(user)
    user.update!(deleted_at: Time.current)
    get notifications_path(format: :json)
    expect(response).to redirect_to(new_session_path(locale: I18n.locale))
    expect(Notification.visible_to(user)).to be_empty
  end

  it "does not change reading through GET or a missing CSRF token" do
    notice = status_notice
    sign_in(user)
    get "/notificacoes/#{notice.id}/leitura"
    expect(notice.reload.read_at).to be_nil
    ActionController::Base.allow_forgery_protection = true
    patch read_notification_path(notice), as: :json
    expect(notice.reload.read_at).to be_nil
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  it "escapes persisted messages in the preview instead of executing markup" do
    notice = status_notice
    notice.update!(message: '<script>alert("injected")</script>')
    sign_in(user)
    get notifications_path(format: :json)
    expect(response.parsed_body["list_html"]).to include("&lt;script&gt;")
    expect(response.parsed_body["list_html"]).not_to include("<script>")
  end

  it "paginates the full inbox and bounds the preview" do
    51.times { status_notice }
    sign_in(user)
    get notifications_path(page: 2)
    expect(Nokogiri::HTML(response.body).css("main [data-notification-id]").size).to eq(1)
    get notifications_path(format: :json)
    expect(Nokogiri::HTML(response.parsed_body["list_html"]).css("[data-notification-id]").size).to eq(10)
  end
end
