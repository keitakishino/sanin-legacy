class Wishlist < ApplicationRecord
  belongs_to :trade

  enum :edition, {
    normal: '0',
    expanded: '1',
    borderless: '2',
    showcase: '3',
    retro: '4'
  }

  enum :language, {
    any: '0',
    jp: '1',
    en: '2',
    it: '3',
    fr: '4',
    de: '5',
    ct: '6',
    cs: '7',
    ko: '8',
    ru: '9'
  }

  enum :state, {
    playable: '0',
    poor: '1',
    hp: '2',
    mp: '3',
    sp: '4',
    nm: '5',
    signed: '6'
  }
end
