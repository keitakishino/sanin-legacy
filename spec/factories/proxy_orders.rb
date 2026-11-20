FactoryBot.define do
  factory :proxy_order do
    association :event, factory: [ :event, :proxy_order ]
    status { :ordered }
    shipping_usd { BigDecimal("0") }
  end
end
