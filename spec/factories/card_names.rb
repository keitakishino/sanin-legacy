FactoryBot.define do
  factory :card_name do
    sequence(:name) { |n| "Card Name #{n}" }
  end
end
