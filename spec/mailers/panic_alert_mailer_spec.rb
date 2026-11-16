require "rails_helper"

RSpec.describe PanicAlertMailer, type: :mailer do
  it "sends an emergency message with the protocol and location to the responder" do
    recipient = create(:user).tap { |user| grant_role(user, :security) }
    alert = create(:alert, :panic, location_source: "gps", latitude: -8.0, longitude: -34.9)

    message = described_class.emergency(alert, recipient)

    expect(message.to).to eq([ recipient.email_address ])
    expect(message.subject).to include("EMERGÊNCIA", alert.protocol)
    expect(message["X-Priority"].value).to eq("1")
    expect(message["Importance"].value).to eq("high")
    expect(message.body.encoded).to include(alert.protocol, "query=-8.0,-34.9", "atendimento")
  end

  it "RNF001 records the email delivery once it is handed to the mail service" do
    recipient = create(:user).tap { |user| grant_role(user, :security) }
    alert = create(:alert, :panic, location_source: "gps", latitude: -8.0, longitude: -34.9)

    expect { described_class.emergency(alert, recipient).deliver_now }.to change(PanicDelivery, :count).by(1)
    expect(PanicDelivery.last).to have_attributes(alert: alert, user: recipient, channel: "email", status: "sent")
  end
end
