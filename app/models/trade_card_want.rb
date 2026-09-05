class TradeCardWant < ApplicationRecord
  belongs_to :trade
  belongs_to :expansion, optional: true

  # Nullable enums representing "不問" (no preference) as nil
  enum :language, { ja: 0, en: 1, other: 2 }, suffix: true
  enum :foil, { foil: 0, non_foil: 1, special: 2 }, suffix: true
  enum :frame, { normal: 0, extended: 1, borderless: 2, showcase: 3, retro: 4 }, suffix: true

  validates :card_name, presence: true
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # A13: language, foil, frame are nullable (representing "不問"/no preference)
  #      conditions is an integer array where nil or empty array means "不問"
  #      Values: nm(0)/sp(1)/mp(2)/hp(3)/poor(4)
  validate :conditions_values_valid
  validate :no_duplicate_card_entry

  after_save :recalculate_trade_totals
  after_destroy :recalculate_trade_totals

  def conditions_to_display
    return "不問" if conditions.nil? || conditions.empty?

    labels = {
      0 => "NM",
      1 => "SP",
      2 => "MP",
      3 => "HP",
      4 => "Poor"
    }

    conditions.map { |c| labels[c] }.join("/")
  end

  private

  def recalculate_trade_totals
    trade.recalculate_totals! if trade.present?
  end

  def conditions_values_valid
    return if conditions.nil? || conditions.empty?

    unless conditions.all? { |val| val.is_a?(Integer) && (0..4).include?(val) }
      errors.add(:conditions, "must contain only integers between 0 and 4")
    end
  end

  def no_duplicate_card_entry
    return if trade.blank?

    normalized_conditions = normalize_conditions(conditions)

    duplicate_candidates = trade.trade_card_wants.where(
      card_name: card_name,
      language: language,
      foil: foil,
      frame: frame,
      expansion_id: expansion_id
    )
    duplicate_candidates = duplicate_candidates.where.not(id: id) if persisted?

    # Each loop is acceptable here as duplicate_candidates are expected to be few per trade
    duplicate_candidates.each do |candidate|
      if normalize_conditions(candidate.conditions) == normalized_conditions
        errors.add(:base, "このカード明細は既に登録されています")
        break
      end
    end
  end

  def normalize_conditions(conds)
    return nil if conds.nil? || conds.empty?
    conds.sort
  end
end
