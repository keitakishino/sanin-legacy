# System spec for Issue #384: Mobile responsive combobox and participant buttons
# Tests participant-select Stimulus controller on mobile viewport (390x844)
require "rails_helper"

RSpec.describe "Admin Proxy Order Participant Select Mobile", type: :system do
  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
  let!(:buyer) { create(:user, username: "buyer") }
  let!(:takahashi) { create(:user, username: "takahashi") }
  let!(:tanaka) { create(:user, username: "Tanaka") }

  let!(:proxy_order) { create(:proxy_order, event:, status: :ordered) }
  let!(:item) { create(:proxy_order_item, proxy_order:, card_name: "Target Card") }
  let!(:p_takahashi) { create(:proxy_order_participant, proxy_order:, user: takahashi) }
  let!(:p_single_char) { create(:proxy_order_participant, :guest, proxy_order:, guest_name: "A") }
  let!(:p_long_name) { create(:proxy_order_participant, :guest, proxy_order:, guest_name: "X" * 60) }
  let!(:p_done) do
    participant = create(:proxy_order_participant, proxy_order:, user: tanaka)
    create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant)
    participant
  end

  before do
    sign_in(admin)
    resize_window_to(390, 844)
    visit admin_event_proxy_order_path(event)
    # Open the item details if not already open
    unless find("#proxy_order_item_#{item.id}")[:open]
      find("#proxy_order_item_#{item.id} summary").click
    end
  end

  describe "C1: Participant button wrapping on mobile" do
    it "wraps participant buttons without horizontal scroll" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"

      # Check that there are at least 2 participant buttons
      buttons = find(scope).all("button[data-action='participant-select#pick']")
      expect(buttons.length).to be >= 2

      # Get button positions - use scope selector with proper escaping
      button_tops = page.evaluate_script(
        "Array.from(document.querySelector('#{scope}').querySelectorAll('button[data-action=\"participant-select#pick\"]')).map(b => b.getBoundingClientRect().top)"
      )

      # Buttons should be on at least 2 different rows (different top values)
      expect(button_tops.uniq.length).to be >= 2

      # Check buttons fit within scope
      scope_rect = page.evaluate_script(
        "document.querySelector('#{scope}').getBoundingClientRect()"
      )
      buttons_rects = page.evaluate_script(
        "Array.from(document.querySelector('#{scope}').querySelectorAll('button[data-action=\"participant-select#pick\"]')).map(b => ({left: b.getBoundingClientRect().left, right: b.getBoundingClientRect().right}))"
      )

      buttons_rects.each do |rect|
        expect(rect["right"]).to be <= scope_rect["right"] + 1
        expect(rect["left"]).to be >= scope_rect["left"] - 1
      end

      # Check no horizontal scroll in scope
      scroll_width = page.evaluate_script("document.querySelector('#{scope}').scrollWidth")
      client_width = page.evaluate_script("document.querySelector('#{scope}').clientWidth")
      expect(scroll_width).to be <= client_width + 1
    end
  end

  describe "C2: Candidate list full-width display on mobile" do
    it "displays candidate list below input at full form width with no horizontal scroll" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"

      within scope do
        input = find("input[role='combobox']")
        input.set("Y" * 60)

        list = find("ul[role='listbox']")
        expect(list).to be_visible
      end

      # Check list position and dimensions
      input_rect = page.evaluate_script(
        "document.querySelector('input[role=\"combobox\"]').getBoundingClientRect()"
      )
      list_rect = page.evaluate_script(
        "document.querySelector('ul[role=\"listbox\"]').getBoundingClientRect()"
      )

      # List should be below input
      expect(list_rect["top"]).to be >= input_rect["bottom"] - 1

      # List should fit within window
      expect(list_rect["right"]).to be <= page.evaluate_script("window.innerWidth") + 1

      # No horizontal scroll in list
      list_scroll_width = page.evaluate_script("document.querySelector('ul[role=\"listbox\"]').scrollWidth")
      list_client_width = page.evaluate_script("document.querySelector('ul[role=\"listbox\"]').clientWidth")
      expect(list_scroll_width).to be <= list_client_width + 1
    end
  end

  describe "C3: Tap area size (44px minimum)" do
    it "ensures participant buttons have adequate touch area" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"

      buttons = find(scope).all("button[data-action='participant-select#pick']")
      expect(buttons.length).to be >= 1

      buttons_rects = page.evaluate_script(
        "Array.from(document.querySelector('#{scope}').querySelectorAll('button[data-action=\"participant-select#pick\"]')).map(b => ({height: b.getBoundingClientRect().height, width: b.getBoundingClientRect().width}))"
      )

      buttons_rects.each do |rect|
        # Allow some tolerance for rounding
        expect(rect["height"]).to be >= 43
        expect(rect["width"]).to be >= 43
      end
    end

    it "ensures candidate list items have adequate touch area" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"

      within scope do
        input = find("input[role='combobox']")
        input.set("ta")

        list = find("ul[role='listbox']")
        expect(list).to be_visible
      end

      options = page.all("[role='option']")
      expect(options.length).to be >= 1

      options_rects = page.evaluate_script(
        "Array.from(document.querySelectorAll('[role=\"option\"]')).map(o => ({height: o.getBoundingClientRect().height, width: o.getBoundingClientRect().width}))"
      )

      options_rects.each do |rect|
        expect(rect["height"]).to be >= 43
        expect(rect["width"]).to be >= 43
      end
    end
  end
end
