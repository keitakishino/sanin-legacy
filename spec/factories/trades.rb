FactoryBot.define do
  factory :trade do
    association :event
    association :user

    status { :pending }
    offers_total_amount { 0 }
    wants_total_amount { 0 }
    net_amount { 0 }
  end
end
