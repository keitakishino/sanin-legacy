class Identity < ApplicationRecord
  belongs_to :user

  enum :provider, { google: 0, twitter: 1 }, prefix: true

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
  validates :user_id, presence: true

  scope :by_provider, ->(provider) { where(provider: provider) }
  scope :google_identities, -> { where(provider: :google) }
  scope :twitter_identities, -> { where(provider: :twitter) }

  def provider_display_name
    case provider
    when "google"
      "Google"
    when "twitter"
      "Twitter(X)"
    end
  end

  def twitter_profile_url
    return nil unless provider == "twitter"

    "https://twitter.com/intent/user?user_id=#{uid}"
  end
end
