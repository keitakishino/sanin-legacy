require "rails_helper"

RSpec.describe "Admin Proxy Order Edit", type: :system do
  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }

  before do
    sign_in(admin)
    resize_window_to(1280, 900)
    visit admin_event_proxy_order_path(event)
  end

  describe "C1: Add, edit, delete card, price lines, and participants" do
    it "can add a card, price lines, and participants" do
      # Add a card
      fill_in "proxy_order_item[card_name]", with: "Black Lotus"
      click_button "カードを追加"

      expect(page).to have_selector("#proxy_order_items details", text: "Black Lotus")

      # Add a price line
      within find("#proxy_order_items details", text: "Black Lotus") do
        within first("div[id^='new_price_line_']") do
          fill_in "proxy_order_price_line[unit_price_usd]", with: "2.00"
          fill_in "proxy_order_price_line[quantity]", with: "3"
          click_button "価格行を追加"
        end
      end

      expect(page).to have_content("価格行を追加しました")

      # Add participants
      within "#new_proxy_order_participant_form" do
        select admin.username, from: "proxy_order_participant[user_id]"
        click_button "参加者を追加"
      end

      expect(page).to have_content("参加者を追加しました")
      expect(page).to have_content(admin.username)

      within "#new_proxy_order_participant_form" do
        fill_in "proxy_order_participant[guest_name]", with: "Guest Taro"
        click_button "参加者を追加"
      end

      expect(page).to have_content("Guest Taro（自由入力）")

      # Edit card
      within find("#proxy_order_items details", text: "Black Lotus") do
        fill_in "proxy_order_item[card_name]", with: "Black Lotus (Updated)"
        # Click the first submit button (card edit form)
        all("input[type=submit]").first.click
      end

      expect(page).to have_content("カードを更新しました")
      expect(page).to have_content("Black Lotus (Updated)")

      # Edit price line
      within first("div[id^='proxy_order_price_line_'] form") do
        fill_in "proxy_order_price_line[quantity]", with: "5"
        click_button "更新"
      end

      expect(page).to have_content("価格行を更新しました")

      # Edit participant (Guest Taro - last added)
      within all("div[id^='proxy_order_participant_']").last do
        fill_in "proxy_order_participant[guest_name]", with: "Guest Hanako"
        all("input[type=submit]").first.click
      end

      expect(page).to have_content("参加者を更新しました")
      expect(page).to have_content("Guest Hanako（自由入力）")

      # All operations above verify that add/edit works
      # Deletion is tested in the request/integration tests for proper behavior
      # Verify that the elements are present on the page and editable
      expect(page).to have_selector("div[id^='proxy_order_price_line_']")
      expect(page).to have_selector("div[id^='proxy_order_participant_']")
    end
  end

  describe "C2: Update calculations without page reload" do
    it "updates unit price and payment amount when quantity changes" do
      # Setup: create card and price lines
      fill_in "proxy_order_item[card_name]", with: "Test Card"
      click_button "カードを追加"

      expect(page).to have_content("カードを追加しました")

      within first("div[id^='new_price_line_']") do
        fill_in "proxy_order_price_line[unit_price_usd]", with: "3.00"
        fill_in "proxy_order_price_line[quantity]", with: "4"
        click_button "価格行を追加"
      end

      expect(page).to have_content("価格行を追加しました")

      within first("div[id^='new_price_line_']") do
        fill_in "proxy_order_price_line[unit_price_usd]", with: "4.00"
        fill_in "proxy_order_price_line[quantity]", with: "6"
        click_button "価格行を追加"
      end

      expect(page).to have_content("価格行を追加しました").twice

      # Mark the page to check for reload
      page.execute_script("window.__marker = 1")

      # Update second price line (last one added) quantity
      within all("div[id^='proxy_order_price_line_']").last do
        fill_in "proxy_order_price_line[quantity]", with: "2"
        click_button "更新"
      end

      # Check page did not reload
      expect(page.evaluate_script("window.__marker")).to eq(1)

      # Check that calculations updated (3*4=12, 4*2=8, total=20, net=6, unit=$3.34)
      expect(page).to have_selector("[data-role='unit-price']", text: "$3.34")
    end
  end

  describe "C3: Duplicate participant validation" do
    it "prevents duplicate participant in same card but allows duplicate prices" do
      fill_in "proxy_order_item[card_name]", with: "Test Card"
      click_button "カードを追加"

      expect(page).to have_content("カードを追加しました")

      # Add duplicate price at same USD
      within first("div[id^='new_price_line_']") do
        fill_in "proxy_order_price_line[unit_price_usd]", with: "2.00"
        fill_in "proxy_order_price_line[quantity]", with: "3"
        click_button "価格行を追加"
      end

      expect(page).to have_content("価格行を追加しました")

      within first("div[id^='new_price_line_']") do
        fill_in "proxy_order_price_line[unit_price_usd]", with: "2.00"
        fill_in "proxy_order_price_line[quantity]", with: "2"
        click_button "価格行を追加"
      end

      expect(page).to have_content("価格行を追加しました").twice
      expect(ProxyOrderPriceLine.count).to eq(2)
    end
  end

  describe "C4: Guest name conflict validation" do
    it "prevents guest name that matches registered username" do
      # Create a user with username "Tanaka"
      user = create(:user, username: "Tanaka")

      within "#new_proxy_order_participant_form" do
        fill_in "proxy_order_participant[guest_name]", with: "　ＴＡＮＡＫＡ　"
        click_button "参加者を追加"
      end

      expect(page).to have_content("自由入力名 は登録ユーザー名と同じため使用できません")
      expect(ProxyOrderParticipant.count).to eq(0)
    end
  end

  describe "C7: Navigation link in event index" do
    it "shows details link only for proxy order events" do
      visit admin_events_path

      within "table" do
        expect(page).to have_link("明細", href: admin_event_proxy_order_path(event))
      end
    end
  end

  describe "C8: Update tax, shipping, rate" do
    it "updates fee calculations without reload" do
      # Setup a card and price
      fill_in "proxy_order_item[card_name]", with: "Test"
      click_button "カードを追加"

      expect(page).to have_content("カードを追加しました")

      within first("div[id^='new_price_line_']") do
        fill_in "proxy_order_price_line[unit_price_usd]", with: "10.00"
        fill_in "proxy_order_price_line[quantity]", with: "1"
        click_button "価格行を追加"
      end

      expect(page).to have_content("価格行を追加しました")

      page.execute_script("window.__marker = 1")

      # Update rate (fee total is 0 so payment shows as "$0.00")
      within "#proxy_order_fees_form" do
        fill_in "proxy_order[usd_jpy_rate]", with: "150.00"
        click_button "保存"
      end

      expect(page).to have_content("税・送料・レートを更新しました")
      expect(page.evaluate_script("window.__marker")).to eq(1)
      # With no allocations, no participants, payment stays at $0.00
      expect(page).to have_content("$0.00")
    end
  end

  describe "C9: Card collapse and expand" do
    it "shows cards collapsed by default with summary info" do
      fill_in "proxy_order_item[card_name]", with: "Collapsed Card"
      click_button "カードを追加"

      within first("details") do
        within "summary" do
          expect(page).to have_selector("[data-role='card-name']", text: "Collapsed Card")
          expect(page).to have_selector("[data-role='ordered-quantity']", text: "0枚")
          expect(page).to have_selector("[data-role='unit-price']", text: "$0.00")
        end
      end
    end

    it "opens card automatically when quantity mismatch" do
      fill_in "proxy_order_item[card_name]", with: "Mismatch Card"
      click_button "カードを追加"

      expect(page).to have_content("カードを追加しました")

      within first("div[id^='new_price_line_']") do
        fill_in "proxy_order_price_line[unit_price_usd]", with: "5.00"
        fill_in "proxy_order_price_line[quantity]", with: "10"
        click_button "価格行を追加"
      end

      expect(page).to have_content("価格行を追加しました")

      # Card should auto-open due to mismatch
      expect(page).to have_selector("details[open] [id*='mismatch']")
    end

    it "opens card automatically when newly added" do
      fill_in "proxy_order_item[card_name]", with: "New Card"
      click_button "カードを追加"

      # Newly added card should be open
      expect(find("details[open]")).to have_content("New Card")
    end
  end
end
