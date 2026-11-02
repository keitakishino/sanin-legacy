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
        event = Event.new(title: 'Test Event', event_date: Event.current_date)
        expect(event.valid?).to be false
        expect(event.errors[:created_by]).to be_present
      end

      it 'validates presence of title' do
        user = create(:user)
        event = Event.new(event_date: Event.current_date, created_by: user)
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
        event = Event.new(title: 'a' * 256, event_date: Event.current_date)
        expect(event.valid?).to be false
        expect(event.errors[:title]).to be_present
      end
    end

    describe 'date validations' do
      let(:user) { create(:user) }

      it 'rejects past date for event_date' do
        event = Event.new(title: 'Test Event', event_date: Event.current_date - 1.day, created_by: user)
        expect(event.valid?).to be false
        expect(event.errors[:event_date]).to be_present
      end

      it 'accepts today as event_date' do
        event = Event.new(title: 'Test Event', event_date: Event.current_date, created_by: user)
        expect(event.valid?).to be true
        expect(event.errors[:event_date]).to be_empty
      end

      it 'accepts future date for event_date' do
        event = Event.new(title: 'Test Event', event_date: Event.current_date + 1.day, created_by: user)
        expect(event.valid?).to be true
        expect(event.errors[:event_date]).to be_empty
      end
    end

    describe 'event_type validations' do
      let(:user) { create(:user) }

      it 'has default event_type as trade' do
        event = Event.new(title: 'Test Event', event_date: Event.current_date + 1.day, created_by: user)
        expect(event.event_type).to eq('trade')
      end

      it 'allows creating with trade event_type' do
        event = Event.new(title: 'Test Event', event_date: Event.current_date + 1.day, created_by: user, event_type: :trade)
        expect(event.valid?).to be true
      end

      it 'allows creating with tournament event_type' do
        event = Event.new(title: 'Test Event', event_date: Event.current_date + 1.day, created_by: user, event_type: :tournament)
        expect(event.valid?).to be true
        expect(event.tournament?).to be true
      end

      it 'allows creating with proxy_order event_type' do
        event = Event.new(title: 'Test Event', event_date: Event.current_date + 1.day, created_by: user, event_type: :proxy_order)
        expect(event.valid?).to be true
        expect(event.proxy_order?).to be true
      end

      it 'prevents changing event_type after creation' do
        event = create(:event)
        expect(event.trade?).to be true
        event.event_type = :tournament
        expect(event.valid?).to be false
        expect(event.errors[:event_type]).to be_present
      end

      it 'allows updating other attributes after creation' do
        event = create(:event)
        event.title = 'Updated Title'
        event.event_date = Event.current_date + 10.days
        expect(event.valid?).to be true
      end
    end

    # 属性名と本文の間に空白は入らない。ja.errors.format は rails-i18n の
    # "%{attribute}%{message}"。以前は ja に format が無く en の
    # "%{attribute} %{message}" にフォールバックしていたため空白が入っていた
    describe 'error messages' do
      let(:user) { create(:user) }

      context 'when title is blank' do
        it 'displays Japanese error message' do
          with_locale(:ja) do
            event = Event.new(title: '', event_date: Event.current_date, created_by: user)
            event.valid?
            expect(event.errors.full_messages).to include("イベント名を入力してください")
          end
        end
      end

      context 'when title exceeds max length' do
        it 'displays Japanese error message for too_long' do
          with_locale(:ja) do
            event = Event.new(title: 'a' * 256, event_date: Event.current_date, created_by: user)
            event.valid?
            expect(event.errors.full_messages).to include("イベント名は長すぎます（最大255文字）")
          end
        end
      end

      context 'when event_date is blank' do
        it 'displays Japanese error message' do
          with_locale(:ja) do
            event = Event.new(title: 'Test Event', event_date: nil, created_by: user)
            event.valid?
            expect(event.errors.full_messages).to include("イベント日時を入力してください")
          end
        end
      end

      context 'when event_date is in the past' do
        it 'displays Japanese error message for past date' do
          with_locale(:ja) do
            event = Event.new(title: 'Test Event', event_date: Event.current_date - 1.day, created_by: user)
            event.valid?
            expect(event.errors.full_messages).to include("イベント日時は過去の日付に設定することはできません")
          end
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

      it 'cascades discard to all associated trades' do
        trade1 = create(:trade, event: event)
        trade2 = create(:trade, event: event)

        expect(trade1.discarded?).to be false
        expect(trade2.discarded?).to be false

        event.discard!

        expect(trade1.reload.discarded?).to be true
        expect(trade2.reload.discarded?).to be true
      end

      it 'cascades discard through trades to trade_card_offers and trade_card_wants' do
        trade = create(:trade, event: event)
        offer = create(:trade_card_offer, trade: trade)
        want = create(:trade_card_want, trade: trade)

        expect(offer.discarded?).to be false
        expect(want.discarded?).to be false

        event.discard!

        expect(trade.reload.discarded?).to be true
        expect(offer.reload.discarded?).to be true
        expect(want.reload.discarded?).to be true
      end

      context 'when event is a proxy_order event' do
        let(:proxy_event) { create(:event, :proxy_order) }
        let(:proxy_order) { create(:proxy_order, event: proxy_event) }
        let(:item) { create(:proxy_order_item, proxy_order: proxy_order) }
        let(:price_line) { create(:proxy_order_price_line, proxy_order_item: item) }
        let(:participant) { create(:proxy_order_participant, proxy_order: proxy_order) }
        let(:allocation) { create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant) }

        it 'cascades logical deletion to proxy order and its children' do
          # Create all related records
          price_line
          participant
          allocation

          # Pre-discard one item to verify existing discarded_at is not overwritten
          past_time = 1.week.ago.change(usec: 0)
          old_item = create(:proxy_order_item, proxy_order: proxy_order)
          old_item.update_column(:discarded_at, past_time)

          expect(proxy_order.discarded?).to be false
          expect(item.discarded?).to be false
          expect(price_line.discarded?).to be false
          expect(participant.discarded?).to be false
          expect(allocation.discarded?).to be false

          result = proxy_event.discard!

          expect(result).to be true
          expect(proxy_event.reload.discarded?).to be true
          expect(ProxyOrder.with_discarded.find(proxy_order.id).discarded?).to be true
          expect(ProxyOrderItem.with_discarded.find(item.id).discarded?).to be true
          expect(ProxyOrderPriceLine.with_discarded.find(price_line.id).discarded?).to be true
          expect(ProxyOrderParticipant.with_discarded.find(participant.id).discarded?).to be true
          expect(ProxyOrderAllocation.with_discarded.find(allocation.id).discarded?).to be true

          # Verify records are hidden via default_scope
          expect(ProxyOrder.find_by(id: proxy_order.id)).to be_nil
          expect(ProxyOrderItem.find_by(id: item.id)).to be_nil
          expect(ProxyOrderPriceLine.find_by(id: price_line.id)).to be_nil
          expect(ProxyOrderParticipant.find_by(id: participant.id)).to be_nil
          expect(ProxyOrderAllocation.find_by(id: allocation.id)).to be_nil

          # Verify old item's discarded_at was not changed
          expect(ProxyOrderItem.with_discarded.find(old_item.id).discarded_at).to eq(past_time)
        end
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

  describe 'JST 基準の日付判定' do
    let(:user) { create(:user) }

    it 'treats past dates in JST as invalid' do
      travel_to Time.utc(2026, 10, 5, 16, 0) do
        event = Event.new(title: 'Test Event', event_date: Date.new(2026, 10, 5), created_by: user)
        expect(event.valid?).to be false
        expect(event.errors[:event_date]).to be_present
      end
    end

    it 'treats today in JST as valid' do
      travel_to Time.utc(2026, 10, 5, 16, 0) do
        event = Event.new(title: 'Test Event', event_date: Date.new(2026, 10, 6), created_by: user)
        expect(event.valid?).to be true
        expect(event.errors[:event_date]).to be_empty
      end
    end

    it 'returns JST date for Event.current_date' do
      travel_to Time.utc(2026, 10, 5, 16, 0) do
        expect(Event.current_date).to eq(Date.new(2026, 10, 6))
      end
    end
  end
end
