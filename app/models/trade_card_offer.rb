class TradeCardOffer < ApplicationRecord
  belongs_to :trade
  belongs_to :expansion, optional: true

  enum :language, { ja: 0, en: 1, other: 2 }
  enum :condition, { nm: 0, sp: 1, mp: 2, hp: 3, poor: 4, none: 5 }, suffix: true
  enum :foil, { foil: 0, non_foil: 1, special: 2 }
  enum :frame, { normal: 0, extended: 1, borderless: 2, showcase: 3 }

  validates :card_name, presence: true
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :language, :condition, :foil, :frame, presence: true
  validates :pw_mark, inclusion: { in: [ true, false ] }
  validates :amount, numericality: { only_integer: true }, allow_nil: true

  # A18: Custom validation for duplicate card entries within the same trade
  #      will be implemented in Issue #45
end
