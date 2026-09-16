require 'rails_helper'

describe Trade, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:event) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:completed_by).class_name('User').optional }
    it { is_expected.to belong_to(:spreadsheet_exported_by).class_name('User').optional }
    it { is_expected.to have_many(:trade_card_offers).dependent(:destroy) }
    it { is_expected.to have_many(:trade_card_wants).dependent(:destroy) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, in_progress: 1, completed: 2, cancelled: 3) }
  end

  describe 'validations' do
    subject { build(:trade) }

    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_numericality_of(:offers_total_amount).only_integer }
    it { is_expected.to validate_numericality_of(:wants_total_amount).only_integer }
    it { is_expected.to validate_numericality_of(:net_amount).only_integer }
  end

  describe 'unique constraint' do
    let(:event) { create(:event) }
    let(:user) { create(:user) }

    before do
      create(:trade, event: event, user: user)
    end

    it 'raises error when duplicate [event_id, user_id] is created' do
      expect do
        create(:trade, event: event, user: user)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'logical deletion' do
    let(:trade) { create(:trade) }

    describe '#discard!' do
      it 'sets discarded_at to current time' do
        expect(trade.discarded_at).to be_nil
        trade.discard!
        expect(trade.discarded_at).not_to be_nil
        expect(trade.reload.discarded_at).not_to be_nil
      end

      it 'cascades discard to trade_card_offers' do
        offer1 = create(:trade_card_offer, trade: trade)
        offer2 = create(:trade_card_offer, trade: trade)

        expect(offer1.discarded?).to be false
        expect(offer2.discarded?).to be false

        trade.discard!

        expect(offer1.reload.discarded?).to be true
        expect(offer2.reload.discarded?).to be true
      end

      it 'cascades discard to trade_card_wants' do
        want1 = create(:trade_card_want, trade: trade)
        want2 = create(:trade_card_want, trade: trade)

        expect(want1.discarded?).to be false
        expect(want2.discarded?).to be false

        trade.discard!

        expect(want1.reload.discarded?).to be true
        expect(want2.reload.discarded?).to be true
      end

      it 'cascades discard to both offers and wants' do
        offer = create(:trade_card_offer, trade: trade)
        want = create(:trade_card_want, trade: trade)

        trade.discard!

        expect(offer.reload.discarded?).to be true
        expect(want.reload.discarded?).to be true
      end
    end

    describe '#restore!' do
      let(:discarded_trade) { create(:trade, discarded_at: Time.current) }

      it 'clears discarded_at' do
        expect(discarded_trade.discarded_at).not_to be_nil
        discarded_trade.restore!
        expect(discarded_trade.discarded_at).to be_nil
        expect(discarded_trade.reload.discarded_at).to be_nil
      end
    end

    describe '#discarded?' do
      it 'returns true when discarded_at is present' do
        trade.discard!
        expect(trade.discarded?).to be true
      end

      it 'returns false when discarded_at is nil' do
        expect(trade.discarded?).to be false
      end
    end
  end

  describe 'default_scope' do
    let!(:active_trade) { create(:trade) }
    let!(:discarded_trade) { create(:trade, discarded_at: Time.current) }

    it 'excludes discarded trades by default' do
      expect(Trade.all).to contain_exactly(active_trade)
    end

    describe '.with_discarded' do
      it 'includes discarded trades' do
        expect(Trade.with_discarded.all).to contain_exactly(active_trade, discarded_trade)
      end
    end

    describe '.only_discarded' do
      it 'returns only discarded trades' do
        expect(Trade.only_discarded.all).to contain_exactly(discarded_trade)
      end
    end
  end

  describe '#recalculate_totals!' do
    let(:trade) { create(:trade) }

    context 'with no card entries' do
      it 'sets all totals to 0' do
        trade.recalculate_totals!
        expect(trade.offers_total_amount).to eq(0)
        expect(trade.wants_total_amount).to eq(0)
        expect(trade.net_amount).to eq(0)
      end
    end

    context 'with multiple offers' do
      it 'calculates offers_total_amount as sum of trade_card_offers (amount * quantity)' do
        create(:trade_card_offer, trade: trade, amount: 1000, quantity: 1)
        create(:trade_card_offer, trade: trade, amount: 2000, quantity: 2)
        trade.recalculate_totals!
        expect(trade.offers_total_amount).to eq(5000)
      end
    end

    context 'with multiple wants' do
      it 'calculates wants_total_amount as sum of trade_card_wants (amount * quantity)' do
        create(:trade_card_want, trade: trade, amount: 500, quantity: 2)
        create(:trade_card_want, trade: trade, amount: 1500, quantity: 1)
        trade.recalculate_totals!
        expect(trade.wants_total_amount).to eq(2500)
      end
    end

    context 'with both offers and wants' do
      it 'calculates net_amount as offers_total_amount - wants_total_amount (with amount * quantity)' do
        create(:trade_card_offer, trade: trade, amount: 5000, quantity: 2)
        create(:trade_card_want, trade: trade, amount: 2000, quantity: 3)
        trade.recalculate_totals!
        expect(trade.net_amount).to eq(4000)
      end
    end

    context 'with nil amounts' do
      it 'treats nil amounts as 0 (even when quantity is present)' do
        create(:trade_card_offer, trade: trade, amount: 1000, quantity: 2)
        create(:trade_card_offer, trade: trade, amount: nil, quantity: 1)
        create(:trade_card_want, trade: trade, amount: nil, quantity: 1)
        trade.recalculate_totals!
        expect(trade.offers_total_amount).to eq(2000)
        expect(trade.wants_total_amount).to eq(0)
        expect(trade.net_amount).to eq(2000)
      end
    end

    context 'when net_amount becomes negative' do
      it 'correctly calculates negative net_amount (with amount * quantity)' do
        create(:trade_card_offer, trade: trade, amount: 1000, quantity: 1)
        create(:trade_card_want, trade: trade, amount: 3000, quantity: 1)
        trade.recalculate_totals!
        expect(trade.net_amount).to eq(-2000)
      end
    end
  end
end
