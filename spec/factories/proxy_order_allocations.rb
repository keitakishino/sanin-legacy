FactoryBot.define do
  factory :proxy_order_allocation do
    association :proxy_order_item
    proxy_order_participant { association :proxy_order_participant, proxy_order: proxy_order_item.proxy_order }
    quantity { 1 }
    lost_quantity { 0 }
  end
end
