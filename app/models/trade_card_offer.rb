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
  validates :amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  validate :no_duplicate_card_entry

  after_save :recalculate_trade_totals
  after_destroy :recalculate_trade_totals

  private

  def recalculate_trade_totals
    trade.recalculate_totals! if trade.present?
  end

  def no_duplicate_card_entry
    return if trade.blank?

    duplicate_key = {
      card_name: card_name,
      language: language,
      condition: condition,
      foil: foil,
      frame: frame,
      pw_mark: pw_mark,
      expansion_id: expansion_id
    }

    scope = trade.trade_card_offers.where(duplicate_key)
    scope = scope.where.not(id: id) if persisted?

    errors.add(:base, "このカード明細は既に登録されています") if scope.exists?
  end
end
