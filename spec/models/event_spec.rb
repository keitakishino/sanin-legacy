require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:event_date) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }
  end

  describe 'logical deletion' do
    let(:event) { create(:event) }

    describe '#discard!' do
      it 'sets discarded_at to current time' do
        expect(event.discarded_at).to be_nil
        event.discard!
        expect(event.discarded_at).not_to be_nil
        expect(event.reload.discarded_at).not_to be_nil
      end
    end

    describe '#restore!' do
      let(:discarded_event) { create(:event, discarded_at: Time.current) }

      it 'clears discarded_at' do
        expect(discarded_event.discarded_at).not_to be_nil
        discarded_event.restore!
        expect(discarded_event.discarded_at).to be_nil
        expect(discarded_event.reload.discarded_at).to be_nil
      end
    end

    describe '#discarded?' do
      it 'returns true when discarded_at is present' do
        event.discard!
        expect(event.discarded?).to be true
      end

      it 'returns false when discarded_at is nil' do
        expect(event.discarded?).to be false
      end
    end
  end

  describe 'default_scope' do
    let!(:active_event) { create(:event) }
    let!(:discarded_event) { create(:event, discarded_at: Time.current) }

    it 'excludes discarded events by default' do
      expect(Event.all).to contain_exactly(active_event)
    end

    describe '.with_discarded' do
      it 'includes discarded events' do
        expect(Event.with_discarded.all).to contain_exactly(active_event, discarded_event)
      end
    end

    describe '.only_discarded' do
      it 'returns only discarded events' do
        expect(Event.only_discarded.all).to contain_exactly(discarded_event)
      end
    end
  end
end
