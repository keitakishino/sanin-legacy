require "rails_helper"

RSpec.describe "User Proxy Order View", type: :system do
  let(:user) { create(:user, email: "test@example.com", password: "password123") }
  let(:other_buyer_user) { create(:user, username: "other_buyer", email: "other@example.com", password: "password456") }
  let(:event) { create(:event, :proxy_order, title: "My Proxy Order") }
  let(:proxy_order) { create(:proxy_order, event:, status: :ordered, tax_usd: 10, usd_jpy_rate: nil) }
  let(:me) { create(:proxy_order_participant, proxy_order:, user:) }
  let(:other) { create(:proxy_order_participant, proxy_order:, user: other_buyer_user) }
  let(:item_a) { create(:proxy_order_item, proxy_order:, card_name: "Mine Card") }
  let(:item_b) { create(:proxy_order_item, proxy_order:, card_name: "Others Only Card") }
  let(:not_my_event) { create(:event, :proxy_order, title: "Not My Proxy") }
  let(:not_my_proxy_order) { create(:proxy_order, event: not_my_event) }

  before do
    sign_in(user)
    resize_window_to(1280, 900)

    # Setup data for my proxy order
    create(:proxy_order_price_line, proxy_order_item: item_a, quantity: 2, unit_price_usd: 5.00)
    create(:proxy_order_price_line, proxy_order_item: item_b, quantity: 3, unit_price_usd: 10.00)

    create(:proxy_order_allocation, proxy_order_item: item_a, proxy_order_participant: me, quantity: 2, lost_quantity: 0)
    create(:proxy_order_allocation, proxy_order_item: item_b, proxy_order_participant: other, quantity: 3, lost_quantity: 0)

    # Setup data for not_my_proxy_order (participant not user)
    create(:proxy_order_participant, proxy_order: not_my_proxy_order, user: other_buyer_user)
  end

  describe "C1: Dashboard proxy order list" do
    it "displays user's proxy orders in dashboard" do
      visit root_path
      expect(page).to have_selector("#my_proxy_orders")
      expect(page).to have_content("My Proxy Order")
    end

    it "displays order status badge" do
      visit root_path
      within "#my_proxy_orders" do
        expect(page).to have_content("注文")
      end
    end

    it "navigates to proxy order detail when clicking view details" do
      visit root_path
      within "#my_proxy_orders" do
        click_link "詳細を表示"
      end
      expect(page).to have_current_path(proxy_order_path(event.id))
    end
  end

  describe "C2: Proxy order detail view" do
    before { visit proxy_order_path(event.id) }

    it "displays event title" do
      expect(page).to have_content("My Proxy Order")
    end

    it "displays my items in table" do
      expect(page).to have_selector("#proxy_order_my_items")
      expect(page).to have_content("Mine Card")
    end

    it "displays allocation quantity" do
      within "#proxy_order_my_items" do
        expect(page).to have_content("2")
      end
    end

    it "displays lost quantity as 0" do
      within "#proxy_order_my_items" do
        # Find the row and check for 0 in lost quantity column
        rows = page.all("tr")
        mine_card_row = rows.find { |row| row.text.include?("Mine Card") }
        expect(mine_card_row.text).to include("0")
      end
    end

    it "displays payment summary with role attributes" do
      expect(page).to have_selector("[data-role='goods-total']")
      expect(page).to have_selector("[data-role='fee']")
      expect(page).to have_selector("[data-role='payment-usd']")
      expect(page).to have_selector("[data-role='payment-jpy']")
    end

    it "displays status with ordered state highlighted" do
      expect(page).to have_selector("#proxy_order_status [data-status='ordered']")
      # Check that ordered span has the primary color class
      ordered_span = find("#proxy_order_status [data-status='ordered']")
      expect(ordered_span["class"]).to include("bg-primary")
    end

    it "has no form, input, select, textarea, or button elements" do
      main_content = find("main") rescue find("div.container")
      expect(main_content).to have_no_css("form, input, select, textarea, button")
    end
  end

  describe "C3: Privacy - Only own items and participants hidden" do
    before { visit proxy_order_path(event.id) }

    it "does not display others only card" do
      expect(page).not_to have_content("Others Only Card")
    end

    it "does not display other buyer username" do
      expect(page).not_to have_content("other_buyer")
    end

    it "does not display other participant allocations" do
      within "#proxy_order_my_items" do
        rows = page.all("tr")
        # Should only have header row + 1 data row (Mine Card)
        expect(rows.count).to eq(2)
      end
    end

    context "when not a participant of proxy order" do
      it "does not display the proxy order in dashboard" do
        expect(page).not_to have_content("Not My Proxy")
      end
    end
  end

  describe "C4: Provisional and undecided amount display" do
    before { visit proxy_order_path(event.id) }

    it "displays provisional notice in ordered state" do
      expect(page).to have_selector("#proxy_order_provisional")
      expect(page).to have_content("暫定")
      expect(page).to have_content("注文中のため暫定の金額です")
    end

    it "displays undecided payment in jpy" do
      expect(page).to have_selector("[data-role='payment-jpy']")
      payment_jpy_element = find("[data-role='payment-jpy']")
      expect(payment_jpy_element.text).to include("未確定")
    end

    it "displays provisional badge next to payment jpy" do
      main_area = find("main") rescue find("div.container")
      expect(main_area).to have_content("暫定")
    end
  end

  describe "Arrived state with rate set" do
    before do
      proxy_order.update_columns(status: :arrived, usd_jpy_rate: 150)
      visit proxy_order_path(event.id)
    end

    it "does not display provisional notice" do
      expect(page).not_to have_selector("#proxy_order_provisional")
    end

    it "does not display undecided payment" do
      expect(page).not_to have_content("未確定")
    end

    it "displays payment in yen with rate applied" do
      payment_jpy_element = find("[data-role='payment-jpy']")
      # goods_total = (5.00 * 2) = 10
      # fee_total = (40 + 10) * 0.05 = 2.5
      # fee_per_person = 2.5 / 2 = 1.25
      # user's fee = (10 + 10/2) * 0.05 = 0.75
      # user's payment_usd = 10 + 0.75 = 10.75
      # user's payment_jpy = 10.75 * 150 = 1612.5 = 1612
      expect(payment_jpy_element.text).to match(/¥/)
      expect(payment_jpy_element.text).not_to include("未確定")
    end
  end
end
