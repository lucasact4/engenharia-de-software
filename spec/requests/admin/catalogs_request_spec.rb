require "rails_helper"

RSpec.describe "Admin catalogs", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in(admin) }

  describe "categories" do
    it "creates, searches, sorts and edits" do
      post admin_categories_path, params: { category: { code: "acessibilidade", name: "Acessibilidade", position: 5, active: "1" } },
                                    headers: { "REMOTE_ADDR" => "198.51.100.17" }
      category = Category.find_by!(code: "acessibilidade")
      expect(response).to redirect_to(admin_categories_path(locale: I18n.locale))
      created_event = AuditEvent.for_subject(category).sole
      expect(created_event).to have_attributes(actor: admin, action: "category.created", ip_address: "198.51.100.17")
      expect(created_event.changeset).to include("name" => [ nil, "Acessibilidade" ])

      get admin_categories_path(term: "acess", sort_column: "name", sort_direction: "asc")
      expect(response.body).to include("Acessibilidade")

      patch admin_category_path(category), params: { category: { name: "Acessibilidade e rotas" } },
                                           headers: { "REMOTE_ADDR" => "198.51.100.18" }
      expect(category.reload.name).to eq("Acessibilidade e rotas")
      updated_event = AuditEvent.for_subject(category).order(:created_at, :id).last
      expect(updated_event).to have_attributes(actor: admin, action: "category.updated", ip_address: "198.51.100.18")
      expect(updated_event.changeset).to eq("name" => [ "Acessibilidade", "Acessibilidade e rotas" ])
    end

    it "shows validation errors" do
      post admin_categories_path, params: { category: { code: "X Inválido", name: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "deactivates without deleting and keeps old alerts valid while blocking new choices" do
      category = create(:category)
      alert = create(:alert, category: category)

      patch deactivate_admin_category_path(category)
      expect(category.reload).not_to be_active
      expect(AuditEvent.for_subject(category).last).to have_attributes(
        action: "category.deactivated", changeset: { "active" => [ true, false ] }, ip_address: "127.0.0.1"
      )
      expect(Category.exists?(category.id)).to be(true)

      expect(alert.reload).to be_valid
      Alerts::Transition.call(actor: admin, alert: alert, to: "triaging")
      expect(alert.reload.status).to eq("triaging")

      result = Alerts::CreateOccurrence.call(actor: create(:user), attributes: occurrence_attributes(category: category)) rescue $!
      expect(result).to be_a(ActiveRecord::RecordInvalid)

      options = AlertOptionsPresenter.new(actor: admin, alert: alert).categories
      expect(options.find { |option| option.value == category.id }.disabled).to be(true)
      expect(AlertOptionsPresenter.new(actor: admin).categories.map(&:value)).not_to include(category.id)

      patch activate_admin_category_path(category)
      expect(category.reload).to be_active
      expect(AuditEvent.for_subject(category).last).to have_attributes(
        action: "category.activated", changeset: { "active" => [ false, true ] }
      )
    end

    it "locks the code and the details rule once the category is used" do
      category = create(:category, requires_details: false)
      create(:alert, category: category)

      patch admin_category_path(category), params: { category: { code: "novo_codigo", requires_details: "1" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(category.reload).to have_attributes(requires_details: false)
      expect(category.code).not_to eq("novo_codigo")
    end

    it "has no destroy route" do
      category = create(:category)
      delete "/admin/categorias/#{category.id}"

      expect(Category.exists?(category.id)).to be(true)
    end
  end

  describe "locations" do
    it "explains the empty catalog without inventing official places" do
      get admin_locations_path

      expect(response.body).to include("A lista oficial de prédios e áreas da UFRPE ainda não foi fornecida")
      expect(Location.count).to eq(0)
    end

    it "creates with an optional coordinate pair and validates the pair" do
      post admin_locations_path, params: { location: { code: "local_teste", name: "Local de teste", reference_latitude: "-8.01" } }
      expect(response).to have_http_status(:unprocessable_entity)

      post admin_locations_path, params: { location: { code: "local_teste", name: "Local de teste", reference_latitude: "-8.01", reference_longitude: "-34.95" } }
      location = Location.find_by!(code: "local_teste")
      expect(location.reference_longitude).to eq(BigDecimal("-34.95"))
      event = AuditEvent.for_subject(location).sole
      expect(event).to have_attributes(actor: admin, action: "location.created", ip_address: "127.0.0.1")
      expect(event.changeset).to include("reference_latitude" => [ nil, "-8.01" ], "reference_longitude" => [ nil, "-34.95" ])

      patch admin_location_path(location), params: { location: { name: "Local de teste revisado" } }
      update_event = AuditEvent.for_subject(location).order(:created_at, :id).last
      expect(update_event).to have_attributes(action: "location.updated", actor: admin)
      expect(update_event.changeset).to eq("name" => [ "Local de teste", "Local de teste revisado" ])
    end

    it "lets administrators add a mapped building outline" do
      boundary = {
        type: "Polygon",
        coordinates: [ [ [ -34.95, -8.01 ], [ -34.94, -8.01 ], [ -34.94, -8.00 ], [ -34.95, -8.01 ] ] ]
      }.to_json
      post admin_locations_path, params: { location: { code: "predio_teste", name: "Prédio de teste", boundary_geojson: boundary } }

      location = Location.find_by!(code: "predio_teste")
      expect(response).to redirect_to(admin_locations_path(locale: I18n.locale))
      expect(location.boundary).to eq(JSON.parse(boundary))
      expect(AuditEvent.for_subject(location).sole.changeset.fetch("boundary").map { |digest| digest&.length }).to eq([ nil, 64 ])
    end
  end

  it "is not available to coordination or regular users" do
    user = create(:user)
    grant_role(user, :coordination)
    sign_in(user)

    post admin_categories_path, params: { category: { code: "invasao", name: "Invasão" } }

    expect(response).to redirect_to(panel_path(locale: I18n.locale))
    expect(Category.exists?(code: "invasao")).to be(false)
  end
end
