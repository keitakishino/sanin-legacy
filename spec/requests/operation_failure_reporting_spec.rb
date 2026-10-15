require "rails_helper"

RSpec.describe "Operation Failure Reporting", type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:user) }

  shared_context "with mocked Discord and throttle" do
    before do
      @original_webhook_url = Rails.configuration.x.discord_error_webhook_url
      Rails.configuration.x.discord_error_webhook_url = "https://discord.com/api/webhooks/123/abc"

      allow_any_instance_of(ErrorNotification::Throttle).to receive(:check).and_return([ true, 0 ])

      # Reset and set up fresh mock, avoiding carry-over from other specs
      allow(ErrorNotification::DiscordSender).to receive(:deliver_later).and_call_original
    end

    after do
      Rails.configuration.x.discord_error_webhook_url = @original_webhook_url
      # Clear the mock to prevent carry-over
      allow(ErrorNotification::DiscordSender).to receive(:deliver_later).and_call_original
    end
  end

  describe "C1: Event discard failure reports to Rails.error and sends Discord notification" do
    include_context "with mocked Discord and throttle"

    before do
      post signin_path, params: { email: admin_user.email, password: "password123" }
    end

    it "reports OperationFailed error when event discard fails" do
      event = create(:event)

      allow_any_instance_of(Event).to receive(:save).and_wrap_original do |m, *args, **kw|
        if kw[:context] == :discard
          m.receiver.errors.add(:base, "論理削除に失敗しました")
          false
        else
          m.call(*args, **kw)
        end
      end

      allow(Rails.error).to receive(:report).and_call_original

      delete admin_event_path(event)

      expect(Rails.error).to have_received(:report).with(
        instance_of(ErrorNotification::OperationFailed), any_args
      ).once { |error, **kwargs|
        expect(error.message).to include("event.discard failed")
      }
    end

    it "sends Discord notification with error details" do
      event = create(:event)

      allow_any_instance_of(Event).to receive(:save).and_wrap_original do |m, *args, **kw|
        if kw[:context] == :discard
          m.receiver.errors.add(:base, "論理削除に失敗しました")
          false
        else
          m.call(*args, **kw)
        end
      end

      allow(ErrorNotification::DiscordSender).to receive(:deliver_later).and_call_original

      delete admin_event_path(event)

      expect(ErrorNotification::DiscordSender).to have_received(:deliver_later).with(
        anything,
        hash_including(content: /ErrorNotification::OperationFailed/)
      ).once
    end
  end

  describe "C2: Event discard failure records to audit logs" do
    include_context "with mocked Discord and throttle"

    before do
      post signin_path, params: { email: admin_user.email, password: "password123" }
    end

    it "records failure in audit_logs with action=event.discard" do
      event = create(:event)

      allow_any_instance_of(Event).to receive(:save).and_wrap_original do |m, *args, **kw|
        if kw[:context] == :discard
          m.receiver.errors.add(:base, "論理削除に失敗しました")
          false
        else
          m.call(*args, **kw)
        end
      end

      expect {
        delete admin_event_path(event)
      }.to change {
        AuditLog.where(action: "event.discard", result: :failure, target_type: "Event", target_id: event.id).count
      }.by(1)
    end

    it "includes failure reason in audit_logs details" do
      event = create(:event)

      allow_any_instance_of(Event).to receive(:save).and_wrap_original do |m, *args, **kw|
        if kw[:context] == :discard
          m.receiver.errors.add(:base, "論理削除に失敗しました")
          false
        else
          m.call(*args, **kw)
        end
      end

      delete admin_event_path(event)

      audit_log = AuditLog.where(action: "event.discard", result: :failure, target_type: "Event", target_id: event.id).last
      expect(audit_log.details["reason"]).to include("論理削除に失敗しました")
    end
  end

  describe "C3: Trade/TradeCardOffer/TradeCardWant discard/destroy failures" do
    include_context "with mocked Discord and throttle"

    before do
      post signin_path, params: { email: admin_user.email, password: "password123" }
    end

    describe "Trade discard failure" do
      it "reports and records when trade discard fails" do
        event = create(:event)
        trade = create(:trade, event: event)

        allow_any_instance_of(Trade).to receive(:update).and_wrap_original do |m, *args, **kw|
          if kw.key?(:discarded_at) || (args.first.is_a?(Hash) && args.first.key?(:discarded_at))
            m.receiver.errors.add(:base, "論理削除に失敗しました")
            false
          else
            m.call(*args, **kw)
          end
        end

        allow(Rails.error).to receive(:report).and_call_original

        expect {
          delete admin_event_path(event)
        }.to change {
          AuditLog.where(action: "trade.discard", result: :failure).count
        }.by(1)

        expect(Rails.error).to have_received(:report).with(
          instance_of(ErrorNotification::OperationFailed), any_args
        ) { |error|
          expect(error.message).to include("trade.discard")
        }
      end
    end

    describe "TradeCardOffer discard failure" do
      it "reports and records when offer discard fails" do
        event = create(:event)
        trade = create(:trade, event: event)
        offer = create(:trade_card_offer, trade: trade)

        allow_any_instance_of(TradeCardOffer).to receive(:discard!) do |r|
          r.errors.add(:base, "提供カード明細削除失敗")
          false
        end

        allow(Rails.error).to receive(:report).and_call_original

        expect {
          delete admin_event_path(event)
        }.to change {
          AuditLog.where(action: "trade_card_offer.discard", result: :failure).count
        }.by(1)

        expect(Rails.error).to have_received(:report).with(
          instance_of(ErrorNotification::OperationFailed), any_args
        ) { |error|
          expect(error.message).to include("trade_card_offer.discard")
        }
      end
    end

    describe "TradeCardOffer destroy failure" do
      include_context "with mocked Discord and throttle"

      it "reports and records when destroy fails" do
        event = create(:event)
        trade = create(:trade, event: event, user: user)
        offer = create(:trade_card_offer, trade: trade)

        post signin_path, params: { email: user.email, password: "password123" }

        # Mock destroyed? to return false (failure state)
        allow_any_instance_of(TradeCardOffer).to receive(:destroyed?).and_return(false)
        # Mock destroy to add errors without actually deleting
        allow_any_instance_of(TradeCardOffer).to receive(:destroy) do |r|
          r.errors.add(:base, "削除できません")
          r
        end

        allow(Rails.error).to receive(:report).and_call_original

        expect {
          delete "/trades/#{event.id}/card_offers/#{offer.id}"
        }.to change {
          AuditLog.where(action: "trade_card_offer.destroy", result: :failure).count
        }.by(1)

        expect(Rails.error).to have_received(:report) do |error, **kwargs|
          expect(error).to be_instance_of(ErrorNotification::OperationFailed)
          expect(error.message).to include("trade_card_offer.destroy")
        end
      end
    end

    describe "TradeCardWant discard failure" do
      it "reports and records when want discard fails" do
        event = create(:event)
        trade = create(:trade, event: event)
        want = create(:trade_card_want, trade: trade)

        allow_any_instance_of(TradeCardWant).to receive(:discard!) do |r|
          r.errors.add(:base, "求めるカード明細削除失敗")
          false
        end

        allow(Rails.error).to receive(:report).and_call_original

        expect {
          delete admin_event_path(event)
        }.to change {
          AuditLog.where(action: "trade_card_want.discard", result: :failure).count
        }.by(1)

        expect(Rails.error).to have_received(:report).with(
          instance_of(ErrorNotification::OperationFailed), any_args
        ) { |error|
          expect(error.message).to include("trade_card_want.discard")
        }
      end
    end

    describe "TradeCardWant destroy failure" do
      include_context "with mocked Discord and throttle"

      it "reports and records when destroy fails" do
        event = create(:event)
        trade = create(:trade, event: event, user: user)
        want = create(:trade_card_want, trade: trade)

        post signin_path, params: { email: user.email, password: "password123" }

        # Mock destroyed? to return false (failure state)
        allow_any_instance_of(TradeCardWant).to receive(:destroyed?).and_return(false)
        # Mock destroy to add errors without actually deleting
        allow_any_instance_of(TradeCardWant).to receive(:destroy) do |r|
          r.errors.add(:base, "削除できません")
          r
        end

        allow(Rails.error).to receive(:report).and_call_original

        expect {
          delete "/trades/#{event.id}/card_wants/#{want.id}"
        }.to change {
          AuditLog.where(action: "trade_card_want.destroy", result: :failure).count
        }.by(1)

        expect(Rails.error).to have_received(:report) do |error, **kwargs|
          expect(error).to be_instance_of(ErrorNotification::OperationFailed)
          expect(error.message).to include("trade_card_want.destroy")
        end
      end
    end
  end

  describe "C4: Past-date event deletion shows success message" do
    include_context "with mocked Discord and throttle"

    before do
      post signin_path, params: { email: admin_user.email, password: "password123" }
    end

    it "redirects and shows success message when deleting past-date event" do
      event = create(:event)
      event.update_column(:event_date, Event.current_date - 1)

      delete admin_event_path(event)
      follow_redirect!

      expect(response.body).to include("イベントを削除しました")
      expect(Event.with_discarded.find(event.id).discarded?).to be true
    end
  end

  describe "C5: Normal event deletion succeeds" do
    include_context "with mocked Discord and throttle"

    before do
      post signin_path, params: { email: admin_user.email, password: "password123" }
    end

    it "discards event and records success in audit_logs" do
      event = create(:event)

      expect {
        delete admin_event_path(event)
      }.to change {
        AuditLog.where(action: "event.discard", result: :success, target_type: "Event", target_id: event.id).count
      }.by(1)

      expect(event.reload.discarded?).to be true
    end

    it "does not report OperationFailed error on success" do
      event = create(:event)

      allow(Rails.error).to receive(:report)

      delete admin_event_path(event)

      expect(Rails.error).not_to have_received(:report).with(
        instance_of(ErrorNotification::OperationFailed), any_args
      )
    end

    it "does not record failure in audit_logs" do
      event = create(:event)

      expect {
        delete admin_event_path(event)
      }.not_to change {
        AuditLog.where(action: "event.discard", result: :failure).count
      }
    end
  end
end
