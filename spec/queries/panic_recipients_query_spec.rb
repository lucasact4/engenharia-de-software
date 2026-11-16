require "rails_helper"

RSpec.describe PanicRecipientsQuery do
  let(:alert) { create(:alert, :panic, location_source: "gps", latitude: -8.0, longitude: -34.9) }

  def security_user(latitude: nil, longitude: nil, reported_at: Time.current)
    user = create(:user).tap { |record| grant_role(record, :security) }
    if latitude
      SecurityPresence.create!(user: user, latitude: latitude, longitude: longitude, reported_at: reported_at)
    end
    user
  end

  it "alerts every security responder and administrator, however far they are" do
    close_a = security_user(latitude: -8.0001, longitude: -34.9)
    close_b = security_user(latitude: -8.0002, longitude: -34.9)
    close_c = security_user(latitude: -8.0003, longitude: -34.9)
    far = security_user(latitude: -8.1, longitude: -34.9)
    without_position = security_user
    admin = create(:user, :admin)

    expect(described_class.new(alert).call).to contain_exactly(close_a, close_b, close_c, far, without_position, admin)
  end

  it "sends to the closest responders first without leaving anyone out" do
    far = security_user(latitude: -8.1, longitude: -34.9)
    close = security_user(latitude: -8.0001, longitude: -34.9)
    without_position = security_user

    recipients = described_class.new(alert).call

    expect(recipients.first(2)).to eq([ close, far ])
    expect(recipients).to include(without_position)
  end

  it "ignores stale positions for the order but still alerts that responder" do
    stale = security_user(latitude: -8.0, longitude: -34.9, reported_at: 6.minutes.ago)
    admin = create(:user, :admin)

    expect(described_class.new(alert).call).to contain_exactly(stale, admin)
  end

  it "alerts every eligible recipient when the panic has no location" do
    alert.update!(location_source: "unavailable", latitude: nil, longitude: nil,
                  location_unavailable_reason: "not_shared")
    security = security_user
    admin = create(:user, :admin)

    expect(described_class.new(alert).call).to contain_exactly(security, admin)
  end

  it "leaves out inactive accounts and roles that do not handle panic" do
    inactive = create(:user, :inactive).tap { |user| grant_role(user, :security) }
    coordination = create(:user).tap { |user| grant_role(user, :coordination) }
    security = security_user(latitude: -8.0, longitude: -34.9)

    expect(described_class.new(alert).call).to contain_exactly(security)
    expect(described_class.new(alert).call).not_to include(inactive, coordination)
  end
end
