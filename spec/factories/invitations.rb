FactoryBot.define do
  factory :invitation do
    sequence(:code) { |n| "invite#{n}" }
    issued_by { association :admin_user, strategy: :create }
    status { :active }
    expires_at { 7.days.from_now }

    factory :used_invitation do
      status { :used }
      used_by { association :user, strategy: :create }
      used_at { 1.day.ago }
    end

    factory :expired_invitation do
      status { :expired }
      expires_at { 1.day.ago }

      # expires_at_in_future is validated on: :create, so a genuinely past
      # expires_at can never pass normal creation. This fixture represents an
      # invitation that has since expired (valid in the past, now overdue),
      # so we bypass validation the same way `expire_old_codes` mutates rows.
      to_create { |instance| instance.save(validate: false) }
    end

    factory :revoked_invitation do
      status { :revoked }
    end
  end
end
