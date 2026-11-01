FactoryBot.define do
  factory :proxy_order_item do
    association :proxy_order
    association :expansion
    sequence(:card_name) { |n| "Proxy Card #{n}" }
    foil { :foil }
    frame { :normal }
  end
end
