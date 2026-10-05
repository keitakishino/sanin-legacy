require "rails_helper"

RSpec.describe "Audit Log Recording", type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:expansion) { create(:expansion) }

  describe "admin event create" do
    before do
      post signin_path, params: { email: admin_user.email, password: "password123" }
    end

    let(:valid_params) do
      {
        event: {
          title: "New Event",
          description: "d",
          event_date: Date.today + 7.days
        }
      }
    end

    it "records audit log with action=event.create and result=success" do
      expect {
        post admin_events_path, params: valid_params
      }.to change {
        AuditLog.where(action: "event.create", result: :success).count
      }.by(1)
    end

    it "sets target_type to Event" do
      post admin_events_path, params: valid_params
      audit_log = AuditLog.where(action: "event.create", result: :success).last
      expect(audit_log.target_type).to eq("Event")
    end

    it "sets user_id to admin" do
      post admin_events_path, params: valid_params
      audit_log = AuditLog.where(action: "event.create", result: :success).last
      expect(audit_log.user_id).to eq(admin_user.id)
    end
  end

  describe "admin event update" do
    before do
      post signin_path, params: { email: admin_user.email, password: "password123" }
    end

    let(:update_params) do
      {
        event: {
          title: "Updated"
        }
      }
    end

    it "records audit log with action=event.update" do
      expect {
        patch admin_event_path(event), params: update_params
      }.to change {
        AuditLog.where(action: "event.update").count
      }.by(1)
    end
  end

  describe "admin event discard" do
    before do
      post signin_path, params: { email: admin_user.email, password: "password123" }
    end

    it "records audit log with action=event.discard and result=success" do
      expect {
        delete admin_event_path(event)
      }.to change {
        AuditLog.where(action: "event.discard", result: :success, target_type: "Event", target_id: event.id).count
      }.by(1)
    end

    it "records audit log with action=event.discard and result=failure when discard fails" do
      event_to_discard = event

      # Mock discard! to set errors without actually updating
      allow_any_instance_of(Event).to receive(:discard!) do |event_inst|
        event_inst.errors.add(:base, "Discard failed")
      end

      expect {
        delete admin_event_path(event_to_discard)
      }.to change {
        AuditLog.where(action: "event.discard", result: :failure).count
      }.by(1)
    end
  end

  describe "admin trade update" do
    before do
      post signin_path, params: { email: admin_user.email, password: "password123" }
    end

    let(:trade) { create(:trade, event: event, user: user) }

    let(:update_params) do
      {
        trade: {
          status: :in_progress
        }
      }
    end

    it "records audit log with action=trade.update" do
      expect {
        patch admin_event_trade_path(event, trade), params: update_params
      }.to change {
        AuditLog.where(action: "trade.update").count
      }.by(1)
    end
  end

  describe "trade card offer create" do
    before do
      post signin_path, params: { email: user.email, password: "password123" }
    end

    let(:valid_params) do
      {
        trade_card_offer: {
          card_name: "Black Lotus",
          quantity: 1,
          language: :ja,
          condition: :nm,
          foil: :foil,
          frame: :normal,
          pw_mark: false,
          expansion_id: expansion.id,
          note: "Test note"
        }
      }
    end

    it "records audit log with action=trade_card_offer.create" do
      trade = create(:trade, event: event, user: user)
      expect {
        post "/trades/#{event.id}/card_offers", params: valid_params
      }.to change {
        AuditLog.where(action: "trade_card_offer.create").count
      }.by(1)
    end
  end

  describe "trade card offer update" do
    before do
      post signin_path, params: { email: user.email, password: "password123" }
    end

    let(:trade) { create(:trade, event: event, user: user) }
    let(:offer) { create(:trade_card_offer, trade: trade) }

    let(:valid_params) do
      {
        trade_card_offer: {
          quantity: 2
        }
      }
    end

    it "records audit log with action=trade_card_offer.update" do
      expect {
        patch "/trades/#{event.id}/card_offers/#{offer.id}", params: valid_params
      }.to change {
        AuditLog.where(action: "trade_card_offer.update").count
      }.by(1)
    end
  end

  describe "trade card offer destroy" do
    before do
      post signin_path, params: { email: user.email, password: "password123" }
    end

    let(:trade) { create(:trade, event: event, user: user) }
    let(:offer) { create(:trade_card_offer, trade: trade) }

    it "records audit log with action=trade_card_offer.destroy" do
      expect {
        delete "/trades/#{event.id}/card_offers/#{offer.id}"
      }.to change {
        AuditLog.where(action: "trade_card_offer.destroy").count
      }.by(1)
    end
  end

  describe "trade card want create" do
    before do
      post signin_path, params: { email: user.email, password: "password123" }
    end

    let(:valid_params) do
      {
        trade_card_want: {
          card_name: "Black Lotus",
          quantity: 1,
          language: :ja,
          foil: :foil,
          frame: :normal,
          expansion_id: expansion.id,
          note: "Test note",
          conditions: [ "nm" ]
        }
      }
    end

    it "records audit log with action=trade_card_want.create" do
      trade = create(:trade, event: event, user: user)
      expect {
        post "/trades/#{event.id}/card_wants", params: valid_params
      }.to change {
        AuditLog.where(action: "trade_card_want.create").count
      }.by(1)
    end
  end

  describe "trade card want update" do
    before do
      post signin_path, params: { email: user.email, password: "password123" }
    end

    let(:trade) { create(:trade, event: event, user: user) }
    let(:want) { create(:trade_card_want, trade: trade) }

    let(:valid_params) do
      {
        trade_card_want: {
          quantity: 2,
          conditions: [ "nm" ]
        }
      }
    end

    it "records audit log with action=trade_card_want.update" do
      expect {
        patch "/trades/#{event.id}/card_wants/#{want.id}", params: valid_params
      }.to change {
        AuditLog.where(action: "trade_card_want.update").count
      }.by(1)
    end
  end

  describe "trade card want destroy" do
    before do
      post signin_path, params: { email: user.email, password: "password123" }
    end

    let(:trade) { create(:trade, event: event, user: user) }
    let(:want) { create(:trade_card_want, trade: trade) }

    it "records audit log with action=trade_card_want.destroy" do
      expect {
        delete "/trades/#{event.id}/card_wants/#{want.id}"
      }.to change {
        AuditLog.where(action: "trade_card_want.destroy").count
      }.by(1)
    end
  end

  describe "admin invitation issue" do
    before do
      post signin_path, params: { email: admin_user.email, password: "password123" }
    end

    let(:valid_params) do
      {
        invitation: {}
      }
    end

    it "records audit log with action=invitation.issue" do
      expect {
        post admin_invitations_path, params: valid_params
      }.to change {
        AuditLog.where(action: "invitation.issue").count
      }.by(1)
    end
  end

  describe "recording failure does not break the operation" do
    before do
      post signin_path, params: { email: admin_user.email, password: "password123" }
    end

    let(:valid_params) do
      {
        event: {
          title: "New Event",
          description: "d",
          event_date: Date.today + 7.days
        }
      }
    end

    it "creates event even if AuditLog.record! raises" do
      allow(AuditLog).to receive(:record!).and_raise(StandardError, "boom")

      expect {
        post admin_events_path, params: valid_params
      }.to change(Event, :count).by(1)

      expect(response).to redirect_to(admin_events_path)
      expect(AuditLog).to have_received(:record!).at_least(:once)
    end
  end

  describe "implicit trade create" do
    before do
      post signin_path, params: { email: user.email, password: "password123" }
    end

    it "records audit log with action=trade.create when visiting trade for first time" do
      expect {
        get trade_path(event)
      }.to change {
        AuditLog.where(action: "trade.create", target_type: "Trade").count
      }.by(1)
    end

    it "does not record audit log on second visit to same trade" do
      get trade_path(event)

      expect {
        get trade_path(event)
      }.not_to change {
        AuditLog.where(action: "trade.create", target_type: "Trade").count
      }
    end

    it "records audit log even when authorize_user! redirects due to unauthorized access" do
      other_user = create(:user)
      post signin_path, params: { email: other_user.email, password: "password123" }

      # Mock find_or_create_by to return a trade owned by a different user
      allow(Trade).to receive(:find_or_create_by).and_return(create(:trade, event: event, user: user))

      expect {
        get trade_path(event)
      }.to change {
        AuditLog.count
      }.by(1)

      expect(response).to redirect_to(events_path)
    end

    it "shows trade page even if record_audit raises exception" do
      allow(AuditLog).to receive(:record!).and_raise(StandardError, "boom")

      expect {
        get trade_path(event)
      }.not_to raise_error

      expect(response).to be_successful
    end
  end
end
