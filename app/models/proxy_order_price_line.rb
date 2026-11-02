class ProxyOrderPriceLine < ApplicationRecord
  belongs_to :proxy_order_item

  validates :unit_price_usd, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :lost_quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :lost_quantity_not_exceed_quantity

  before_create :set_default_lost_quantity

  default_scope { where(discarded_at: nil) }
  scope :with_discarded, -> { unscope(where: :discarded_at) }
  scope :only_discarded, -> { unscope(where: :discarded_at).where.not(discarded_at: nil) }

  def discarded?
    discarded_at.present?
  end

  private

  def set_default_lost_quantity
    self.lost_quantity ||= 0
  end

  def lost_quantity_not_exceed_quantity
    return if quantity.blank? || lost_quantity.blank?
    return if lost_quantity <= quantity

    errors.add(:lost_quantity, :exceeds_quantity)
  end
end
