FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "operator#{n}@example.com" }
    name { "Operator #{email.split('@').first}" }
    password { "password123!" }
    role { "operator" }

    trait :admin do
      sequence(:email) { |n| "admin#{n}@example.com" }
      name { "Admin User" }
      role { "admin" }
    end

    factory :admin, traits: [ :admin ]
  end
end
