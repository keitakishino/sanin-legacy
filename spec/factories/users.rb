FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    role { :general }

    factory :admin_user do
      role { :admin }
    end

    factory :oauth_user do
      email { nil }
      password_digest { nil }
    end
  end
end
