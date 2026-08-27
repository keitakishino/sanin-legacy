class Invitation < ApplicationRecord
  belongs_to :issued_by, class_name: "User"
  belongs_to :used_by, class_name: "User", optional: true

  enum :status, { active: 0, used: 1, expired: 2, revoked: 3 }, prefix: true

  validates :code, presence: true, uniqueness: true, format: { with: /\A[a-zA-Z0-9]+\z/, message: "must contain only alphanumeric characters" }
  validates :issued_by_id, presence: true
  validates :status, presence: true
  validates :expires_at, presence: true
  validates :signup_token, uniqueness: { allow_nil: true }

  validate :issued_by_is_admin, on: :create
  validate :expires_at_in_future, on: :create

  scope :active_invitations, -> { where(status: :active) }
  scope :used_invitations, -> { where(status: :used) }
  scope :expired_invitations, -> { where(status: :expired) }
  scope :revoked_invitations, -> { where(status: :revoked) }
  scope :not_used, -> { where(status: [ :active, :expired, :revoked ]) }
  scope :expired_and_active, -> { where(status: [ :expired, :active ]) }

  def expired?
    expires_at < Time.current
  end

  def used?
    status_used?
  end

  def available?
    status_active? && !expired?
  end

  def use_by(user)
    update(used_by: user, used_at: Time.current, status: :used)
  end

  def generate_signup_token
    token = SecureRandom.alphanumeric(24)
    update(signup_token: token, signup_token_expires_at: 1.hour.from_now)
    token
  end

  class << self
    def find_by_code(code)
      find_by(code: code)
    end

    def find_by_signup_token(token)
      find_by(signup_token: token)
    end

    def expire_old_codes
      where(status: :active).where("expires_at < ?", Time.current).update_all(status: :expired)
    end
  end

  private

  def issued_by_is_admin
    errors.add(:issued_by, "must be an admin user") unless issued_by&.role_admin?
  end

  def expires_at_in_future
    errors.add(:expires_at, "must be in the future") if expires_at.present? && expires_at < Time.current
  end
end
