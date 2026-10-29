FactoryBot.define do
  factory :identity do
    user { association :user, strategy: :create }
    provider { :google }
    sequence(:uid) { |n| "google_uid_#{n}" }

    factory :google_identity do
      provider { :google }
    end

    factory :discord_identity do
      provider { :discord }
      sequence(:uid) { |n| "#{100000000000000000 + n}" }
    end
  end
end
