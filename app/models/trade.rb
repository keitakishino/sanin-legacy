class Trade < ApplicationRecord
  belongs_to :event
  belongs_to :user
  belongs_to :completed_by, class_name: "User", foreign_key: :completed_by_id, optional: true
  belongs_to :spreadsheet_exported_by, class_name: "User", foreign_key: :spreadsheet_exported_by_id, optional: true

  has_many :trade_card_offers, dependent: :destroy
  has_many :trade_card_wants, dependent: :destroy

  enum :status, { pending: 0, in_progress: 1, completed: 2, cancelled: 3 }

  validates :status, presence: true
  validates :offers_total_amount, :wants_total_amount, :net_amount, numericality: { only_integer: true }
  validate :validate_status_transition

  def recalculate_totals!
    new_offers_total = trade_card_offers.sum(:amount) || 0
    new_wants_total = trade_card_wants.sum(:amount) || 0
    new_net = new_offers_total - new_wants_total

    update!(
      offers_total_amount: new_offers_total,
      wants_total_amount: new_wants_total,
      net_amount: new_net
    )
  end

  private

  def validate_status_transition
    return if status_was.nil? || status.nil?
    return if status == status_was

    allowed_transitions = {
      "pending" => %w[in_progress completed cancelled],
      "in_progress" => %w[completed cancelled],
      "completed" => [],
      "cancelled" => []
    }

    return if allowed_transitions[status_was]&.include?(status)

    errors.add(:status, "は現在のステータス（#{status_was}）から変更することができません")
  end

  # A18: Custom validation for duplicate card entries will be implemented in Issue #45
  # A17: Automatic calculation of offers_total_amount, wants_total_amount, and net_amount
  #      will be implemented in Issue #47
end
