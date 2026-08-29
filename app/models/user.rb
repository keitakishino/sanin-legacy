class User < ApplicationRecord
  has_secure_password validations: false

  has_many :identities, dependent: :destroy
  has_many :invitations_issued, class_name: "Invitation", foreign_key: "issued_by_id",
                                 dependent: :restrict_with_exception
  has_many :invitations_used, class_name: "Invitation", foreign_key: "used_by_id",
                               dependent: :restrict_with_exception
  has_many :created_events, class_name: "Event", foreign_key: "created_by_id",
                             dependent: :restrict_with_exception

  enum :role, { general: 0, admin: 1 }, prefix: true

  validates :username, presence: true, uniqueness: true, length: { minimum: 3, maximum: 50 }
  validates :email, uniqueness: { allow_nil: true }, format: { with: URI::MailTo::EMAIL_REGEXP, if: :email? }
  validates :password, :password_confirmation, presence: true, length: { minimum: 8 }, if: :will_save_password?
  validate :password_confirmation_match, if: :will_save_password?

  scope :admins, -> { where(role: :admin) }
  scope :general_users, -> { where(role: :general) }

  private

  def will_save_password?
    password.present? || password_confirmation.present?
  end

  def password_confirmation_match
    return if password_confirmation.blank?

    errors.add(:password_confirmation, :confirmation) if password != password_confirmation
  end
end
