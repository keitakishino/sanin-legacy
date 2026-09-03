class Expansion < ApplicationRecord
  validates :scryfall_set_code, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :name, presence: true, length: { maximum: 255 }
  validates :name_ja, length: { maximum: 255 }, allow_nil: true

  scope :search_by_code, ->(query) {
    return none if query.blank?
    where("LOWER(scryfall_set_code) LIKE LOWER(?)", "#{query}%").limit(8)
  }
end
