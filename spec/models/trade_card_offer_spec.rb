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

      it 'validates quantity < 0' do
        subject.quantity = -1
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

  describe 'duplicate card entry validation (A18)' do
    let(:trade) { create(:trade) }

    context 'when no duplicate exists' do
      it 'allows saving a new offer' do
        offer = build(:trade_card_offer, trade: trade)
        expect(offer).to be_valid
        expect { offer.save }.to change { TradeCardOffer.count }.by(1)
      end
    end

    context 'when duplicate card entry exists in the same trade' do
      let(:existing_offer) do
        create(:trade_card_offer,
          trade: trade,
          card_name: "Black Lotus",
          language: :ja,
          condition: :nm,
          foil: :foil,
          frame: :normal,
          pw_mark: true,
          expansion_id: nil)
      end

      it 'rejects duplicate card entry' do
        existing_offer
        duplicate = build(:trade_card_offer,
          trade: trade,
          card_name: "Black Lotus",
          language: :ja,
          condition: :nm,
          foil: :foil,
          frame: :normal,
          pw_mark: true,
          expansion_id: nil)
        expect(duplicate).to be_invalid
        expect(duplicate.errors[:base]).to include("このカード明細は既に登録されています")
      end

      it 'does not create the duplicate record' do
        existing_offer
        duplicate = build(:trade_card_offer,
          trade: trade,
          card_name: "Black Lotus",
          language: :ja,
          condition: :nm,
          foil: :foil,
          frame: :normal,
          pw_mark: true,
          expansion_id: nil)
        expect { duplicate.save }.not_to change { TradeCardOffer.count }
      end
    end

    context 'when expansion_id is nil for both records' do
      let(:existing_offer) do
        create(:trade_card_offer,
          trade: trade,
          card_name: "Beta Card",
          expansion_id: nil)
      end

      it 'correctly identifies duplicates with nil expansion_id' do
        existing_offer
        duplicate = build(:trade_card_offer,
          trade: trade,
          card_name: "Beta Card",
          expansion_id: nil)
        expect(duplicate).to be_invalid
      end
    end

    context 'when records are in different trades' do
      let(:other_trade) { create(:trade) }

      it 'allows the same card in different trades' do
        create(:trade_card_offer,
          trade: trade,
          card_name: "Card A",
          language: :ja,
          condition: :nm,
          foil: :foil,
          frame: :normal,
          pw_mark: false)

        same_card = build(:trade_card_offer,
          trade: other_trade,
          card_name: "Card A",
          language: :ja,
          condition: :nm,
          foil: :foil,
          frame: :normal,
          pw_mark: false)

        expect(same_card).to be_valid
      end
    end

    context 'when updating an existing record' do
      let(:offer) { create(:trade_card_offer, trade: trade) }

      it 'allows re-saving the same record without duplication error' do
        offer.quantity = 2
        expect(offer).to be_valid
        expect { offer.save }.not_to raise_error
      end
    end

    context 'when any attribute differs from existing duplicate key' do
      let(:existing_offer) do
        create(:trade_card_offer,
          trade: trade,
          card_name: "Card",
          language: :ja,
          condition: :nm,
          foil: :foil,
          frame: :normal,
          pw_mark: false)
      end

      it 'allows different language' do
        existing_offer
        different = build(:trade_card_offer,
          trade: trade,
          card_name: "Card",
          language: :en,
          condition: :nm,
          foil: :foil,
          frame: :normal,
          pw_mark: false)
        expect(different).to be_valid
      end

      it 'allows different condition' do
        existing_offer
        different = build(:trade_card_offer,
          trade: trade,
          card_name: "Card",
          language: :ja,
          condition: :sp,
          foil: :foil,
          frame: :normal,
          pw_mark: false)
        expect(different).to be_valid
      end

      it 'allows different foil status' do
        existing_offer
        different = build(:trade_card_offer,
          trade: trade,
          card_name: "Card",
          language: :ja,
          condition: :nm,
          foil: :non_foil,
          frame: :normal,
          pw_mark: false)
        expect(different).to be_valid
      end

      it 'allows different frame' do
        existing_offer
        different = build(:trade_card_offer,
          trade: trade,
          card_name: "Card",
          language: :ja,
          condition: :nm,
          foil: :foil,
          frame: :extended,
          pw_mark: false)
        expect(different).to be_valid
      end

      it 'allows different pw_mark' do
        existing_offer
        different = build(:trade_card_offer,
          trade: trade,
          card_name: "Card",
          language: :ja,
          condition: :nm,
          foil: :foil,
          frame: :normal,
          pw_mark: true)
        expect(different).to be_valid
      end

      it 'allows different expansion_id' do
        existing_offer
        expansion = create(:expansion)
        different = build(:trade_card_offer,
          trade: trade,
          card_name: "Card",
          language: :ja,
          condition: :nm,
          foil: :foil,
          frame: :normal,
          pw_mark: false,
          expansion_id: expansion.id)
        expect(different).to be_valid
      end
    end
  end

  describe 'automatic trade totals recalculation (Issue #47)' do
    let(:trade) { create(:trade) }

    context 'after_save callback' do
      it 'recalculates trade totals when a new offer is saved' do
        expect_any_instance_of(Trade).to receive(:recalculate_totals!).once
        create(:trade_card_offer, trade: trade, amount: 1000)
      end

      it 'recalculates trade totals when an existing offer is updated' do
        offer = create(:trade_card_offer, trade: trade, amount: 1000)
        trade.reload

        expect_any_instance_of(Trade).to receive(:recalculate_totals!).once
        offer.update(amount: 2000)
      end

      it 'updates trade totals correctly after saving offer with amount' do
        create(:trade_card_offer, trade: trade, amount: 1000)
        trade.reload
        expect(trade.offers_total_amount).to eq(1000)
        expect(trade.wants_total_amount).to eq(0)
        expect(trade.net_amount).to eq(1000)
      end

      it 'updates trade totals correctly after saving multiple offers' do
        create(:trade_card_offer, trade: trade, amount: 1000)
        create(:trade_card_offer, trade: trade, amount: 500)
        trade.reload
        expect(trade.offers_total_amount).to eq(1500)
      end
    end

    context 'after_destroy callback' do
      it 'recalculates trade totals when an offer is destroyed' do
        offer = create(:trade_card_offer, trade: trade, amount: 1000)
        trade.reload

        expect_any_instance_of(Trade).to receive(:recalculate_totals!).once
        offer.destroy
      end

      it 'updates trade totals correctly after destroying offer' do
        offer1 = create(:trade_card_offer, trade: trade, amount: 1000)
        create(:trade_card_offer, trade: trade, amount: 500)
        trade.reload
        initial_total = trade.offers_total_amount

        offer1.destroy
        trade.reload

        expect(trade.offers_total_amount).to eq(initial_total - 1000)
      end

      it 'sets trade totals to 0 when all offers are destroyed' do
        offer1 = create(:trade_card_offer, trade: trade, amount: 1000)
        offer2 = create(:trade_card_offer, trade: trade, amount: 500)
        trade.reload

        offer1.destroy
        offer2.destroy
        trade.reload

        expect(trade.offers_total_amount).to eq(0)
        expect(trade.net_amount).to eq(0)
      end
    end
  end
end
