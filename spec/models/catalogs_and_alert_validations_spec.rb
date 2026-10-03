require "rails_helper"

RSpec.describe "Catalog locks and alert metadata validations" do
  let(:admin) { create(:user, :admin) }

  describe Category do
    it "locks code and the details rule after the first use" do
      category = create(:category)
      expect(category.update(code: "novo_codigo")).to be(true)

      create(:alert, category: category)
      expect(category.reload.update(code: "outro_codigo")).to be(false)
      expect(category.errors[:code]).to be_present
      expect(category.update(requires_details: true)).to be(false)
      expect(category.reload.update(name: "Nome novo", active: false, position: 3)).to be(true)
    end

    it "does not break old alerts when a used category was marked as requiring details by other means" do
      category = create(:category)
      alert = create(:alert, category: category)
      category.update_columns(requires_details: true)

      expect(alert.reload).to be_valid
      expect { Alerts::Transition.call(actor: admin, alert: alert, to: "triaging") }.not_to raise_error
    end
  end

  describe Role do
    it "never changes recognized codes" do
      role = Role.create!(code: "security", name: "Segurança")

      expect(role.update(code: "seguranca")).to be(false)
    end
  end

  describe Location do
    it "locks the code once used" do
      location = create(:location)
      create(:alert, location_source: "manual", location: location, latitude: nil, longitude: nil)

      expect(location.reload.update(code: "outro_local")).to be(false)
    end
  end

  describe Alert do
    it "validates GPS capture time and accuracy coherence" do
      alert = build(:alert, location_captured_at: 10.minutes.from_now)
      expect(alert).not_to be_valid
      expect(alert.errors[:location_captured_at]).to be_present

      alert = build(:alert, location_captured_at: 2.days.ago)
      expect(alert).not_to be_valid

      alert = build(:alert, location_captured_at: "não é uma data")
      expect(alert).not_to be_valid

      alert = build(:alert, location_accuracy_meters: Alert::MAX_ACCURACY_METERS + 1)
      expect(alert).not_to be_valid

      expect(build(:alert, location_captured_at: 2.minutes.ago, location_accuracy_meters: 30)).to be_valid
    end

    it "does not re-check an old capture time on later saves" do
      alert = create(:alert, location_captured_at: 1.minute.ago)
      travel 3.days do
        expect { Alerts::Transition.call(actor: admin, alert: alert, to: "triaging") }.not_to raise_error
      end
    end
  end
end
