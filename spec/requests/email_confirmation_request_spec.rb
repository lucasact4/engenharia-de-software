require "rails_helper"

RSpec.describe "Confirmação de e-mail", type: :request do
  let(:user) { create(:user) }

  it "sends a link to the registered address and confirms it only after explicit submission" do
    message = NotificationMailer.confirm_email(user).message
    expect(message.to).to eq([ user.email_address ])
    url = URI.parse(message.text_part.body.decoded.strip.lines.last)

    html = Nokogiri::HTML(message.html_part.body.decoded)
    expect(html.css("a").map { |link| link["href"] }).to eq([ url.to_s, url.to_s ])
    expect(html.at_css("img")["src"]).to start_with("cid:")
    expect(message.attachments["sgu-logo.png"]).to be_inline

    get url.request_uri
    expect(response).to have_http_status(:ok)
    expect(user.reload.email_confirmed_at).to be_nil

    token = URI.decode_www_form(url.query).to_h.fetch("token")
    patch email_confirmation_path, params: { token: token }
    confirmed_at = user.reload.email_confirmed_at
    expect(confirmed_at).to be_present

    travel 1.minute do
      patch email_confirmation_path, params: { token: token }
      expect(user.reload.email_confirmed_at).to eq(confirmed_at)
    end
  end

  it "rejects expired links and links issued for a different address" do
    token = user.generate_token_for(:email_confirmation)
    travel 25.hours do
      patch email_confirmation_path, params: { token: token }
      expect(user.reload.email_confirmed_at).to be_nil
    end

    user.update!(email_address: "alterado@example.test")
    patch email_confirmation_path, params: { token: token }
    expect(user.reload.email_confirmed_at).to be_nil
  end

  it "records administrator status changes with actor and before/after values" do
    admin = create(:user, :admin)
    alert = create(:alert, author: user)
    Alerts::Transition.call(actor: admin, alert: alert, to: "triaging")
    event = AuditEvent.for_subject(alert).find_by!(actor: admin, action: "alert.status_changed")
    expect(event.changeset.fetch("status")).to eq(%w[received triaging])
    expect(event.created_at).to be_present
  end
end
