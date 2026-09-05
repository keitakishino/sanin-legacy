require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'associations' do
    describe 'belongs_to :created_by' do
      it 'has a belongs_to association with User' do
        user = create(:user)
        event = create(:event, created_by_id: user.id)
        expect(event.created_by).to eq(user)
      end
    end
  end

  describe 'validations' do
    describe 'presence validations' do
      it 'validates presence of created_by' do
        event = Event.new(title: 'Test Event', event_date: Date.today)
        expect(event.valid?).to be false
        expect(event.errors[:created_by]).to be_present
      end

      it 'validates presence of title' do
        user = create(:user)
        event = Event.new(event_date: Date.today, created_by: user)
        expect(event.valid?).to be false
        expect(event.errors[:title]).to be_present
      end

      it 'validates presence of event_date' do
        user = create(:user)
        event = Event.new(title: 'Test Event', created_by: user)
        expect(event.valid?).to be false
        expect(event.errors[:event_date]).to be_present
      end
    end

    describe 'length validations' do
      it 'validates title length is at most 255 characters' do
        event = Event.new(title: 'a' * 256, event_date: Date.today)
        expect(event.valid?).to be false
        expect(event.errors[:title]).to be_present
      end
    end

    describe 'date validations' do
      let(:user) { create(:user) }

      it 'rejects past date for event_date' do
        event = Event.new(title: 'Test Event', event_date: Date.today - 1.day, created_by: user)
        expect(event.valid?).to be false
        expect(event.errors[:event_date]).to be_present
      end

      it 'accepts today as event_date' do
        event = Event.new(title: 'Test Event', event_date: Date.today, created_by: user)
        expect(event.valid?).to be true
        expect(event.errors[:event_date]).to be_empty
      end

      it 'accepts future date for event_date' do
        event = Event.new(title: 'Test Event', event_date: Date.today + 1.day, created_by: user)
        expect(event.valid?).to be true
        expect(event.errors[:event_date]).to be_empty
      end
    end

    describe 'error messages' do
      let(:user) { create(:user) }

      context 'when title is blank' do
        it 'displays Japanese error message' do
          original_locale = I18n.locale
          I18n.locale = :ja
          event = Event.new(title: '', event_date: Date.today, created_by: user)
          event.valid?
          expect(event.errors.full_messages).to include("イベント名 を入力してください")
          I18n.locale = original_locale
        end
      end

      context 'when title exceeds max length' do
        it 'displays Japanese error message for too_long' do
          original_locale = I18n.locale
          I18n.locale = :ja
          event = Event.new(title: 'a' * 256, event_date: Date.today, created_by: user)
          event.valid?
          expect(event.errors.full_messages).to include("イベント名 は長すぎます（最大255文字）")
          I18n.locale = original_locale
        end
      end

      context 'when event_date is blank' do
        it 'displays Japanese error message' do
          original_locale = I18n.locale
          I18n.locale = :ja
          event = Event.new(title: 'Test Event', event_date: nil, created_by: user)
          event.valid?
          expect(event.errors.full_messages).to include("イベント日時 を入力してください")
          I18n.locale = original_locale
        end
      end

      context 'when event_date is in the past' do
        it 'displays Japanese error message for past date' do
          original_locale = I18n.locale
          I18n.locale = :ja
          event = Event.new(title: 'Test Event', event_date: Date.today - 1.day, created_by: user)
          event.valid?
          expect(event.errors.full_messages).to include("イベント日時 は過去の日付に設定することはできません")
          I18n.locale = original_locale
        end
      end
    end
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
