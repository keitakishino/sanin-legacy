require "rails_helper"

RSpec.describe "Admin::ProxyOrderItems", type: :request do
  include ActionView::RecordIdentifier

  describe "PATCH /admin/events/:event_id/proxy_orders/items/:id" do
    let(:admin) { create(:user, role: :admin) }
    let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
    let(:proxy_order) { create(:proxy_order, event:) }

    before do
      post signin_path, params: { email: admin.email, password: admin.password }
    end

    describe "[C1] 既存のカード名を空にして保存するとエラー文が表示される" do
      it do
        item = create(:proxy_order_item, proxy_order:, card_name: "Lightning Bolt")

        patch admin_event_proxy_order_item_path(event, item),
              params: { proxy_order_item: { card_name: "" } },
              headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include(I18n.t("activerecord.errors.messages.blank"))
        expect(response.body).not_to include('<p class="text-sm font-semibold text-stone-800"></p>')
      end
    end
  end

  describe "POST /admin/events/:event_id/proxy_orders/items" do
    let(:admin) { create(:user, role: :admin) }
    let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
    let(:proxy_order) { create(:proxy_order, event:) }

    before do
      post signin_path, params: { email: admin.email, password: admin.password }
    end

    describe "[C2] 新規カード追加で重複すると、トーストにエラー文が表示される" do
      it do
        existing = create(:proxy_order_item, proxy_order:, card_name: "Lightning Bolt")

        post admin_event_proxy_order_items_path(event),
             params: {
               proxy_order_item: {
                 card_name: "Lightning Bolt",
                 expansion_id: existing.expansion_id,
                 foil: existing.foil,
                 frame: existing.frame
               }
             },
             headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include(I18n.t("activerecord.errors.messages.duplicate_card_entry"))
      end
    end
  end

  describe "[C3] 価格行の保存に失敗しても明細を再描画でき、エラー文が出る" do
    let(:admin) { create(:user, role: :admin) }
    let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
    let(:proxy_order) { create(:proxy_order, event:) }
    let(:item) { create(:proxy_order_item, proxy_order:) }

    before do
      post signin_path, params: { email: admin.email, password: admin.password }
    end

    it "新しい価格行の保存に失敗した場合" do
      post admin_event_proxy_order_item_price_lines_path(event, item),
           params: { proxy_order_price_line: { unit_price_usd: "1.00", quantity: 0 } },
           headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("target=\"#{dom_id(item)}\"")
    end

    it "既存の価格行の保存に失敗した場合" do
      line = create(:proxy_order_price_line, proxy_order_item: item, quantity: 1)

      patch admin_event_proxy_order_item_price_line_path(event, item, line),
            params: { proxy_order_price_line: { unit_price_usd: "1.00", quantity: 0 } },
            headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("target=\"#{dom_id(item)}\"")
    end
  end
end
