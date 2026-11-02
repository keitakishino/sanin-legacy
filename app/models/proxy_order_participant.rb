class ProxyOrderParticipant < ApplicationRecord
  belongs_to :proxy_order
  belongs_to :user, optional: true
  has_many :proxy_order_allocations, dependent: :destroy

  normalizes :guest_name, with: ->(v) { v.strip.presence }

  validate :user_or_guest_exclusive
  validates :user_id, uniqueness: { scope: :proxy_order_id }, allow_nil: true
  validate :guest_name_unique_in_order
  validate :guest_name_not_conflict_with_username

  default_scope { where(discarded_at: nil) }
  scope :with_discarded, -> { unscope(where: :discarded_at) }
  scope :only_discarded, -> { unscope(where: :discarded_at).where.not(discarded_at: nil) }

  def discarded?
    discarded_at.present?
  end

  class << self
    def normalize_name(name)
      name.to_s.unicode_normalize(:nfkc).strip.downcase
    end
  end

  private

  def user_or_guest_exclusive
    if user_id.nil? && guest_name.nil?
      errors.add(:base, :user_or_guest_required)
    elsif user_id.present? && guest_name.present?
      errors.add(:base, :user_or_guest_required)
    end
  end

  def guest_name_unique_in_order
    return if guest_name.blank?
    return if proxy_order.blank?

    duplicates = proxy_order.proxy_order_participants.where.not(guest_name: nil)
    duplicates = duplicates.where.not(id:) if persisted?

    normalized_guest = self.class.normalize_name(guest_name)
    return if duplicates.all? { |p| self.class.normalize_name(p.guest_name) != normalized_guest }

    errors.add(:guest_name, :taken)
  end

  def guest_name_not_conflict_with_username
    return if guest_name.blank?

    normalized_guest = self.class.normalize_name(guest_name)
    return unless User.pluck(:username).any? { |u| self.class.normalize_name(u) == normalized_guest }

    errors.add(:guest_name, :conflicts_with_username)
  end
end
