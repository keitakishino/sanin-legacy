require "rails_helper"

# 「イベントは生きているのに通販だけ論理削除」という不整合でも管理画面が 500 にならないこと。
# 以前はこの状態になると、default_scope で @event.proxy_order が nil になり、
# 作り直そうとして event_id の一意制約に当たり、rescue しても nil のままで
# load_editor_state の @proxy_order.reload が NoMethodError になっていた（自己修復しない）。
RSpec.describe "Admin Proxy Order with a discarded proxy order", type: :request do
  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, :proxy_order) }
  let!(:proxy_order) { create(:proxy_order, event:) }
  let!(:item) { create(:proxy_order_item, proxy_order:, card_name: "Ponder") }

  before do
    post signin_path, params: { email: admin.email, password: admin.password }
  end

  context "when the event is alive but its proxy order is discarded" do
    before do
      proxy_order.discard!
      event.update!(discarded_at: nil) # 旧 Event#restore! と同じ、浅い復元で作られる状態
    end

    it "returns 200 instead of 500" do
      get admin_event_proxy_order_path(event)
      expect(response).to have_http_status(:ok)
    end

    it "restores the proxy order and its items" do
      get admin_event_proxy_order_path(event)

      expect(ProxyOrder.find_by(id: proxy_order.id)).to be_present
      expect(ProxyOrderItem.find_by(id: item.id)).to be_present
      expect(response.body).to include("Ponder")
    end

    it "does not create a second proxy order" do
      expect { get admin_event_proxy_order_path(event) }
        .not_to change { ProxyOrder.with_discarded.where(event_id: event.id).count }
    end

    it "records the repair in the audit log" do
      expect { get admin_event_proxy_order_path(event) }
        .to change { AuditLog.where(action: "proxy_order.restore").count }.by(1)
    end
  end

  context "when the proxy order is healthy" do
    it "still returns 200 and records no repair" do
      expect { get admin_event_proxy_order_path(event) }
        .not_to change { AuditLog.where(action: "proxy_order.restore").count }
      expect(response).to have_http_status(:ok)
    end
  end
end
