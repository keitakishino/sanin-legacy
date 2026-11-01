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
    let(:tanaka) { create(:user, username: "tanaka") }
    let(:yoshioka) { create(:user, username: "yoshioka") }

    before do
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 1, quantity: 1)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 2, quantity: 5)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 3, quantity: 1)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: create(:proxy_order_participant, proxy_order:, user: tanaka), quantity: 2)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: create(:proxy_order_participant, proxy_order:, user: yoshioka), quantity: 5)
      proxy_order.update(tax_usd: 0, customs_usd: 0, shipping_usd: 0, usd_jpy_rate: 150)
      visit admin_event_proxy_order_path(event)
    end

    it "updates lost quantities and recalculates unit price" do
      # Mark page to check for reload
      page.execute_script("window.__marker = 1")

      # Update price line $1 lost quantity to 1
      within first("div[id^='proxy_order_price_line_']") do
        fill_in "proxy_order_price_line[lost_quantity]", with: "1"
        click_button "更新"
      end

      expect(page).to have_content("価格行を更新しました")
      expect(page.evaluate_script("window.__marker")).to eq(1)

      # Update price line $2 lost quantity to 2
      within all("div[id^='proxy_order_price_line_']")[1] do
        fill_in "proxy_order_price_line[lost_quantity]", with: "2"
        click_button "更新"
      end

      # Check that unit price has been updated
      expect(page).to have_selector("[data-role='unit-price']", text: "$2.25")
    end
  end

  describe "C3: Hand-over check in arrived state" do
    let(:proxy_order) { create(:proxy_order, event:, status: :arrived) }
    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }

    before do
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 1)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)
      visit admin_event_proxy_order_path(event)
    end

    it "allows checking hand-over and shows toast" do
      within find("#proxy_order_participant_#{participant.id}") do
        check "handed_over_at"
        click_button "更新"
      end

      expect(page).to have_content("参加者を更新しました")
      expect(participant.reload.handed_over_at).to be_present
    end

    it "shows handed-over status in summary" do
      within find("#proxy_order_participant_#{participant.id}") do
        check "handed_over_at"
        click_button "更新"
      end

      within find("#proxy_order_participant_#{participant.id}_summary") do
        expect(page).to have_selector("[data-role='handed-over']", text: "手渡し済み")
      end
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
