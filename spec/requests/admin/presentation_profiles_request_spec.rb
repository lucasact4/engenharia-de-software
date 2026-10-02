require "rails_helper"

RSpec.describe "Admin presentation profiles", type: :request do
  let(:presentation) { Presentation.load }
  let(:admin) { create(:user, :admin) }

  def selection_params(overrides = {})
    (presentation.catalog_keys - Presentation::REQUIRED_SLIDES).index_with { "1" }.merge(overrides)
  end

  describe "authorization" do
    it "redirects visitors to sign in" do
      get admin_presentation_profiles_path

      expect(response).to redirect_to(new_session_path(locale: I18n.default_locale))
    end

    it "does not let a regular user see or change profiles" do
      profile = create(:presentation_profile, selections: { "gestao" => true })
      sign_in(create(:user))

      get admin_presentation_profiles_path
      expect(response).to redirect_to(root_path(locale: I18n.default_locale))

      patch admin_presentation_profile_path(profile), params: { presentation_profile: { selections: { "gestao" => "0" } } }
      expect(profile.reload.selections).to eq("gestao" => true)

      patch activate_admin_presentation_profile_path(profile)
      expect(profile.reload).not_to be_active
    end

    it "lists the profiles for an admin and identifies the active one" do
      create(:presentation_profile, :active, name: "Segunda entrega")
      sign_in(admin)

      get admin_presentation_profiles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Perfil padrão da apresentação pública: <strong class=\"text-slate-900\">Segunda entrega</strong>")
    end

    it "shows the menu item only to admins" do
      sign_in(admin)
      get admin_path
      expect(response.body).to include(admin_presentation_profiles_path)

      sign_out
      sign_in(create(:user))
      get admin_path
      expect(response.body).not_to include(admin_presentation_profiles_path)
    end
  end

  describe "saving selections" do
    before { sign_in(admin) }

    it "renders the hierarchy from the catalog with required slides locked" do
      get new_admin_presentation_profile_path
      document = Nokogiri::HTML(response.body)

      presentation.catalog_keys.excluding(Presentation::REQUIRED_SLIDES).each do |key|
        expect(document.at_css("input[type=checkbox][name='presentation_profile[selections][#{key}]']")).to be_present, key
      end
      Presentation::REQUIRED_SLIDES.each do |id|
        expect(document.at_css("input[name='presentation_profile[selections][#{id}]']")).to be_nil
        expect(document.at_css("#selection_#{id}[disabled][checked]")).to be_present
      end
    end

    it "creates a profile with the submitted selection" do
      expect {
        post admin_presentation_profiles_path, params: {
          presentation_profile: { name: "Banca", delivery: "primeira", selections: selection_params("gestao.reunioes" => "0") }
        }
      }.to change(PresentationProfile, :count).by(1)

      profile = PresentationProfile.find_by!(name: "Banca")
      expect(response).to redirect_to(edit_admin_presentation_profile_path(profile, locale: I18n.default_locale))
      expect(flash[:success]).to be_present
      expect(profile.selections["gestao.reunioes"]).to be(false)
      expect(profile.selections["gestao"]).to be(true)
    end

    it "updates only the edited profile and preserves item choices of a hidden slide" do
      profile = create(:presentation_profile, selections: selection_params.transform_values { true })
      other = create(:presentation_profile, selections: { "gestao" => true })

      patch admin_presentation_profile_path(profile), params: {
        presentation_profile: { selections: selection_params("gestao" => "0", "gestao.reunioes" => "0") }
      }

      expect(profile.reload.selections).to include("gestao" => false, "gestao.reunioes" => false, "gestao.cards" => true)
      expect(other.reload.selections).to eq("gestao" => true)
    end

    it "rejects unknown keys and keeps the saved selection" do
      profile = create(:presentation_profile, selections: { "gestao" => true })

      patch admin_presentation_profile_path(profile), params: {
        presentation_profile: { selections: { "gestao" => "0", "../../layouts/admin" => "1" } }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("../../layouts/admin")
      expect(profile.reload.selections).to eq("gestao" => true)
    end

    it "rejects hiding the cover or the closing slide" do
      profile = create(:presentation_profile)

      patch admin_presentation_profile_path(profile), params: { presentation_profile: { selections: { "encerramento" => "0" } } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("não pode ocultar slides obrigatórios")
    end

    it "rejects non-boolean values" do
      profile = create(:presentation_profile)

      patch admin_presentation_profile_path(profile), params: { presentation_profile: { selections: { "gestao" => "talvez" } } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "selects the public default profile" do
      current = create(:presentation_profile, :active)
      chosen = create(:presentation_profile)

      patch activate_admin_presentation_profile_path(chosen)

      expect(response).to redirect_to(admin_presentation_profiles_path(locale: I18n.default_locale))
      expect(chosen.reload).to be_active
      expect(current.reload).not_to be_active
    end

    it "deletes inactive profiles but not the active one" do
      active = create(:presentation_profile, :active)
      inactive = create(:presentation_profile)

      expect { delete admin_presentation_profile_path(inactive) }.to change(PresentationProfile, :count).by(-1)
      expect { delete admin_presentation_profile_path(active) }.not_to change(PresentationProfile, :count)
    end
  end
end
