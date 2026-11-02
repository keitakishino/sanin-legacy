class ProxyOrder < ApplicationRecord
  belongs_to :event
  has_many :proxy_order_items, dependent: :destroy
  has_many :proxy_order_participants, dependent: :destroy

  enum :status, { ordered: 0, arrived: 1, completed: 2 }, validate: true, default: :ordered

  validates :event_id, uniqueness: true
  validates :tax_usd, :customs_usd, :shipping_usd, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :usd_jpy_rate, numericality: { greater_than: 0 }, allow_nil: true

  validate :event_must_be_proxy_order_type, on: :create

  default_scope { where(discarded_at: nil) }
  scope :with_discarded, -> { unscope(where: :discarded_at) }
  scope :only_discarded, -> { unscope(where: :discarded_at).where.not(discarded_at: nil) }

  def discarded?
    discarded_at.present?
  end

  def discard!
    @discard_failures = []
    now = Time.current
    @discard_failures << self unless update(discarded_at: now)
    return false if @discard_failures.any?

    item_ids = ProxyOrderItem.with_discarded.where(proxy_order_id: id).select(:id)
    ProxyOrderItem.where(proxy_order_id: id, discarded_at: nil).update_all(discarded_at: now, updated_at: now)
    ProxyOrderPriceLine.where(proxy_order_item_id: item_ids, discarded_at: nil).update_all(discarded_at: now, updated_at: now)
    ProxyOrderAllocation.where(proxy_order_item_id: item_ids, discarded_at: nil).update_all(discarded_at: now, updated_at: now)
    ProxyOrderParticipant.where(proxy_order_id: id, discarded_at: nil).update_all(discarded_at: now, updated_at: now)
    true
  end

  def discard_failures
    @discard_failures || []
  end

  private

  def event_must_be_proxy_order_type
    return if event.blank?
    return if event.proxy_order?

    errors.add(:event, :must_be_proxy_order_event)
  end
end
