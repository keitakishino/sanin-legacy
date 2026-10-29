class Identity < ApplicationRecord
  belongs_to :user

  enum :provider, { google: 0, discord: 2 }, prefix: true # 1 is twitter's legacy slot

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
  validates :user_id, presence: true
  validate :discord_uid_must_be_numeric

  scope :by_provider, ->(provider) { where(provider: provider) }
  scope :google_identities, -> { where(provider: :google) }
  scope :discord_identities, -> { where(provider: :discord) }

  def provider_display_name
    case provider
    when "google"
      "Google"
    when "discord"
      "Discord"
    end
  end

  private

  def discord_uid_must_be_numeric
    return unless provider_discord? && uid.present?

    errors.add(:uid, :invalid, message: "must be numeric for Discord identities") unless uid.match?(/\A\d+\z/)
  end
end
