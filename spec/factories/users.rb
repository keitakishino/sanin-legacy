FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    role { :general }

    transient do
      password { "password123" }
    end

    after(:build) do |user, evaluator|
      user.password = evaluator.password
      user.password_confirmation = evaluator.password
    end

    after(:create) do |user|
      # password_digest is set during build, just save it
      user.save!
    end

    factory :admin_user do
      role { :admin }
    end

    factory :oauth_user do
      email { nil }
      password_digest { nil }
    end
  end
end
