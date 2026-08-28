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
end
