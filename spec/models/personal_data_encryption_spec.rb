require "rails_helper"

RSpec.describe "Dados pessoais cifrados" do
  it "stores private identifiers and both panic positions as ciphertext" do
    user = create(:user, display_name: "Nome de teste")
    alert = create(:alert, :panic, author: user, location_source: "gps",
                   latitude: -8.1234567, longitude: -34.9371212)
    alert.update!(panic_latest_position: { "latitude" => -8.234, "longitude" => -34.97 })

    expect(User.find_by!(email_address: user.email_address)).to eq(user)
    expect(user.reload.display_name).to eq("Nome de teste")
    expect(alert.reload.latitude).to eq(BigDecimal("-8.1234567"))
    expect(alert.panic_latest_position.fetch("latitude")).to eq(-8.234)

    User.with_connection do |connection|
      account = connection.select_one("SELECT email_address, display_name FROM users WHERE id = #{user.id}")
      coordinates = connection.select_one("SELECT latitude, longitude, panic_latest_position FROM alerts WHERE id = #{alert.id}")
      expect((account.values + coordinates.values).all? { |value| ActiveRecord::Encryption.encryptor.encrypted?(value) }).to be(true)
    end
  end
end
