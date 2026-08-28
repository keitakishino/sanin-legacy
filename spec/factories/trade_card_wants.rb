FactoryBot.define do
  factory :trade_card_want do
    association :trade
    association :expansion, factory: :expansion

    sequence(:card_name) { |n| "Wanted Card #{n}" }
    quantity { 1 }
    language { nil }
    conditions { nil }
    foil { nil }
    frame { nil }
    amount { nil }
  end
end
