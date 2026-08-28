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

  # A18: Custom validation for duplicate card entries will be implemented in Issue #45
  # A17: Automatic calculation of offers_total_amount, wants_total_amount, and net_amount
  #      will be implemented in Issue #47
end
