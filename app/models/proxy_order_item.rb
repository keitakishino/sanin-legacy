class ProxyOrderItem < ApplicationRecord
  belongs_to :proxy_order
  belongs_to :expansion, optional: true
  has_many :proxy_order_price_lines, dependent: :destroy
  has_many :proxy_order_allocations, dependent: :destroy

  enum :foil, { foil: 0, non_foil: 1, special: 2 }
  enum :frame, { normal: 0, extended: 1, borderless: 2, showcase: 3, retro: 4 }

  validates :card_name, presence: true

  validate :no_duplicate_card_entry

  default_scope { where(discarded_at: nil) }
  scope :with_discarded, -> { unscope(where: :discarded_at) }
  scope :only_discarded, -> { unscope(where: :discarded_at).where.not(discarded_at: nil) }

  def discarded?
    discarded_at.present?
  end

  def ordered_quantity
    proxy_order_price_lines.sum(&:quantity)
  end

  def allocated_quantity
    proxy_order_allocations.sum(&:quantity)
  end

  def remaining_allocation_quantity
    remaining = ordered_quantity - allocated_quantity
    remaining.positive? ? remaining : 1
  end

  def quantity_mismatch?
    ordered_quantity != allocated_quantity
  end

  def lost_ordered_quantity
    proxy_order_price_lines.sum(&:lost_quantity)
  end

  def lost_allocated_quantity
    proxy_order_allocations.sum(&:lost_quantity)
  end

  def lost_mismatch?
    lost_ordered_quantity != lost_allocated_quantity
  end

  private

  def no_duplicate_card_entry
    return if proxy_order.blank?

    duplicates = proxy_order.proxy_order_items
      .where(expansion_id:, foil:, frame:)
      .where("LOWER(proxy_order_items.card_name) = LOWER(?)", card_name)
    duplicates = duplicates.where.not(id:) if persisted?

    return if duplicates.empty?

    errors.add(:base, :duplicate_card_entry)
  end
end
