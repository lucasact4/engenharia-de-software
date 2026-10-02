Rails.application.routes.draw do
  mount RailsIcons::Engine, at: "/rails_icons"
  resource :session, only: %i[create destroy], path: "entrar"
  get "entrar", to: "sessions#new", as: :new_session
  resources :passwords, param: :token
  root "home#index"
  get "apresentacao", to: "presentations#show", as: :presentation
  get "alertas/:alert_id/fotos/:id", to: "alert_photos#show", as: :alert_photo
  namespace :admin do
    resources :users
    resources :dogs
    resources :presentation_profiles, path: "apresentacao", except: :show do
      patch :activate, on: :member
    end
    get "/" => "dashboard#index"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
