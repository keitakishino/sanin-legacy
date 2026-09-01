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
      it 'calculates offers_total_amount as sum of trade_card_offers amount' do
        create(:trade_card_offer, trade: trade, amount: 1000)
        create(:trade_card_offer, trade: trade, amount: 2000)
        trade.recalculate_totals!
        expect(trade.offers_total_amount).to eq(3000)
      end
    end

    context 'with multiple wants' do
      it 'calculates wants_total_amount as sum of trade_card_wants amount' do
        create(:trade_card_want, trade: trade, amount: 500)
        create(:trade_card_want, trade: trade, amount: 1500)
        trade.recalculate_totals!
        expect(trade.wants_total_amount).to eq(2000)
      end
    end

    context 'with both offers and wants' do
      it 'calculates net_amount as offers_total_amount - wants_total_amount' do
        create(:trade_card_offer, trade: trade, amount: 5000)
        create(:trade_card_want, trade: trade, amount: 2000)
        trade.recalculate_totals!
        expect(trade.net_amount).to eq(3000)
      end
    end

    context 'with nil amounts' do
      it 'treats nil amounts as 0' do
        create(:trade_card_offer, trade: trade, amount: 1000)
        create(:trade_card_offer, trade: trade, amount: nil)
        create(:trade_card_want, trade: trade, amount: nil)
        trade.recalculate_totals!
        expect(trade.offers_total_amount).to eq(1000)
        expect(trade.wants_total_amount).to eq(0)
        expect(trade.net_amount).to eq(1000)
      end
    end

    context 'when net_amount becomes negative' do
      it 'correctly calculates negative net_amount' do
        create(:trade_card_offer, trade: trade, amount: 1000)
        create(:trade_card_want, trade: trade, amount: 3000)
        trade.recalculate_totals!
        expect(trade.net_amount).to eq(-2000)
      end
    end
  end
end
