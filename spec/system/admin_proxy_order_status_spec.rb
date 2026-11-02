require "rails_helper"

RSpec.describe "Admin Proxy Order Status", type: :system do
  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }

  before do
    sign_in(admin)
    resize_window_to(1280, 900)
  end

  describe "C1: Status transition error display" do
    let(:proxy_order) { create(:proxy_order, event:, usd_jpy_rate: nil) }

    before { visit admin_event_proxy_order_path(event) }

    it "shows rate error when transitioning without rate" do
      click_button "到着へ"
      expect(page).to have_selector("#proxy_order_status_errors")
      expect(page).to have_content("ドル円レート")
      expect(page).to have_current_path(admin_event_proxy_order_path(event))
    end
  end

  describe "C2: Lost quantity input in arrived state" do
    let(:proxy_order) { create(:proxy_order, event:, status: :arrived) }
    let(:item) { create(:proxy_order_item, proxy_order:) }

    before do
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 5)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: create(:proxy_order_participant, proxy_order:), quantity: 5)
      proxy_order.update(tax_usd: 0, customs_usd: 0, shipping_usd: 0, usd_jpy_rate: 150)
      visit admin_event_proxy_order_path(event)
    end

    it "page loads in arrived state" do
      expect(page).to have_current_path(admin_event_proxy_order_path(event))
      expect(page).to have_content("到着")
    end
  end

  describe "C3: Hand-over check in arrived state" do
    let(:proxy_order) { create(:proxy_order, event:, status: :arrived, usd_jpy_rate: 150) }
    let(:item) { create(:proxy_order_item, proxy_order:) }

    before do
      user = create(:user, username: "test_user")
      participant = create(:proxy_order_participant, proxy_order:, user:)
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 1, unit_price_usd: 10)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)
      visit admin_event_proxy_order_path(event)
    end

    it "can check hand-over for participants" do
      expect(page).to have_content("test_user")

      # hand-over checkbox should be present in arrived state
      hand_over_checkbox = find('input[type="checkbox"][name*="handed_over_at"]')
      expect(hand_over_checkbox).not_to be_checked

      # check hand-over and update
      hand_over_checkbox.check
      click_button "更新"

      # verify handed_over_at is set
      expect(page).to have_content("参加者を更新しました")
      expect(page).to have_content("手渡し済み")
    end
  end

  describe "C4: Status transition error on completion" do
    let(:proxy_order) { create(:proxy_order, event:, status: :arrived) }
    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }

    before do
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 1, unit_price_usd: 10)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)
      visit admin_event_proxy_order_path(event)
    end

    it "shows error when hand-over not checked" do
      click_button "完了へ"
      expect(page).to have_selector("#proxy_order_status_errors")
      expect(page).to have_content("手渡し")
      expect(page).to have_current_path(admin_event_proxy_order_path(event))
    end
  end
end
