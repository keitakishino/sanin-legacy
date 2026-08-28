require 'rails_helper'

describe TradeCardWant, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:trade) }
    it { is_expected.to belong_to(:expansion).optional }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:language).with_values(ja: 0, en: 1, other: 2).with_suffix }
    it { is_expected.to define_enum_for(:foil).with_values(foil: 0, non_foil: 1, special: 2).with_suffix }
    it { is_expected.to define_enum_for(:frame).with_values(normal: 0, extended: 1, borderless: 2, showcase: 3, retro: 4).with_suffix }
  end

  describe 'validations' do
    subject { build(:trade_card_want) }

    it { is_expected.to validate_presence_of(:card_name) }
    it { is_expected.to validate_presence_of(:quantity) }
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

    context 'conditions validation' do
      it 'accepts valid conditions array (0-4)' do
        subject.conditions = [ 0, 1, 2 ]
        expect(subject).to be_valid
      end

      it 'accepts nil conditions (representing "不問")' do
        subject.conditions = nil
        expect(subject).to be_valid
      end

      it 'accepts empty array for conditions (representing "不問")' do
        subject.conditions = []
        expect(subject).to be_valid
      end

      it 'rejects invalid conditions values' do
        subject.conditions = [ 0, 5 ]
        expect(subject).to be_invalid
      end
    end
  end

  describe 'nullable enums (representing "不問")' do
    subject { build(:trade_card_want) }

    it 'allows nil language (representing "不問")' do
      subject.language = nil
      expect(subject).to be_valid
    end

    it 'allows nil foil (representing "不問")' do
      subject.foil = nil
      expect(subject).to be_valid
    end

    it 'allows nil frame (representing "不問")' do
      subject.frame = nil
      expect(subject).to be_valid
    end

    it 'allows specific language value' do
      subject.language = :ja
      expect(subject).to be_valid
    end

    it 'allows specific foil value' do
      subject.foil = :foil
      expect(subject).to be_valid
    end

    it 'allows specific frame value' do
      subject.frame = :normal
      expect(subject).to be_valid
    end
  end

  describe 'quantity validation' do
    it 'ensures Rails validation prevents quantity <= 0' do
      trade = create(:trade)
      want = build(:trade_card_want, trade: trade, quantity: 0)
      expect(want).to be_invalid
    end
  end
end
