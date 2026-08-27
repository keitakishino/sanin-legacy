FactoryBot.define do
  factory :identity do
    user
    provider { :google }
    sequence(:uid) { |n| "google_uid_#{n}" }

    factory :google_identity do
      provider { :google }
    end

    factory :twitter_identity do
      provider { :twitter }
      sequence(:uid) { |n| "twitter_uid_#{n}" }
    end
  end
end
