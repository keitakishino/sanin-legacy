FactoryBot.define do
  factory :proxy_order_price_line do
    association :proxy_order_item
    unit_price_usd { 3.00 }
    quantity { 1 }
    lost_quantity { 0 }
  end
end
