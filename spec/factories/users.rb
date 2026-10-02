FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "123" }
    password_confirmation { "123" }
    admin { false }

    trait :admin do
      admin { true }
    end

    trait :inactive do
      deleted_at { 1.day.ago }
    end

    trait :public_profile do
      sequence(:username) { |n| "pessoa_#{n}" }
      display_name { "Pessoa Fictícia" }
      public_profile { true }
    end
  end
end
