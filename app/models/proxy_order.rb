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

  TRANSITIONS = { "ordered" => %w[arrived], "arrived" => %w[completed ordered], "completed" => %w[arrived] }.freeze

  def discarded?
    discarded_at.present?
  end

  def details_editable?
    ordered?
  end

  def fees_editable?
    !completed?
  end

  def arrival_inputs_editable?
    arrived?
  end

  def transition_to(new_status)
    errors.clear
    new_status = new_status.to_s

    unless self.class.statuses.key?(new_status) && TRANSITIONS[status]&.include?(new_status)
      errors.add(:base, :invalid_status_transition)
      return false
    end

    if new_status == "arrived" && status == "ordered"
      if usd_jpy_rate.nil?
        errors.add(:base, :rate_required_for_arrival)
      end

      mismatched_items = proxy_order_items.includes(:proxy_order_price_lines, :proxy_order_allocations).select(&:quantity_mismatch?)
      if mismatched_items.any?
        card_names = mismatched_items.map(&:card_name).join("、")
        errors.add(:base, :quantity_mismatch_for_arrival, cards: card_names)
      end
    end

    if new_status == "completed" && status == "arrived"
      mismatched_items = proxy_order_items.includes(:proxy_order_price_lines, :proxy_order_allocations).select(&:lost_mismatch?)
      if mismatched_items.any?
        card_names = mismatched_items.map(&:card_name).join("、")
        errors.add(:base, :lost_mismatch_for_completion, cards: card_names)
      end

      calc = ProxyOrderCalculator.new(self)
      unpaid_unchecked = proxy_order_participants.select do |p|
        calc.payment_jpy(p) != 0 && p.handed_over_at.nil?
      end
      if unpaid_unchecked.any?
        participant_names = unpaid_unchecked.map { |p| p.user&.username || p.guest_name }.join("、")
        errors.add(:base, :handover_required_for_completion, participants: participant_names)
      end
    end

    return false if errors.any?

    update(status: new_status)
  end

  private

  def event_must_be_proxy_order_type
    return if event.blank?
    return if event.proxy_order?

    errors.add(:event, :must_be_proxy_order_event)
  end
end
