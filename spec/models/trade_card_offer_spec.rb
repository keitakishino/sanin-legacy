require 'rails_helper'

describe TradeCardOffer, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:trade) }
    it { is_expected.to belong_to(:expansion).optional }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:language).with_values(ja: 0, en: 1, other: 2) }
    it { is_expected.to define_enum_for(:condition).with_values(nm: 0, sp: 1, mp: 2, hp: 3, poor: 4, none: 5).with_suffix }
    it { is_expected.to define_enum_for(:foil).with_values(foil: 0, non_foil: 1, special: 2) }
    it { is_expected.to define_enum_for(:frame).with_values(normal: 0, extended: 1, borderless: 2, showcase: 3) }
  end

  describe 'validations' do
    subject { build(:trade_card_offer) }

    it { is_expected.to validate_presence_of(:card_name) }
    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_presence_of(:language) }
    it { is_expected.to validate_presence_of(:condition) }
    it { is_expected.to validate_presence_of(:foil) }
    it { is_expected.to validate_presence_of(:frame) }
    it { is_expected.to validate_inclusion_of(:pw_mark).in_array([ true, false ]) }
    it { is_expected.to validate_numericality_of(:amount).only_integer.allow_nil }

    context 'quantity validation' do
      it 'validates quantity > 0' do
        subject.quantity = 0
        expect(subject).to be_invalid
      end

      it 'validates quantity is a positive integer' do
        subject.quantity = 1
        expect(subject).to be_valid
      end
    end
  end

  describe 'quantity validation' do
    it 'ensures Rails validation prevents quantity <= 0' do
      trade = create(:trade)
      offer = build(:trade_card_offer, trade: trade, quantity: 0)
      expect(offer).to be_invalid
    end
  end
end
