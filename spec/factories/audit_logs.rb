FactoryBot.define do
  factory :audit_log do
    association :user, factory: :admin_user
    action { "event.discard" }
    result { :success }
    details { {} }
    request_id { "req-123" }
    target_type { "Event" }
    target_id { 17 }
  end
end
