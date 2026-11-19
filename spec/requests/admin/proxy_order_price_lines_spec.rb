require "rails_helper"

RSpec.describe "Admin::ProxyOrderPriceLines focus_next", type: :request do
  include ActionView::RecordIdentifier

  describe "PATCH /admin/events/:event_id/proxy_orders/:proxy_order_id/items/:item_id/price_lines/:id" do
    let(:admin) { create(:user, role: :admin) }
    let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
    let(:proxy_order) { create(:proxy_order, event:) }
    let(:item) { create(:proxy_order_item, proxy_order:) }

    before do
      post signin_path, params: { email: admin.email, password: admin.password }
    end

    describe "[C1] 対象の明細が一覧から見つからなくても TypeError にならず、新規行の単価欄にフォーカスが移る" do
      it do
        line = create(:proxy_order_price_line, proxy_order_item: item, quantity: 1)

        allow_any_instance_of(ProxyOrderPriceLine).to receive(:update).and_wrap_original do |m, *args|
          result = m.call(*args)
          ProxyOrderPriceLine.where(id: m.receiver.id).delete_all
          result
        end

        patch admin_event_proxy_order_item_price_line_path(event, item, line),
              params: { proxy_order_price_line: { unit_price_usd: 2, quantity: 1 }, focus_next: "1" },
              headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("admin.proxy_order_price_lines.update.updated"))
        expect(response.body).to include("id=\"#{dom_id(item, :new_price_line_unit_price)}\" autofocus=")
      end
    end

    describe "[C2] 次の行がある場合はその行の単価欄にフォーカスが移る" do
      it do
        line1 = create(:proxy_order_price_line, proxy_order_item: item, quantity: 1)
        line2 = create(:proxy_order_price_line, proxy_order_item: item, quantity: 1)

        patch admin_event_proxy_order_item_price_line_path(event, item, line1),
              params: { proxy_order_price_line: { unit_price_usd: 2, quantity: 1 }, focus_next: "1" },
              headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("id=\"#{dom_id(line2, :unit_price)}\" autofocus=")
      end
    end
  end
end
