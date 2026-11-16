require "rails_helper"

RSpec.describe PanicRecipientsQuery do
  let(:alert) { create(:alert, :panic, location_source: "gps", latitude: -8.0, longitude: -34.9) }

  def security_user(latitude:, longitude:, reported_at: Time.current)
    user = create(:user).tap { |record| grant_role(record, :security) }
    SecurityPresence.create!(user: user, latitude: latitude, longitude: longitude, reported_at: reported_at)
    user
  end

  it "selects the three closest current security responders" do
    close_a = security_user(latitude: -8.0001, longitude: -34.9)
    close_b = security_user(latitude: -8.0002, longitude: -34.9)
    close_c = security_user(latitude: -8.0003, longitude: -34.9)
    far = security_user(latitude: -8.1, longitude: -34.9)

    expect(described_class.new(alert).call).to contain_exactly(close_a, close_b, close_c)
    expect(described_class.new(alert).call).not_to include(far)
  end

  it "includes active administrators as backup recipients for a located panic" do
    responder = security_user(latitude: -8.0, longitude: -34.9)
    admin = create(:user, :admin)

    expect(described_class.new(alert).call).to contain_exactly(responder, admin)
  end

  it "falls back to every eligible recipient when no recent security position exists" do
    security = security_user(latitude: -8.0, longitude: -34.9, reported_at: 6.minutes.ago)
    admin = create(:user, :admin)

    expect(described_class.new(alert).call).to contain_exactly(security, admin)
  end

  it "falls back to every eligible recipient when the panic has no location" do
    alert.update!(location_source: "unavailable", latitude: nil, longitude: nil,
                  location_unavailable_reason: "not_shared")
    security = create(:user).tap { |user| grant_role(user, :security) }
    admin = create(:user, :admin)

    expect(described_class.new(alert).call).to contain_exactly(security, admin)
  end
end
