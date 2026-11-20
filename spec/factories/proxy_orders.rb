FactoryBot.define do
  factory :proxy_order do
    association :event, factory: [ :event, :proxy_order ]
    status { :ordered }
    shipping_usd { BigDecimal("0") }
    payment_fee_rate { BigDecimal("4.1") }
    customs_rate { BigDecimal("4.0") }
    consumption_tax_rate { BigDecimal("10.0") }
  end
end
