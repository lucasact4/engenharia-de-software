require "rails_helper"

RSpec.describe DeliverNotificationsJob do
  it "emails only confirmed recipients who opted in" do
    allow(Notifications::ChannelConfig).to receive(:email_available?).and_return(true)
    admin = create(:user, :admin)
    confirmed = create(:user)
    confirmed.update!(email_confirmed_at: Time.current)
    unconfirmed = create(:user)
    [confirmed, unconfirmed].each do |user|
      NotificationPreference.create!(user: user, email_enabled: true)
      alert = create(:alert, author: user)
      Alerts::Transition.call(actor: admin, alert: alert, to: "triaging")
    end

    expect { described_class.perform_now }.to change { ActionMailer::Base.deliveries.size }.by(1)
    expect(ActionMailer::Base.deliveries.last.to).to eq([confirmed.email_address])
    expect(NotificationDelivery.where(result: "skipped").count).to eq(1)
  end
end
