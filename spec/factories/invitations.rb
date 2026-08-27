FactoryBot.define do
  factory :invitation do
    sequence(:code) { |n| "invite#{n}" }
    issued_by { association :admin_user }
    status { :active }
    expires_at { 7.days.from_now }

    factory :used_invitation do
      status { :used }
      used_by { association :user }
      used_at { 1.day.ago }
    end

    factory :expired_invitation do
      status { :expired }
      expires_at { 1.day.ago }
    end

    factory :revoked_invitation do
      status { :revoked }
    end
  end
end
