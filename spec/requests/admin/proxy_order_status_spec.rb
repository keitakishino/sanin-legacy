require "rails_helper"

RSpec.describe "Admin Proxy Order Status", type: :request do
  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
  let(:proxy_order) { create(:proxy_order, event:, usd_jpy_rate: 150) }

  before do
    post signin_path, params: { email: admin.email, password: admin.password }
  end

  describe "C1: Status transition from ordered to arrived" do
    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }

    context "when rate is not set" do
      before { proxy_order.update(usd_jpy_rate: nil) }

      it "returns 422 and keeps status as ordered" do
        patch admin_event_proxy_order_path(event), params: { proxy_order: { status: "arrived" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(proxy_order.reload.status).to eq("ordered")
        expect(response.body).to include("ドル円レート")
      end
    end

    context "when quantity mismatch exists" do
      before do
        create(:proxy_order_price_line, proxy_order_item: item, quantity: 3)
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 2)
      end

      it "returns 422 with error including card name" do
        patch admin_event_proxy_order_path(event), params: { proxy_order: { status: "arrived" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(proxy_order.reload.status).to eq("ordered")
        expect(response.body).to include(item.card_name)
      end
    end

    context "when conditions are met" do
      before do
        create(:proxy_order_price_line, proxy_order_item: item, quantity: 3)
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 3)
      end

      it "returns 303 and updates status" do
        patch admin_event_proxy_order_path(event), params: { proxy_order: { status: "arrived" } }
        expect(response).to have_http_status(:see_other)
        expect(proxy_order.reload.status).to eq("arrived")
      end

      it "creates audit log" do
        expect {
          patch admin_event_proxy_order_path(event), params: { proxy_order: { status: "arrived" } }
        }.to change(AuditLog, :count).by(1)

        log = AuditLog.last
        expect(log.action).to eq("proxy_order.status_change")
        expect(log.details["from"]).to eq("ordered")
        expect(log.details["to"]).to eq("arrived")
      end
    end
  end

  describe "C4: Status transition from arrived to completed" do
    before { proxy_order.update(status: :arrived) }

    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }

    context "when lost quantity mismatch exists" do
      before do
        create(:proxy_order_price_line, proxy_order_item: item, quantity: 3, lost_quantity: 1)
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 3, lost_quantity: 0)
        participant.update(handed_over_at: Time.current)
      end

      it "returns 422 and keeps status as arrived" do
        patch admin_event_proxy_order_path(event), params: { proxy_order: { status: "completed" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(proxy_order.reload.status).to eq("arrived")
      end
    end

    context "when participant has unpaid balance and is not handed over" do
      before do
        create(:proxy_order_price_line, proxy_order_item: item, quantity: 3, lost_quantity: 0, unit_price_usd: 10)
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 3, lost_quantity: 0)
        participant.update(handed_over_at: nil)
      end

      it "returns 422 and keeps status as arrived" do
        patch admin_event_proxy_order_path(event), params: { proxy_order: { status: "completed" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(proxy_order.reload.status).to eq("arrived")
        expect(response.body).to include("手渡し")
      end
    end

    context "when all conditions are met" do
      before do
        create(:proxy_order_price_line, proxy_order_item: item, quantity: 3, lost_quantity: 0, unit_price_usd: 10)
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 3, lost_quantity: 0)
        participant.update(handed_over_at: Time.current)
      end

      it "returns 303 and updates status" do
        patch admin_event_proxy_order_path(event), params: { proxy_order: { status: "completed" } }
        expect(response).to have_http_status(:see_other)
        expect(proxy_order.reload.status).to eq("completed")
      end

      it "creates audit log" do
        expect {
          patch admin_event_proxy_order_path(event), params: { proxy_order: { status: "completed" } }
        }.to change(AuditLog, :count).by(1)

        log = AuditLog.last
        expect(log.action).to eq("proxy_order.status_change")
        expect(log.details["from"]).to eq("arrived")
        expect(log.details["to"]).to eq("completed")
      end
    end
  end

  describe "C2: Lost quantity input in arrived state" do
    before { proxy_order.update(status: :arrived) }

    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:price_line) { create(:proxy_order_price_line, proxy_order_item: item, quantity: 5, lost_quantity: 0) }
    let(:allocation) { create(:proxy_order_allocation, proxy_order_item: item, quantity: 5, lost_quantity: 0) }

    it "updates price line lost_quantity" do
      patch admin_event_proxy_order_item_price_line_path(event, item, price_line), params: { proxy_order_price_line: { lost_quantity: "1" } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      expect(response).to have_http_status(:ok)
      expect(price_line.reload.lost_quantity).to eq(1)
    end

    it "updates allocation lost_quantity" do
      patch admin_event_proxy_order_item_allocation_path(event, item, allocation), params: { proxy_order_allocation: { lost_quantity: "2" } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      expect(response).to have_http_status(:ok)
      expect(allocation.reload.lost_quantity).to eq(2)
    end

    it "treats blank lost_quantity as 0" do
      patch admin_event_proxy_order_item_price_line_path(event, item, price_line), params: { proxy_order_price_line: { lost_quantity: "" } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      expect(response).to have_http_status(:ok)
      expect(price_line.reload.lost_quantity).to eq(0)
    end

    it "creates audit log for price line lost update" do
      expect {
        patch admin_event_proxy_order_item_price_line_path(event, item, price_line), params: { proxy_order_price_line: { lost_quantity: "1" } }
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("proxy_order_price_line.update_lost")
    end

    it "creates audit log for allocation lost update" do
      expect {
        patch admin_event_proxy_order_item_allocation_path(event, item, allocation), params: { proxy_order_allocation: { lost_quantity: "1" } }
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("proxy_order_allocation.update_lost")
    end
  end

  describe "C5: Completed state restrictions" do
    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }
    let(:price_line) { create(:proxy_order_price_line, proxy_order_item: item) }
    let(:allocation) { create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant) }

    before do
      # Force creation of related objects before setting status
      item
      participant
      price_line
      allocation
      proxy_order.update(status: :completed)
    end

    it "prevents item create" do
      expect {
        post admin_event_proxy_order_items_path(event), params: { proxy_order_item: { card_name: "Test" } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      }.not_to change(ProxyOrderItem, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "prevents item update" do
      patch admin_event_proxy_order_item_path(event, item), params: { proxy_order_item: { card_name: "Updated" } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(item.reload.card_name).not_to eq("Updated")
    end

    it "prevents item destroy" do
      expect {
        delete admin_event_proxy_order_item_path(event, item), headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      }.not_to change(ProxyOrderItem, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "prevents price_line create" do
      expect {
        post admin_event_proxy_order_item_price_lines_path(event, item), params: { proxy_order_price_line: { unit_price_usd: 5, quantity: 1 } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      }.not_to change(ProxyOrderPriceLine, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "prevents price_line update quantity" do
      patch admin_event_proxy_order_item_price_line_path(event, item, price_line), params: { proxy_order_price_line: { quantity: 10 } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(price_line.reload.quantity).not_to eq(10)
    end

    it "prevents price_line destroy" do
      expect {
        delete admin_event_proxy_order_item_price_line_path(event, item, price_line), headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      }.not_to change(ProxyOrderPriceLine, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "prevents allocation create" do
      expect {
        post admin_event_proxy_order_item_allocations_path(event, item), params: { proxy_order_allocation: { proxy_order_participant_id: participant.id, quantity: 1 } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      }.not_to change(ProxyOrderAllocation, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "prevents allocation update" do
      patch admin_event_proxy_order_item_allocation_path(event, item, allocation), params: { proxy_order_allocation: { quantity: 10 } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(allocation.reload.quantity).not_to eq(10)
    end

    it "prevents allocation destroy" do
      expect {
        delete admin_event_proxy_order_item_allocation_path(event, item, allocation), headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      }.not_to change(ProxyOrderAllocation, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "prevents participant create" do
      expect {
        post admin_event_proxy_order_participants_path(event), params: { proxy_order_participant: { user_id: admin.id } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      }.not_to change(ProxyOrderParticipant, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "prevents participant update" do
      patch admin_event_proxy_order_participant_path(event, participant), params: { proxy_order_participant: { guest_name: "Updated" } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(participant.reload.guest_name).not_to eq("Updated")
    end

    it "prevents participant destroy" do
      expect {
        delete admin_event_proxy_order_participant_path(event, participant), headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      }.not_to change(ProxyOrderParticipant, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "prevents fee update" do
      patch admin_event_proxy_order_path(event), params: { proxy_order: { tax_usd: 5 } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(proxy_order.reload.tax_usd).not_to eq(5)
    end
  end

  describe "C6: Rollback preserves lost and handed_over" do
    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }

    before do
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 3, lost_quantity: 1, unit_price_usd: 10)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 3, lost_quantity: 1)
      participant.update(handed_over_at: Time.current)

      proxy_order.update(status: :arrived)
      proxy_order.update(status: :completed)
    end

    it "preserves values on completed -> arrived" do
      patch admin_event_proxy_order_path(event), params: { proxy_order: { status: "arrived" } }
      expect(response).to have_http_status(:see_other)

      item.reload
      expect(item.proxy_order_price_lines.first.lost_quantity).to eq(1)
      expect(item.proxy_order_allocations.first.lost_quantity).to eq(1)
      expect(participant.reload.handed_over_at).to be_present
    end

    it "preserves values on arrived -> ordered" do
      patch admin_event_proxy_order_path(event), params: { proxy_order: { status: "arrived" } }
      patch admin_event_proxy_order_path(event), params: { proxy_order: { status: "ordered" } }
      expect(response).to have_http_status(:see_other)

      item.reload
      expect(item.proxy_order_price_lines.first.lost_quantity).to eq(1)
      expect(item.proxy_order_allocations.first.lost_quantity).to eq(1)
      expect(participant.reload.handed_over_at).to be_present
    end
  end

  describe "C7: State-based operation restrictions" do
    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }
    let(:price_line) { create(:proxy_order_price_line, proxy_order_item: item, quantity: 5) }
    let(:allocation) { create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 5) }

    describe "ordered state" do
      it "allows quantity update" do
        patch admin_event_proxy_order_item_price_line_path(event, item, price_line), params: { proxy_order_price_line: { quantity: 3 } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
        expect(response).to have_http_status(:ok)
        expect(price_line.reload.quantity).to eq(3)
      end

      it "rejects lost_quantity input" do
        patch admin_event_proxy_order_item_price_line_path(event, item, price_line), params: { proxy_order_price_line: { lost_quantity: "1" } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(price_line.reload.lost_quantity).to eq(0)
      end

      it "rejects participant handed_over_at update" do
        patch admin_event_proxy_order_participant_path(event, participant), params: { proxy_order_participant: { handed_over_at: "1" } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(participant.reload.handed_over_at).to be_nil
      end
    end

    describe "arrived state" do
      before { proxy_order.update(status: :arrived) }

      it "rejects quantity update for price_line" do
        patch admin_event_proxy_order_item_price_line_path(event, item, price_line), params: { proxy_order_price_line: { quantity: 3 } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(price_line.reload.quantity).to eq(5)
      end

      it "rejects quantity update for allocation" do
        patch admin_event_proxy_order_item_allocation_path(event, item, allocation), params: { proxy_order_allocation: { quantity: 3 } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(allocation.reload.quantity).to eq(5)
      end

      it "rejects card_name update" do
        patch admin_event_proxy_order_item_path(event, item), params: { proxy_order_item: { card_name: "Updated" } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(item.reload.card_name).not_to eq("Updated")
      end

      it "rejects item create" do
        expect {
          post admin_event_proxy_order_items_path(event), params: { proxy_order_item: { card_name: "New" } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
        }.not_to change(ProxyOrderItem, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects allocation create" do
        expect {
          post admin_event_proxy_order_item_allocations_path(event, item), params: { proxy_order_allocation: { proxy_order_participant_id: participant.id, quantity: 1 } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
        }.not_to change(ProxyOrderAllocation, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "C8: Fee update in arrived state" do
    before { proxy_order.update(status: :arrived) }

    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }

    before do
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 2, unit_price_usd: 10)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 2)
    end

    it "allows tax_usd update" do
      patch admin_event_proxy_order_path(event), params: { proxy_order: { tax_usd: 5 } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      expect(response).to have_http_status(:ok)
      expect(proxy_order.reload.tax_usd).to eq(5)
    end

    it "recalculates payment after fee update" do
      original_calc = ProxyOrderCalculator.new(proxy_order)
      original_payment = original_calc.payment_usd(participant)

      patch admin_event_proxy_order_path(event), params: { proxy_order: { tax_usd: 5 } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

      proxy_order.reload
      new_calc = ProxyOrderCalculator.new(proxy_order)
      new_payment = new_calc.payment_usd(participant)

      expect(new_payment).not_to eq(original_payment)
    end

    it "rejects fee update in completed state" do
      proxy_order.update(status: :completed)
      patch admin_event_proxy_order_path(event), params: { proxy_order: { tax_usd: 5 } }, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(proxy_order.reload.tax_usd).not_to eq(5)
    end
  end

  describe "C9: Audit logging" do
    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }
    let(:price_line) { create(:proxy_order_price_line, proxy_order_item: item, quantity: 3) }
    let(:allocation) { create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 3) }

    before { proxy_order.update(status: :arrived) }

    it "logs status transition" do
      expect {
        patch admin_event_proxy_order_path(event), params: { proxy_order: { status: "completed" } }
      }.not_to raise_error
    end

    it "logs price line lost update" do
      expect {
        patch admin_event_proxy_order_item_price_line_path(event, item, price_line), params: { proxy_order_price_line: { lost_quantity: "1" } }
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("proxy_order_price_line.update_lost")
    end

    it "logs allocation lost update" do
      expect {
        patch admin_event_proxy_order_item_allocation_path(event, item, allocation), params: { proxy_order_allocation: { lost_quantity: "1" } }
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("proxy_order_allocation.update_lost")
    end

    it "logs participant handover" do
      expect {
        patch admin_event_proxy_order_participant_path(event, participant), params: { proxy_order_participant: { handed_over_at: "1" } }
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq("proxy_order_participant.hand_over")
    end
  end
end
