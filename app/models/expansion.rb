class Expansion < ApplicationRecord
  validates :scryfall_set_code, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :name, presence: true, length: { maximum: 255 }
  validates :name_ja, length: { maximum: 255 }, allow_nil: true
end
