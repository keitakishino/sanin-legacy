require "rails_helper"

RSpec.describe "Admin Proxy Orders", type: :request do
  describe "GET /admin/events/:event_id/proxy_order" do
    context "when not signed in" do
      it "redirects to signin path" do
        event = create(:event, event_type: :proxy_order)
        get admin_event_proxy_order_path(event)
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when signed in as a general user" do
      it "returns 403" do
        user = create(:user)
        event = create(:event, event_type: :proxy_order)
        post signin_path, params: { email: user.email, password: user.password }

        get admin_event_proxy_order_path(event)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when signed in as admin" do
      it "returns 200" do
        admin = create(:user, role: :admin)
        event = create(:event, event_type: :proxy_order, created_by: admin)
        post signin_path, params: { email: admin.email, password: admin.password }

        expect { get admin_event_proxy_order_path(event) }.to change(ProxyOrder, :count).by(1)
        expect(response).to have_http_status(:ok)
      end

      it "returns 404 for trade event" do
        admin = create(:user, role: :admin)
        event = create(:event, event_type: :trade, created_by: admin)
        post signin_path, params: { email: admin.email, password: admin.password }

        get admin_event_proxy_order_path(event)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /admin/events/:event_id/proxy_order/items" do
    context "when signed in as a general user" do
      it "returns 403" do
        user = create(:user)
        event = create(:event, event_type: :proxy_order)
        proxy_order = create(:proxy_order, event:)
        post signin_path, params: { email: user.email, password: user.password }

        post admin_event_proxy_order_items_path(event), params: { proxy_order_item: { card_name: "Test" } }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /admin/events/:event_id/proxy_order/items/:item_id/price_lines/:id" do
    context "when using item from different order" do
      it "returns 404" do
        admin = create(:user, role: :admin)
        event1 = create(:event, event_type: :proxy_order, created_by: admin)
        event2 = create(:event, event_type: :proxy_order, created_by: admin)
        proxy_order1 = create(:proxy_order, event: event1)
        proxy_order2 = create(:proxy_order, event: event2)
        item1 = create(:proxy_order_item, proxy_order: proxy_order1)
        item2 = create(:proxy_order_item, proxy_order: proxy_order2)
        line2 = create(:proxy_order_price_line, proxy_order_item: item2)

        post signin_path, params: { email: admin.email, password: admin.password }

        patch admin_event_proxy_order_item_price_line_path(event1, item1, line2), params: { proxy_order_price_line: { unit_price_usd: 2.00, quantity: 5 } }
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
