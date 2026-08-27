FactoryBot.define do
  factory :event do
    sequence(:title) { |n| "Event #{n}" }
    description { "サンプルイベント説明" }
    event_date { Date.today + 7.days }
    association :created_by, factory: :user
    spreadsheet_id { nil }
    discarded_at { nil }
  end
end
