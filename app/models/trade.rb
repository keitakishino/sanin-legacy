class Trade < ApplicationRecord
  belongs_to :event
  belongs_to :user
  belongs_to :completed_by, class_name: "User", foreign_key: :completed_by_id, optional: true

  has_many :trade_card_offers, dependent: :destroy
  has_many :trade_card_wants, dependent: :destroy

  enum :status, { pending: 0, in_progress: 1, completed: 2, cancelled: 3 }

  validates :status, presence: true
  validates :offers_total_amount, :wants_total_amount, :net_amount, numericality: { only_integer: true }

  # Scopes for logical deletion
  default_scope { where(discarded_at: nil) }
  scope :with_discarded, -> { unscope(where: :discarded_at) }
  scope :only_discarded, -> { with_discarded.where.not(discarded_at: nil) }

  # Logical deletion methods
  def discard!
    update(discarded_at: Time.current)
    trade_card_offers.each { |offer| offer.discard! }
    trade_card_wants.each { |want| want.discard! }
  end

  def restore!
    update(discarded_at: nil)
  end

  def discarded?
    discarded_at.present?
  end

  # Card detail operation permission matrix (from design doc):
  # - pending: all operations (create/update/destroy) allowed for all users
  # - in_progress: create/admin ops allowed; update/destroy denied for general users
  # - completed: all operations denied for all users
  # - cancelled: all operations allowed for all users
  def card_detail_denial_reason(user, action)
    action = action.to_sym
    return :completed if completed?
    return :in_progress if in_progress? && !user&.role_admin? && %i[update destroy].include?(action)
    nil
  end

  def card_detail_operation_allowed?(user, action)
    card_detail_denial_reason(user, action).nil?
  end

  def recalculate_totals!
    new_offers_total = trade_card_offers.sum("amount * quantity") || 0
    new_wants_total = trade_card_wants.sum("amount * quantity") || 0
    new_net = new_offers_total - new_wants_total

    update!(
      offers_total_amount: new_offers_total,
      wants_total_amount: new_wants_total,
      net_amount: new_net
    )
  end
end
