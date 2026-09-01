class Identity < ApplicationRecord
  belongs_to :user

  enum :provider, { google: 0, twitter: 1 }, prefix: true

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
  validates :user_id, presence: true
  validate :twitter_uid_must_be_numeric

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
    return nil unless valid_twitter_uid?

    base_url = "https://twitter.com/intent/user"
    query_string = "user_id=#{ERB::Util.url_encode(uid)}"
    "#{base_url}?#{query_string}"
  end

  private

  def twitter_uid_must_be_numeric
    return unless provider_twitter? && uid.present?

    errors.add(:uid, :invalid, message: "must be numeric for Twitter identities") unless uid.match?(/\A\d+\z/)
  end

  def valid_twitter_uid?
    uid.match?(/\A\d+\z/)
  end
end
