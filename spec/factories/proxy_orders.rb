FactoryBot.define do
  factory :proxy_order do
    association :event, factory: [ :event, :proxy_order ]
    status { :ordered }
    tax_usd { BigDecimal("0") }
    customs_usd { BigDecimal("0") }
    shipping_usd { BigDecimal("0") }
    payment_fee_usd { BigDecimal("0") }
  end
end
