class TradeCardWant < ApplicationRecord
  belongs_to :trade
  belongs_to :expansion, optional: true

  # Nullable enums representing "不問" (no preference) as nil
  enum :language, { ja: 0, en: 1, other: 2 }, suffix: true
  enum :foil, { foil: 0, non_foil: 1, special: 2 }, suffix: true
  enum :frame, { normal: 0, extended: 1, borderless: 2, showcase: 3, retro: 4 }, suffix: true

  validates :card_name, presence: true
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :amount, numericality: { only_integer: true }, allow_nil: true

  # A13: language, foil, frame are nullable (representing "不問"/no preference)
  #      conditions is an integer array where nil or empty array means "不問"
  #      Values: nm(0)/sp(1)/mp(2)/hp(3)/poor(4)
  validate :conditions_values_valid

  # A18: Custom validation for duplicate card entries within the same trade
  #      will be implemented in Issue #45

  private

  def conditions_values_valid
    return if conditions.nil? || conditions.empty?

    unless conditions.all? { |val| val.is_a?(Integer) && (0..4).include?(val) }
      errors.add(:conditions, "must contain only integers between 0 and 4")
    end
  end
end
