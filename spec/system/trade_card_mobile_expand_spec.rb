require "rails_helper"

RSpec.describe "Trade Card Mobile Expand", type: :system do
  before do
    sign_in(user)
    resize_window_to(375, 800)
  end

  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:trade) { create(:trade, user: user, event: event, status: :pending) }
  let(:long_name) { "Asmoranomardicadaistinaculdacar, the Very Long Legendary Card Name Of Doom" }

  def page_has_no_horizontal_scroll?
    evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")
  end

  def wrapper_has_horizontal_scroll?(table_selector)
    evaluate_script(<<-JS
      (function() {
        var table = document.querySelector('#{table_selector}');
        if (!table) return false;
        var wrapper = table.parentElement;
        if (!wrapper) return false;
        return wrapper.scrollWidth > wrapper.clientWidth;
      })()
    JS
    )
  end

  describe "C1: Card name wrapping in expansion details" do
    it "general user page shows full card name wrapped in offers expansion" do
      offer = create(:trade_card_offer, trade: trade, card_name: long_name, quantity: 1)

      visit trade_path(event)

      # Find and click the expand button
      button = find("button[data-toggle-expand='trade_card_offer_#{offer.id}']")
      execute_script("arguments[0].click();", button.native)
      sleep 0.3

      # Check expansion is visible
      expect(page).to have_css("tr#expand_trade_card_offer_#{offer.id}", visible: true)

      # Check card name is fully displayed with wrapping
      card_name_elem = find("[data-testid='expand-card-name']")
      expect(card_name_elem.text).to eq(long_name)

      # Check wrapping (height > 1.5 line-height)
      height = evaluate_script("arguments[0].offsetHeight", card_name_elem.native)
      line_height = evaluate_script("window.getComputedStyle(arguments[0]).lineHeight", card_name_elem.native)
      line_height_px = line_height.to_f
      expect(height).to be > line_height_px * 1.5

      # Check text not truncated
      scroll_width = evaluate_script("arguments[0].scrollWidth", card_name_elem.native)
      client_width = evaluate_script("arguments[0].clientWidth", card_name_elem.native)
      expect(scroll_width).to be <= client_width
    end

    it "general user page shows full card name wrapped in wants expansion" do
      want = create(:trade_card_want, trade: trade, card_name: long_name, quantity: 1)

      visit trade_path(event)

      # Find and click the expand button
      button = find("button[data-toggle-expand='trade_card_want_#{want.id}']")
      execute_script("arguments[0].click();", button.native)
      sleep 0.3

      # Check expansion is visible
      expect(page).to have_css("tr#expand_trade_card_want_#{want.id}", visible: true)

      # Check card name is fully displayed
      card_name_elem = find("[data-testid='expand-card-name']")
      expect(card_name_elem.text).to eq(long_name)

      # Check wrapping
      height = evaluate_script("arguments[0].offsetHeight", card_name_elem.native)
      line_height = evaluate_script("window.getComputedStyle(arguments[0]).lineHeight", card_name_elem.native)
      line_height_px = line_height.to_f
      expect(height).to be > line_height_px * 1.5

      # Check text not truncated
      scroll_width = evaluate_script("arguments[0].scrollWidth", card_name_elem.native)
      client_width = evaluate_script("arguments[0].clientWidth", card_name_elem.native)
      expect(scroll_width).to be <= client_width
    end

    it "admin page shows full card name wrapped in offers expansion" do
      admin = create(:user, :admin)
      sign_in(admin)

      offer = create(:trade_card_offer, trade: trade, card_name: long_name, quantity: 1)

      visit admin_event_trade_path(event, trade)

      # Find and click the expand button
      button = find("button[data-toggle-expand='trade_card_offer_#{offer.id}']")
      execute_script("arguments[0].click();", button.native)
      sleep 0.3

      # Check expansion is visible
      expect(page).to have_css("tr#expand_trade_card_offer_#{offer.id}", visible: true)

      # Check card name is fully displayed
      card_name_elem = find("[data-testid='expand-card-name']")
      expect(card_name_elem.text).to eq(long_name)
    end
  end

  describe "C2: All fields displayed in expansion details" do
    it "offers with no data show all fields with dashes" do
      offer = create(:trade_card_offer, trade: trade, card_name: "Test Card", quantity: 1,
                                         expansion: nil, note: nil, amount: nil)

      visit trade_path(event)

      button = find("button[data-toggle-expand='trade_card_offer_#{offer.id}']")
      execute_script("arguments[0].click();", button.native)
      sleep 0.3

      expanded_row = find("tr#expand_trade_card_offer_#{offer.id}", visible: true)

      # Check all fields are present
      expect(expanded_row).to have_content("言語:")
      expect(expanded_row).to have_content("状態:")
      expect(expanded_row).to have_content("フォイル:")
      expect(expanded_row).to have_content("フレーム:")
      expect(expanded_row).to have_content("PWマーク:")
      expect(expanded_row).to have_content("セット:")
      expect(expanded_row).to have_content("備考:")
      expect(expanded_row).to have_content("単価:")
      expect(expanded_row).to have_content("小計:")

      # All null fields should show dashes
      dashes = expanded_row.all("p").map(&:text).count { |t| t.include?("—") }
      expect(dashes).to be >= 4  # At least セット、備考、単価、小計
    end

    it "wants without pw_mark field show all fields except pw_mark" do
      want = create(:trade_card_want, trade: trade, card_name: "Test Card", quantity: 1,
                                       expansion: nil, note: nil, amount: nil)

      visit trade_path(event)

      button = find("button[data-toggle-expand='trade_card_want_#{want.id}']")
      execute_script("arguments[0].click();", button.native)
      sleep 0.3

      expanded_row = find("tr#expand_trade_card_want_#{want.id}", visible: true)

      # Check all expected fields are present
      expect(expanded_row).to have_content("言語:")
      expect(expanded_row).to have_content("状態:")
      expect(expanded_row).to have_content("フォイル:")
      expect(expanded_row).to have_content("フレーム:")
      expect(expanded_row).to have_content("セット:")
      expect(expanded_row).to have_content("備考:")
      expect(expanded_row).to have_content("単価:")
      expect(expanded_row).to have_content("小計:")

      # Check PWマーク is NOT present
      expect(expanded_row).not_to have_content("PWマーク:")
    end

    it "offers with data show formatted values" do
      expansion = create(:expansion, scryfall_set_code: "dom")
      offer = create(:trade_card_offer, trade: trade, card_name: "Test Card", quantity: 2,
                                         expansion: expansion, amount: 500, note: "Test note")

      visit trade_path(event)

      button = find("button[data-toggle-expand='trade_card_offer_#{offer.id}']")
      execute_script("arguments[0].click();", button.native)
      sleep 0.3

      expanded_row = find("tr#expand_trade_card_offer_#{offer.id}", visible: true)

      # Check set code is uppercase
      expect(expanded_row).to have_content("セット:")
      expect(expanded_row).to have_content("DOM")

      # Check note is displayed
      expect(expanded_row).to have_content("備考:")
      expect(expanded_row).to have_content("Test note")

      # Check unit price is formatted
      expect(expanded_row).to have_content("単価:")
      expect(expanded_row).to have_content("¥500")

      # Check subtotal is formatted (500 * 2 = 1000)
      expect(expanded_row).to have_content("小計:")
      expect(expanded_row).to have_content("¥1,000")
    end
  end

  describe "C3: Toggle expansion by clicking expand button again" do
    it "closing expanded offers row when clicking expand button again" do
      offer = create(:trade_card_offer, trade: trade, card_name: "Test Card", quantity: 1)

      visit trade_path(event)

      button = find("button[data-toggle-expand='trade_card_offer_#{offer.id}']")

      # Open expansion
      execute_script("arguments[0].click();", button.native)
      sleep 0.3
      expect(page).to have_css("tr#expand_trade_card_offer_#{offer.id}", visible: true)
      expect(find("button[data-toggle-expand='trade_card_offer_#{offer.id}']")["aria-expanded"]).to eq("true")

      # Close expansion
      execute_script("arguments[0].click();", button.native)
      sleep 0.3
      expect(page).to have_css("tr#expand_trade_card_offer_#{offer.id}", visible: :hidden)
      expect(find("button[data-toggle-expand='trade_card_offer_#{offer.id}']")["aria-expanded"]).to eq("false")
    end
  end

  describe "C4: Only one expansion open at a time" do
    it "opening different row closes the previous expansion for offers" do
      offer1 = create(:trade_card_offer, trade: trade, card_name: "Card 1", quantity: 1)
      offer2 = create(:trade_card_offer, trade: trade, card_name: "Card 2", quantity: 1)

      visit trade_path(event)

      # Open first offer
      button1 = find("button[data-toggle-expand='trade_card_offer_#{offer1.id}']")
      execute_script("arguments[0].click();", button1.native)
      sleep 0.3
      expect(page).to have_css("tr#expand_trade_card_offer_#{offer1.id}", visible: true)

      # Open second offer
      button2 = find("button[data-toggle-expand='trade_card_offer_#{offer2.id}']")
      execute_script("arguments[0].click();", button2.native)
      sleep 0.3

      # First should be closed, second should be open
      expect(page).to have_css("tr#expand_trade_card_offer_#{offer1.id}", visible: :hidden)
      expect(page).to have_css("tr#expand_trade_card_offer_#{offer2.id}", visible: true)

      # Only one expand row should be visible in the table
      visible_expand_rows = all("tr[id^='expand_trade_card_offer_']", visible: true)
      expect(visible_expand_rows.count).to eq(1)
    end
  end

  describe "C5: No horizontal scroll when expansion is open" do
    it "general user offers with long card name and note" do
      long_card = "X" * 120
      long_note = "Y" * 120
      offer = create(:trade_card_offer, trade: trade, card_name: long_card, quantity: 1,
                                         note: long_note)

      visit trade_path(event)

      button = find("button[data-toggle-expand='trade_card_offer_#{offer.id}']")
      execute_script("arguments[0].click();", button.native)
      sleep 0.3

      expect(page_has_no_horizontal_scroll?).to be(true)
      expect(wrapper_has_horizontal_scroll?("#trade_card_offers")).to be(false)
    end

    it "general user wants with long card name and note" do
      long_card = "X" * 120
      long_note = "Y" * 120
      want = create(:trade_card_want, trade: trade, card_name: long_card, quantity: 1,
                                       note: long_note)

      visit trade_path(event)

      button = find("button[data-toggle-expand='trade_card_want_#{want.id}']")
      execute_script("arguments[0].click();", button.native)
      sleep 0.3

      expect(page_has_no_horizontal_scroll?).to be(true)
      expect(wrapper_has_horizontal_scroll?("#trade_card_wants")).to be(false)
    end

    it "admin page offers with long card name and note" do
      admin = create(:user, :admin)
      sign_in(admin)

      long_card = "X" * 120
      long_note = "Y" * 120
      offer = create(:trade_card_offer, trade: trade, card_name: long_card, quantity: 1,
                                         note: long_note)

      visit admin_event_trade_path(event, trade)

      button = find("button[data-toggle-expand='trade_card_offer_#{offer.id}']")
      execute_script("arguments[0].click();", button.native)
      sleep 0.3

      expect(page_has_no_horizontal_scroll?).to be(true)
      expect(wrapper_has_horizontal_scroll?("#trade_card_offers")).to be(false)
    end
  end
end
