# Dados fictícios e isolados para testes. Não representam locais ou pessoas reais da UFRPE.
FactoryBot.define do
  factory :role do
    sequence(:code) { |n| "role_#{n}" }
    name { code.humanize }
    active { true }
    position { 0 }
  end

  factory :category do
    sequence(:code) { |n| "category_#{n}" }
    sequence(:name) { |n| "Categoria #{n}" }
    active { true }
    requires_details { false }

    trait :other do
      code { "other" }
      name { "Outro" }
      requires_details { true }
    end
  end

  factory :location do
    sequence(:code) { |n| "local_ficticio_#{n}" }
    sequence(:name) { |n| "Prédio Fictício #{n}" }
    active { true }
  end

  factory :alert do
    association :author, factory: :user
    kind { "occurrence" }
    title { "Lâmpada queimada no corredor" }
    description { "A iluminação do corredor está apagada desde ontem à noite." }
    category
    location_source { "gps" }
    latitude { -8.0 }
    longitude { -34.9 }
    requested_visibility { "internal" }
    visibility { "internal" }

    trait :restricted do
      requested_visibility { "restricted" }
      visibility { "restricted" }
    end

    trait :public_request do
      requested_visibility { "public_external" }
      visibility { "restricted" }
    end

    trait :panic do
      kind { "panic" }
      title { nil }
      description { nil }
      category { nil }
      location_source { "unavailable" }
      latitude { nil }
      longitude { nil }
      requested_visibility { "restricted" }
      visibility { "restricted" }
      client_request_id { SecureRandom.uuid }
      client_request_digest { "digest-de-teste" }
    end
  end

  factory :publication do
    association :author, factory: [ :user, :admin ]
    kind { "news" }
    title { "Comunicado de teste" }
    body { "Texto editorial revisado para os testes." }
    visibility { "public_external" }

    trait :approved do
      review_status { "approved" }
      reviewed_by { author }
      reviewed_at { 1.hour.ago }
      reviewed_content_version { content_version }
    end

    trait :published do
      approved
      state { "published" }
      published_at { 30.minutes.ago }
    end
  end

  factory :comment do
    publication
    association :author, factory: :user
    body { "Comentário fictício." }
  end
end
