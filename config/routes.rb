Rails.application.routes.draw do
  mount RailsIcons::Engine, at: "/rails_icons"
  resource :session, only: %i[create destroy], path: "entrar"
  get "entrar", to: "sessions#new", as: :new_session
  get "criar-conta", to: "registrations#new", as: :new_registration
  post "criar-conta", to: "registrations#create", as: :registration
  resources :passwords, param: :token
  root "home#index"
  get "apresentacao", to: "presentations#show", as: :presentation

  # Área autenticada de pessoas usuárias e equipes (portal).
  resource :panel, only: :show, path: "painel", controller: "panel"

  resources :alerts, path: "alertas", only: %i[index show new create edit update] do
    patch :audience, on: :member, path: "audiencia"
    resource :subscription, only: %i[create destroy], controller: "alert_subscriptions", path: "acompanhamento"
  end
  # Fotos originais: sempre pelo controller, com autorização a cada pedido.
  get "alertas/:alert_id/fotos/:id", to: "alert_photos#show", as: :alert_photo
  delete "alertas/:alert_id/fotos/:id", to: "alert_photos#destroy"

  get "panico", to: "panic_alerts#new", as: :new_panic
  post "panico", to: "panic_alerts#create", as: :panic

  namespace :handling, path: "atendimento" do
    resources :alerts, path: "", only: %i[index show] do
      member do
        patch :assessment, path: "classificacao"
        patch :assignment, path: "responsavel"
        patch :transition, path: "situacao"
      end
    end
  end

  # Mural editorial (público para conteúdo externo) e interações.
  resources :publications, path: "mural", only: %i[index show] do
    { like: "curtida", bookmark: "salvo", subscription: "acompanhamento" }.each do |kind, path|
      resource kind, only: %i[create destroy], controller: "publication_interactions", path: path,
                     as: "#{kind}_interaction", defaults: { kind: kind }
    end
    resources :comments, only: :create, path: "comentarios"
    resources :content_reports, only: %i[new create], path: "denuncia"
  end

  resources :comments, path: "comentarios", only: %i[show edit update destroy] do
    resource :like, only: %i[create destroy], controller: "comment_likes", path: "curtida"
    resources :content_reports, only: %i[new create], path: "denuncia"
  end

  get "salvos", to: "saved_publications#index", as: :saved_publications
  get "acompanhamentos", to: "follow_ups#index", as: :follow_ups
  delete "acompanhamentos/indisponiveis", to: "follow_ups#prune", as: :prune_follow_ups

  resources :content_reports, path: "denuncias", only: %i[index show] do
    patch :reopen, on: :member, path: "reabrir"
  end

  resource :profile, path: "perfil", only: %i[show edit update]
  resources :people, path: "pessoas", controller: "public_profiles", only: %i[index show] do
    get :followers, on: :member, path: "seguidores"
    resource :follow, only: %i[create destroy], controller: "follows", path: "seguir"
  end

  namespace :admin do
    resources :users do
      resources :roles, only: %i[create destroy], controller: "user_roles", param: :code
    end
    resources :registrations, path: "cadastros", only: %i[index show] do
      member do
        patch :approve, path: "aprovar"
        patch :reject, path: "reprovar"
      end
    end
    resources :categories, path: "categorias", except: :destroy do
      member do
        patch :activate, path: "ativar"
        patch :deactivate, path: "desativar"
      end
    end
    resources :locations, path: "locais", except: :destroy do
      member do
        patch :activate, path: "ativar"
        patch :deactivate, path: "desativar"
      end
    end
    resources :alerts, path: "ocorrencias", except: :destroy do
      member do
        patch :assessment, path: "classificacao"
        patch :assignment, path: "responsavel"
        patch :transition, path: "situacao"
        patch :audience, path: "audiencia"
        patch :restriction, path: "restricao"
      end
    end
    resources :publications, path: "publicacoes", except: :destroy do
      member do
        patch :submit_review, path: "envio"
        patch :review, path: "revisao"
        patch :publish, path: "publicacao"
        patch :withdraw, path: "retirada"
      end
    end
    resources :content_reports, path: "denuncias", only: %i[index show] do
      patch :review, on: :member, path: "analise"
    end
    resources :comments, path: "comentarios", only: [] do
      patch :moderate, on: :member, path: "moderacao"
    end
    resources :presentation_profiles, path: "apresentacao", except: :show do
      patch :activate, on: :member
    end
    get "/" => "dashboard#index"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
