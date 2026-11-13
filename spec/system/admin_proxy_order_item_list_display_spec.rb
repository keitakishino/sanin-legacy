require "rails_helper"

RSpec.describe "Admin proxy order item list display", type: :system do
  include ActionView::RecordIdentifier

  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }

  before do
    sign_in admin
    resize_window_to(1280, 900)
  end

  describe "[C1] Items are closed on initial page load" do
    it "shows all items closed, including those with quantity mismatch" do
      proxy_order = create(:proxy_order, event:, status: :ordered)
      # Create a price line (quantity 3) without any allocations (quantity 0)
      mismatch_item = create(:proxy_order_item, proxy_order:, card_name: "Mismatch Card")
      create(:proxy_order_price_line, proxy_order_item: mismatch_item, quantity: 3)

      # Create an item with matching quantities
      match_item = create(:proxy_order_item, proxy_order:, card_name: "Match Card")
      create(:proxy_order_price_line, proxy_order_item: match_item, quantity: 2)
      create(:proxy_order_allocation, proxy_order_item: match_item, quantity: 2)

      visit admin_event_proxy_order_path(event)

      # All items should be closed initially
      expect(page).to have_selector("details##{dom_id(mismatch_item)}:not([open])", visible: :all)
      expect(page).to have_selector("details##{dom_id(match_item)}:not([open])", visible: :all)
    end
  end

  describe "[C2] Items stay open after editing" do
    it "keeps the card open after adding a price line" do
      proxy_order = create(:proxy_order, event:, status: :ordered)
      item = create(:proxy_order_item, proxy_order:, card_name: "Test Card")

      visit admin_event_proxy_order_path(event)

      # Open the item by clicking summary
      find("##{dom_id(item)} summary").click
      expect(page).to have_selector("##{dom_id(item)}[open]")

      # Add a price line
      within "##{dom_id(item)}" do
        fill_in dom_id(item, :new_price_line_unit_price), with: "5.00"
        fill_in "proxy_order_price_line[quantity]", with: "3"
        click_button "＋ 価格行を追加"
      end

      # Wait for the toast message
      expect(page).to have_text("価格行を追加しました")

      # The item should still be open
      expect(page).to have_selector("##{dom_id(item)}[open]")
    end
  end

  describe "[C3] Checkmark displays when quantities match" do
    it "shows checkmark in summary when price line quantity matches allocation quantity" do
      proxy_order = create(:proxy_order, event:, status: :ordered)
      item = create(:proxy_order_item, proxy_order:, card_name: "Match Card")
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 2)
      create(:proxy_order_allocation, proxy_order_item: item, quantity: 2)

      visit admin_event_proxy_order_path(event)

      # Find the summary and verify checkmark is present
      summary = find("##{dom_id(item)} summary")
      expect(summary).to have_selector("[data-role='quantity-match'][aria-label='数量一致']", text: "☑")
    end
  end

  describe "[C4] No checkmark or warning when quantities don't match" do
    it "shows no checkmark for mismatched quantities" do
      proxy_order = create(:proxy_order, event:, status: :ordered)
      item = create(:proxy_order_item, proxy_order:, card_name: "Mismatch Card")
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 3)

      visit admin_event_proxy_order_path(event)

      summary = find("##{dom_id(item)} summary")
      expect(summary).not_to have_selector("[aria-label='数量一致']")
    end
  end

  describe "[C5] Checkmark updates when quantity changes" do
    it "removes checkmark when quantity becomes mismatched" do
      proxy_order = create(:proxy_order, event:, status: :ordered)
      item = create(:proxy_order_item, proxy_order:, card_name: "Test Card")
      price_line = create(:proxy_order_price_line, proxy_order_item: item, quantity: 2)
      create(:proxy_order_allocation, proxy_order_item: item, quantity: 2)

      visit admin_event_proxy_order_path(event)

      # Initially should have checkmark
      summary = find("##{dom_id(item)} summary")
      expect(summary).to have_selector("[data-role='quantity-match']")

      # Open the item and change price line quantity
      find("##{dom_id(item)} summary").click
      expect(page).to have_selector("##{dom_id(item)}[open]")

      within "##{dom_id(price_line)}" do
        fill_in "proxy_order_price_line[quantity]", with: "5"
        find("input[name='proxy_order_price_line[quantity]']").send_keys :tab
      end

      # Wait for update
      expect(page).to have_text("価格行を更新しました")

      # Checkmark should be gone
      summary = find("##{dom_id(item)} summary")
      expect(summary).not_to have_selector("[data-role='quantity-match']")
    end
  end

  describe "[C6] Participant buttons update in other items when guest is added" do
    it "shows new guest button in other items without page reload" do
      proxy_order = create(:proxy_order, event:, status: :ordered)
      item_a = create(:proxy_order_item, proxy_order:, card_name: "Card A")
      item_b = create(:proxy_order_item, proxy_order:, card_name: "Card B")

      visit admin_event_proxy_order_path(event)

      # Open item B first
      find("##{dom_id(item_b)} summary").click
      expect(page).to have_selector("##{dom_id(item_b)}[open]")

      # Verify item B does NOT have new_participant button initially
      within "##{dom_id(item_b, :new_allocation)}" do
        expect(page).not_to have_button("new_participant")
      end

      # Open item A
      find("##{dom_id(item_a)} summary").click
      expect(page).to have_selector("##{dom_id(item_a)}[open]")

      # Add new guest to item A (creates participant and allocation)
      within "##{dom_id(item_a, :new_allocation)}" do
        find("input[role='combobox']").set("new_participant")
        find("[role='listbox'] [role='option']", text: "『new_participant』をゲストとして追加", match: :first).click
        fill_in "proxy_order_allocation[quantity]", with: "1"
        click_button "追加"
      end

      expect(page).to have_text("注文を追加しました")

      # Verify item B's participant buttons section now has the new user (via turbo_stream refresh)
      within "##{dom_id(item_b, :new_allocation)}" do
        expect(page).to have_button("new_participant")
      end

      # Verify item B is still open
      expect(page).to have_selector("##{dom_id(item_b)}[open]")
    end
  end

  describe "[C7] Participant buttons update when allocation is deleted" do
    it "restores deleted participant button in other items after deletion" do
      proxy_order = create(:proxy_order, event:, status: :ordered)
      item_a = create(:proxy_order_item, proxy_order:, card_name: "Card A")
      item_b = create(:proxy_order_item, proxy_order:, card_name: "Card B")

      visit admin_event_proxy_order_path(event)

      # Open item B first, then item A
      find("##{dom_id(item_b)} summary").click
      expect(page).to have_selector("##{dom_id(item_b)}[open]")

      find("##{dom_id(item_a)} summary").click
      expect(page).to have_selector("##{dom_id(item_a)}[open]")

      # Add a new guest to item A
      within "##{dom_id(item_a, :new_allocation)}" do
        find("input[role='combobox']").set("New Guest")
        find("[role='option']", text: "『New Guest』をゲストとして追加", match: :first).click
        fill_in "proxy_order_allocation[quantity]", with: "1"
        click_button "追加"
      end

      expect(page).to have_text("注文を追加しました")

      # Verify A does not have New Guest button (already allocated)
      within "##{dom_id(item_a, :new_allocation)}" do
        expect(page).not_to have_button("New Guest")
      end

      # Verify B has the New Guest button
      within "##{dom_id(item_b, :new_allocation)}" do
        expect(page).to have_button("New Guest")
      end

      # Delete the allocation from item A
      allocation = ProxyOrderAllocation.last
      within "##{dom_id(allocation, :delete)}" do
        accept_confirm { click_button "削除" }
      end

      expect(page).to have_text("注文を削除しました")

      # Verify New Guest button appears in both A and B now
      within "##{dom_id(item_a, :new_allocation)}" do
        expect(page).to have_button("New Guest")
      end
      within "##{dom_id(item_b, :new_allocation)}" do
        expect(page).to have_button("New Guest")
      end
    end
  end

  describe "[C8] Added guest does not appear in own item's buttons" do
    it "does not show added guest button in the item where guest was added" do
      proxy_order = create(:proxy_order, event:, status: :ordered)
      item_a = create(:proxy_order_item, proxy_order:, card_name: "Card A")

      visit admin_event_proxy_order_path(event)

      # Open item A and add a new guest
      find("##{dom_id(item_a)} summary").click
      expect(page).to have_selector("##{dom_id(item_a)}[open]")

      within "##{dom_id(item_a, :new_allocation)}" do
        find("input[role='combobox']").set("New Guest")
        find("[role='option']", text: "『New Guest』をゲストとして追加", match: :first).click
        fill_in "proxy_order_allocation[quantity]", with: "1"
        click_button "追加"
      end

      expect(page).to have_text("注文を追加しました")

      # Verify New Guest button does NOT appear in item A's participant buttons
      within "##{dom_id(item_a, :new_allocation)}" do
        expect(page).not_to have_button("New Guest")
      end
    end
  end

  describe "[C9] Other items remain open when one item's allocation changes" do
    it "keeps other items open when allocation is added to another item" do
      proxy_order = create(:proxy_order, event:, status: :ordered)
      item_a = create(:proxy_order_item, proxy_order:, card_name: "Card A")
      item_b = create(:proxy_order_item, proxy_order:, card_name: "Card B")
      participant = create(:user, username: "test_user")
      create(:proxy_order_participant, proxy_order:, user: participant)

      visit admin_event_proxy_order_path(event)

      # Open item B
      find("##{dom_id(item_b)} summary").click
      expect(page).to have_selector("##{dom_id(item_b)}[open]")

      # Open item A
      find("##{dom_id(item_a)} summary").click
      expect(page).to have_selector("##{dom_id(item_a)}[open]")

      # Add allocation to item A
      within "##{dom_id(item_a, :new_allocation)}" do
        find("input[role='combobox']").set(participant.username)
        find("[role='listbox'] [role='option']", text: participant.username, match: :first).click
        fill_in "proxy_order_allocation[quantity]", with: "1"
        click_button "追加"
      end

      expect(page).to have_text("注文を追加しました")

      # Item B should still be open
      expect(page).to have_selector("##{dom_id(item_b)}[open]")
    end
  end
end
