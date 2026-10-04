require "rails_helper"

RSpec.describe "Trade Card Mobile Layout", type: :system do
  before do
    sign_in(user)
    resize_window_to(375, 800)
  end

  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:trade) { create(:trade, user: user, event: event, status: :pending) }
  let(:long_card_name) { "Asmoranomardicadaistinaculdacar, the Very Long Legendary Card Name Of Doom" }

  def has_no_horizontal_scroll?(selector)
    evaluate_script("(function() { var e = document.querySelector('#{selector}'); return e ? e.scrollWidth <= e.clientWidth : true; })()")
  end

  def page_has_no_horizontal_scroll?
    evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")
  end

  def wrapper_has_horizontal_scroll?(table_selector)
    # The table is wrapped in a .overflow-x-auto div, so we need to check if the wrapper can scroll
    # This should return true for main (table exceeds wrapper), false for the fix branch
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

  describe "C1: No horizontal scroll with long card name" do
    it "general user page has no horizontal scroll at 375px" do
      # Create trade card offers with long names
      create(:trade_card_offer, trade: trade, card_name: long_card_name, quantity: 1)
      expansion = create(:expansion)
      create(:trade_card_offer, trade: trade, card_name: "Test", expansion: expansion)

      visit trade_path(event)

      expect(page_has_no_horizontal_scroll?).to be(true)
      expect(wrapper_has_horizontal_scroll?("#trade_card_offers")).to be(false)
    end

    it "general user page has no horizontal scroll for wants section" do
      create(:trade_card_want, trade: trade, card_name: long_card_name, quantity: 1)

      visit trade_path(event)

      expect(page_has_no_horizontal_scroll?).to be(true)
      expect(wrapper_has_horizontal_scroll?("#trade_card_wants")).to be(false)
    end

    it "admin page has no horizontal scroll at 375px" do
      admin = create(:user, :admin)
      sign_in(admin)

      create(:trade_card_offer, trade: trade, card_name: long_card_name, quantity: 1)
      create(:trade_card_want, trade: trade, card_name: long_card_name, quantity: 1)

      visit admin_event_trade_path(event, trade)

      expect(page_has_no_horizontal_scroll?).to be(true)
      expect(wrapper_has_horizontal_scroll?("#trade_card_offers")).to be(false)
      expect(wrapper_has_horizontal_scroll?("#trade_card_wants")).to be(false)
    end
  end

  describe "C5: No horizontal scroll when edit form is open" do
    it "general user offers edit form has no horizontal scroll" do
      create(:trade_card_offer, trade: trade, card_name: long_card_name, quantity: 1)

      visit trade_path(event)

      within("#trade_card_offers") { click_button "編集", match: :first }
      sleep 0.5  # Wait for animation

      expect(page_has_no_horizontal_scroll?).to be(true)
      expect(wrapper_has_horizontal_scroll?("#trade_card_offers")).to be(false)
    end

    it "general user wants edit form has no horizontal scroll" do
      create(:trade_card_want, trade: trade, card_name: long_card_name, quantity: 1)

      visit trade_path(event)

      within("#trade_card_wants") { click_button "編集", match: :first }
      sleep 0.5  # Wait for animation

      expect(page_has_no_horizontal_scroll?).to be(true)
      expect(wrapper_has_horizontal_scroll?("#trade_card_wants")).to be(false)
    end
  end

  describe "C7: Edit form toggle behavior at 375px" do
    it "shows and hides edit form when edit button is clicked" do
      offer = create(:trade_card_offer, trade: trade, card_name: "Test Card")

      visit trade_path(event)

      # Initially hidden
      edit_form_id = "edit_form_trade_card_offer_#{offer.id}"
      expect(page).to have_css("tr##{edit_form_id}", visible: :hidden)

      # Scroll to table to ensure button is visible
      execute_script("document.querySelector('#trade_card_offers').scrollIntoView(true);")
      sleep 0.5

      # Click to show - use javascript to bypass click interception
      button = find("#trade_card_offers button", text: "編集", match: :first)
      execute_script("arguments[0].scrollIntoView(true);", button.native)
      sleep 0.3
      execute_script("arguments[0].click();", button.native)
      sleep 0.5
      expect(page).to have_css("tr##{edit_form_id}", visible: true)

      # Click to hide
      button = find("#trade_card_offers button", text: "編集", match: :first)
      execute_script("arguments[0].scrollIntoView(true);", button.native)
      sleep 0.3
      execute_script("arguments[0].click();", button.native)
      sleep 0.5
      expect(page).to have_css("tr##{edit_form_id}", visible: :hidden)
    end
  end

  describe "C10: Add form auto-clear and toast notification at 375px" do
    it "clears form and shows toast after adding offer" do
      visit trade_path(event)

      find("#add_offer_btn").click
      sleep 0.5

      within("#new_trade_card_offer", visible: :all) do
        fill_in "trade_card_offer[card_name]", with: "Mobile Added Card"
        fill_in "trade_card_offer[quantity]", with: "1"
        click_button "追加"
      end

      # Wait for the card to appear
      expect(page).to have_content("Mobile Added Card")

      # Check toast appears
      expect(page).to have_css("#toast-container")
      expect(page).to have_content("Mobile Added Card")

      # Check form is cleared
      find("#add_offer_btn").click
      sleep 0.5
      within("#new_trade_card_offer", visible: :all) do
        expect(find("input[name='trade_card_offer[card_name]']").value).to be_empty
      end
    end

    it "clears form and shows toast after adding want" do
      visit trade_path(event)

      find("#add_want_btn").click
      sleep 0.5

      within("#new_trade_card_want", visible: :all) do
        fill_in "trade_card_want[card_name]", with: "Mobile Added Card"
        fill_in "trade_card_want[quantity]", with: "1"
        click_button "追加"
      end

      # Wait for the card to appear
      expect(page).to have_content("Mobile Added Card")

      # Check toast appears
      expect(page).to have_css("#toast-container")
      expect(page).to have_content("Mobile Added Card")

      # Check form is cleared
      find("#add_want_btn").click
      sleep 0.5
      within("#new_trade_card_want", visible: :all) do
        expect(find("input[name='trade_card_want[card_name]']").value).to be_empty
      end
    end
  end
end
