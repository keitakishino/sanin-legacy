require "rails_helper"
require "nokogiri"

RSpec.describe "ProxyOrders", type: :request do
  let(:user) { create(:user, email: "test@example.com", password: "password123") }
  let(:third_user) { create(:user, email: "third@example.com", password: "password789") }
  let(:other_buyer_user) { create(:user, username: "other_buyer", email: "other@example.com", password: "password456") }
  let(:event) { create(:event, :proxy_order, title: "Test Proxy Order") }
  let(:proxy_order) { create(:proxy_order, event:, status: :ordered, tax_usd: 10, usd_jpy_rate: nil) }
  let(:me) { create(:proxy_order_participant, proxy_order:, user:) }
  let(:other) { create(:proxy_order_participant, proxy_order:, user: other_buyer_user) }
  let(:item_a) { create(:proxy_order_item, proxy_order:, card_name: "Mine Card") }
  let(:item_b) { create(:proxy_order_item, proxy_order:, card_name: "Others Only Card") }

  before do
    # Ensure host is set correctly for request specs
    host! "www.example.com"

    # Setup data
    create(:proxy_order_price_line, proxy_order_item: item_a, quantity: 2, unit_price_usd: 5.00)
    create(:proxy_order_price_line, proxy_order_item: item_b, quantity: 3, unit_price_usd: 10.00)

    create(:proxy_order_allocation, proxy_order_item: item_a, proxy_order_participant: me, quantity: 2, lost_quantity: 0)
    create(:proxy_order_allocation, proxy_order_item: item_b, proxy_order_participant: other, quantity: 3, lost_quantity: 0)
  end

  describe "GET /proxy_orders/:event_id" do
    context "when user is not logged in" do
      it "redirects to signin page" do
        get proxy_order_path(event.id)
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is logged in" do
      before do
        post signin_path, params: { email: user.email, password: "password123" }
      end

      context "when user is a participant" do
        it "returns status 200" do
          get proxy_order_path(event.id)
          expect(response).to have_http_status(:ok)
        end

        it "displays Mine Card" do
          get proxy_order_path(event.id)
          expect(response.body).to include("Mine Card")
        end

        it "displays provisional status" do
          get proxy_order_path(event.id)
          expect(response.body).to include("暫定")
        end

        it "displays pending payment jpy as undecided" do
          get proxy_order_path(event.id)
          expect(response.body).to include("未確定")
        end

        it "does not display Others Only Card" do
          get proxy_order_path(event.id)
          expect(response.body).not_to include("Others Only Card")
        end

        it "does not display other_buyer username" do
          get proxy_order_path(event.id)
          expect(response.body).not_to include("other_buyer")
        end

        it "does not include form, input, button, select, textarea elements in main content" do
          get proxy_order_path(event.id)
          doc = Nokogiri::HTML.parse(response.body)
          main_content = doc.css("main").first || doc.css(".container").first
          forms = main_content.css("form, input, button, select, textarea") if main_content
          expect(forms.length).to eq(0)
        end
      end

      context "[C4] when proxy order is arrived with rate set" do
        before do
          proxy_order.update_columns(status: :arrived, usd_jpy_rate: 150)
        end

        it "does not display provisional status" do
          get proxy_order_path(event.id)
          expect(response.body).not_to include("暫定")
        end

        it "does not display undecided payment jpy" do
          get proxy_order_path(event.id)
          expect(response.body).not_to include("未確定")
        end

        it "displays payment in yen" do
          get proxy_order_path(event.id)
          # Should display yen amount when rate is set
          expect(response.body).to match(/¥/)
        end
      end

      context "when user is not a participant" do
        it "returns 404" do
          # Delete the user from participants so they're not a participant
          ProxyOrderParticipant.where(user_id: user.id).destroy_all
          get proxy_order_path(event.id)
          expect(response).to have_http_status(:not_found)
        end
      end

      context "when event is a trade event, not proxy order" do
        let(:trade_event) { create(:event) }

        it "returns 404" do
          get proxy_order_path(trade_event.id)
          expect(response).to have_http_status(:not_found)
        end
      end

      context "when event id does not exist" do
        it "returns 404" do
          get proxy_order_path(999999)
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "[C3] when accessing as a non-participant user" do
      before do
        post signin_path, params: { email: third_user.email, password: "password789" }
      end

      it "returns 404" do
        get proxy_order_path(event.id)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
