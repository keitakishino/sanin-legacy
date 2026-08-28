FactoryBot.define do
  factory :trade_card_offer do
    association :trade
    association :expansion, factory: :expansion

    sequence(:card_name) { |n| "Card #{n}" }
    quantity { 1 }
    language { :ja }
    condition { :nm }
    foil { :foil }
    frame { :normal }
    pw_mark { false }
    amount { 1000 }
  end
end
