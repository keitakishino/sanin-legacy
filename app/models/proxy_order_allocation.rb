class ProxyOrderAllocation < ApplicationRecord
  belongs_to :proxy_order_item
  belongs_to :proxy_order_participant

  validates :proxy_order_participant_id, uniqueness: { scope: :proxy_order_item_id }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :lost_quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :lost_quantity_not_exceed_quantity
  validate :participant_in_same_order

  private

  def lost_quantity_not_exceed_quantity
    return if quantity.blank? || lost_quantity.blank?
    return if lost_quantity <= quantity

    errors.add(:lost_quantity, :exceeds_quantity)
  end

  def participant_in_same_order
    return if proxy_order_item.blank? || proxy_order_participant.blank?
    return if proxy_order_item.proxy_order_id == proxy_order_participant.proxy_order_id

    errors.add(:proxy_order_participant, :must_belong_to_same_order)
  end
end
