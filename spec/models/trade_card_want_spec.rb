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

      it 'validates quantity < 0' do
        subject.quantity = -1
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

  describe 'duplicate card entry validation (A18)' do
    let(:trade) { create(:trade) }

    context 'when no duplicate exists' do
      it 'allows saving a new want' do
        want = build(:trade_card_want, trade: trade)
        expect(want).to be_valid
        expect { want.save }.to change { TradeCardWant.count }.by(1)
      end
    end

    context 'when duplicate card entry exists in the same trade' do
      let(:existing_want) do
        create(:trade_card_want,
          trade: trade,
          card_name: "Ancestral Recall",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [ 0, 1, 2 ],
          expansion_id: nil)
      end

      it 'rejects duplicate card entry' do
        existing_want
        duplicate = build(:trade_card_want,
          trade: trade,
          card_name: "Ancestral Recall",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [ 0, 1, 2 ],
          expansion_id: nil)
        expect(duplicate).to be_invalid
        expect(duplicate.errors[:base]).to include("このカード明細は既に登録されています")
      end

      it 'does not create the duplicate record' do
        existing_want
        duplicate = build(:trade_card_want,
          trade: trade,
          card_name: "Ancestral Recall",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [ 0, 1, 2 ],
          expansion_id: nil)
        expect { duplicate.save }.not_to change { TradeCardWant.count }
      end
    end

    context 'when conditions array element order differs' do
      let(:existing_want) do
        create(:trade_card_want,
          trade: trade,
          card_name: "Card",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [ 0, 1, 2 ],
          expansion_id: nil)
      end

      it 'treats different order as duplicate (sorted internally)' do
        existing_want
        same_different_order = build(:trade_card_want,
          trade: trade,
          card_name: "Card",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [ 2, 0, 1 ],
          expansion_id: nil)
        expect(same_different_order).to be_invalid
      end
    end

    context 'when conditions: nil and conditions: [] both exist' do
      let(:existing_with_nil) do
        create(:trade_card_want,
          trade: trade,
          card_name: "Card",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: nil,
          expansion_id: nil)
      end

      it 'treats nil and empty array as the same' do
        existing_with_nil
        same_with_empty = build(:trade_card_want,
          trade: trade,
          card_name: "Card",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [],
          expansion_id: nil)
        expect(same_with_empty).to be_invalid
      end
    end

    context 'when language is nil (representing "不問")' do
      let(:existing_want) do
        create(:trade_card_want,
          trade: trade,
          card_name: "Card",
          language: nil,
          foil: :foil,
          frame: :normal,
          conditions: [ 0 ],
          expansion_id: nil)
      end

      it 'treats nil language value as matching nil' do
        existing_want
        duplicate = build(:trade_card_want,
          trade: trade,
          card_name: "Card",
          language: nil,
          foil: :foil,
          frame: :normal,
          conditions: [ 0 ],
          expansion_id: nil)
        expect(duplicate).to be_invalid
      end

      it 'allows specific language when existing has nil' do
        existing_want
        different = build(:trade_card_want,
          trade: trade,
          card_name: "Card",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [ 0 ],
          expansion_id: nil)
        expect(different).to be_valid
      end
    end

    context 'when expansion_id is nil for both records' do
      let(:existing_want) do
        create(:trade_card_want,
          trade: trade,
          card_name: "Beta Card",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: nil,
          expansion_id: nil)
      end

      it 'correctly identifies duplicates with nil expansion_id' do
        existing_want
        duplicate = build(:trade_card_want,
          trade: trade,
          card_name: "Beta Card",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: nil,
          expansion_id: nil)
        expect(duplicate).to be_invalid
      end
    end

    context 'when records are in different trades' do
      let(:other_trade) { create(:trade) }

      it 'allows the same card in different trades' do
        create(:trade_card_want,
          trade: trade,
          card_name: "Card A",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [ 0, 1 ],
          expansion_id: nil)

        same_card = build(:trade_card_want,
          trade: other_trade,
          card_name: "Card A",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [ 0, 1 ],
          expansion_id: nil)

        expect(same_card).to be_valid
      end
    end

    context 'when updating an existing record' do
      let(:want) { create(:trade_card_want, trade: trade) }

      it 'allows re-saving the same record without duplication error' do
        want.quantity = 2
        expect(want).to be_valid
        expect { want.save }.not_to raise_error
      end
    end

    context 'when any key attribute differs from existing duplicate key' do
      let(:existing_want) do
        create(:trade_card_want,
          trade: trade,
          card_name: "Card",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [ 0 ],
          expansion_id: nil)
      end

      it 'allows different card_name' do
        existing_want
        different = build(:trade_card_want,
          trade: trade,
          card_name: "Different Card",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [ 0 ],
          expansion_id: nil)
        expect(different).to be_valid
      end

      it 'allows different language' do
        existing_want
        different = build(:trade_card_want,
          trade: trade,
          card_name: "Card",
          language: :en,
          foil: :foil,
          frame: :normal,
          conditions: [ 0 ],
          expansion_id: nil)
        expect(different).to be_valid
      end

      it 'allows different foil status' do
        existing_want
        different = build(:trade_card_want,
          trade: trade,
          card_name: "Card",
          language: :ja,
          foil: :non_foil,
          frame: :normal,
          conditions: [ 0 ],
          expansion_id: nil)
        expect(different).to be_valid
      end

      it 'allows different frame' do
        existing_want
        different = build(:trade_card_want,
          trade: trade,
          card_name: "Card",
          language: :ja,
          foil: :foil,
          frame: :extended,
          conditions: [ 0 ],
          expansion_id: nil)
        expect(different).to be_valid
      end

      it 'allows different conditions array content' do
        existing_want
        different = build(:trade_card_want,
          trade: trade,
          card_name: "Card",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [ 1, 2 ],
          expansion_id: nil)
        expect(different).to be_valid
      end

      it 'allows different expansion_id' do
        existing_want
        expansion = create(:expansion)
        different = build(:trade_card_want,
          trade: trade,
          card_name: "Card",
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [ 0 ],
          expansion_id: expansion.id)
        expect(different).to be_valid
      end
    end
  end

  describe 'automatic trade totals recalculation (Issue #47)' do
    let(:trade) { create(:trade) }

    context 'after_save callback' do
      it 'recalculates trade totals when a new want is saved' do
        expect_any_instance_of(Trade).to receive(:recalculate_totals!).once
        create(:trade_card_want, trade: trade, amount: 1000)
      end

      it 'recalculates trade totals when an existing want is updated' do
        want = create(:trade_card_want, trade: trade, amount: 1000)
        trade.reload

        expect_any_instance_of(Trade).to receive(:recalculate_totals!).once
        want.update(amount: 2000)
      end

      it 'updates trade totals correctly after saving want with amount' do
        create(:trade_card_want, trade: trade, amount: 1000)
        trade.reload
        expect(trade.wants_total_amount).to eq(1000)
        expect(trade.offers_total_amount).to eq(0)
        expect(trade.net_amount).to eq(-1000)
      end

      it 'updates trade totals correctly after saving multiple wants' do
        create(:trade_card_want, trade: trade, amount: 1000)
        create(:trade_card_want, trade: trade, amount: 500)
        trade.reload
        expect(trade.wants_total_amount).to eq(1500)
      end
    end

    context 'after_destroy callback' do
      it 'recalculates trade totals when a want is destroyed' do
        want = create(:trade_card_want, trade: trade, amount: 1000)
        trade.reload

        expect_any_instance_of(Trade).to receive(:recalculate_totals!).once
        want.destroy
      end

      it 'updates trade totals correctly after destroying want' do
        want1 = create(:trade_card_want, trade: trade, amount: 1000)
        create(:trade_card_want, trade: trade, amount: 500)
        trade.reload
        initial_total = trade.wants_total_amount

        want1.destroy
        trade.reload

        expect(trade.wants_total_amount).to eq(initial_total - 1000)
      end

      it 'sets trade totals to 0 when all wants are destroyed' do
        want1 = create(:trade_card_want, trade: trade, amount: 1000)
        want2 = create(:trade_card_want, trade: trade, amount: 500)
        trade.reload

        want1.destroy
        want2.destroy
        trade.reload

        expect(trade.wants_total_amount).to eq(0)
        expect(trade.net_amount).to eq(0)
      end
    end
  end
end
