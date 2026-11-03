require "rails_helper"

RSpec.describe "Dashboard empty states", type: :system do
  let(:user) { create(:user, email: "test@example.com", password: "password123") }

  before do
    sign_in(user)
    resize_window_to(1280, 900)
  end

  context "when user has no trades and no proxy orders" do
    it "displays both empty states with matching styles" do
      visit root_path

      # Wait for the incomplete_trades frame to load
      expect(page).to have_text("トレードはまだありません", wait: 10)

      # Check that the proxy orders empty state is displayed
      within "#my_proxy_orders" do
        expect(page).to have_text("代理通販はまだありません")
        expect(page).to have_text("管理者があなたを参加者に追加すると、ここに表示されます。")
      end

      # Verify the old text is not displayed
      expect(page).not_to have_text("参加している代理通販はありません")
    end

    it "has no events link in incomplete_trades frame" do
      visit root_path

      # Wait for the incomplete_trades frame to load
      expect(page).to have_text("トレードはまだありません", wait: 10)

      # Verify no link to events in the frame
      within "#incomplete_trades" do
        expect(page).not_to have_link("イベント一覧を見る")
      end
    end

    it "has exactly one events link in main content" do
      visit root_path

      # Wait for the incomplete_trades frame to load
      expect(page).to have_text("トレードはまだありません", wait: 10)

      # Count events links in main
      events_links = page.all("main a[href='/events']")
      expect(events_links.count).to eq(1)
    end

    it "proxy_orders and trades empty states have matching background color and alignment" do
      visit root_path

      # Wait for the incomplete_trades frame to load
      expect(page).to have_text("トレードはまだありません", wait: 10)

      # Get computed styles for both empty state boxes
      incomplete_trades_box = page.find("#incomplete_trades .bg-stone-50")
      proxy_orders_box = page.find("#my_proxy_orders .bg-stone-50")

      trades_bg_color = page.evaluate_script(
        "window.getComputedStyle(document.querySelector('#incomplete_trades .bg-stone-50')).backgroundColor"
      )
      proxy_bg_color = page.evaluate_script(
        "window.getComputedStyle(document.querySelector('#my_proxy_orders .bg-stone-50')).backgroundColor"
      )

      trades_text_align = page.evaluate_script(
        "window.getComputedStyle(document.querySelector('#incomplete_trades .bg-stone-50')).textAlign"
      )
      proxy_text_align = page.evaluate_script(
        "window.getComputedStyle(document.querySelector('#my_proxy_orders .bg-stone-50')).textAlign"
      )

      # Both should have the same background color
      expect(trades_bg_color).to eq(proxy_bg_color)

      # Both should be center aligned
      expect(trades_text_align).to eq("center")
      expect(proxy_text_align).to eq("center")
    end
  end

  context "when user has incomplete trades" do
    let!(:event) { create(:event) }
    let!(:trade) { create(:trade, user:, event:, status: :pending) }

    it "has exactly one events link in main content" do
      visit root_path

      # Wait for the incomplete_trades frame to load with trade details
      expect(page).to have_text(event.title, wait: 10)

      # Count events links in main
      events_links = page.all("main a[href='/events']")
      expect(events_links.count).to eq(1)
    end
  end
end
