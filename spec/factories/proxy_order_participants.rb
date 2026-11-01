FactoryBot.define do
  factory :proxy_order_participant do
    association :proxy_order
    association :user

    trait :guest do
      user { nil }
      sequence(:guest_name) { |n| "Guest #{n}" }
    end
  end
end
