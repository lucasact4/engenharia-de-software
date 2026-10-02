FactoryBot.define do
  factory :presentation_profile do
    sequence(:name) { |n| "Perfil #{n}" }
    delivery { "segunda" }
    active { false }
    selections { {} }

    trait :active do
      active { true }
    end
  end
end
