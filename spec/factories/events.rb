FactoryBot.define do
  factory :event do
    sequence(:title) { |n| "Event #{n}" }
    description { "サンプルイベント説明" }
    event_date { Date.today + 7.days }
    event_type { :trade }
    association :created_by, factory: :user
    discarded_at { nil }

    trait :tournament do
      event_type { :tournament }
    end

    trait :proxy_order do
      event_type { :proxy_order }
    end
  end
end
