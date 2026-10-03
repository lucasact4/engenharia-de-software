require "rails_helper"

RSpec.describe "Admin catalogs", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in(admin) }

  describe "categories" do
    it "creates, searches, sorts and edits" do
      post admin_categories_path, params: { category: { code: "acessibilidade", name: "Acessibilidade", position: 5, active: "1" } }
      category = Category.find_by!(code: "acessibilidade")
      expect(response).to redirect_to(admin_categories_path(locale: I18n.locale))

      get admin_categories_path(term: "acess", sort_column: "name", sort_direction: "asc")
      expect(response.body).to include("Acessibilidade")

      patch admin_category_path(category), params: { category: { name: "Acessibilidade e rotas" } }
      expect(category.reload.name).to eq("Acessibilidade e rotas")
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
      expect(Location.find_by!(code: "local_teste").reference_longitude).to eq(BigDecimal("-34.95"))
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
