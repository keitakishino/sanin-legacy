require "rails_helper"

RSpec.describe "Admin Proxy Order Item Inputs", type: :system do
  include ActionView::RecordIdentifier

  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
  let!(:user) { create(:user, username: "TestUser") }

  before do
    sign_in(admin)
    resize_window_to(1280, 900)
  end

  def open_item(item)
    # Details are initially closed, so click summary to open
    find("details##{dom_id(item)} > summary").click
    expect(page).to have_selector("details##{dom_id(item)}[open]")
  end

  def js_trim(value)
    value.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
  end

  describe "[C1] Initial quantity value for price line add form" do
    it "sets quantity to 1 for new price line form" do
      proxy_order = create(:proxy_order, event:)
      item = create(:proxy_order_item, proxy_order:, card_name: "Test Card")
      # Create a price line to have quantity data available
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 1)
      visit admin_event_proxy_order_path(event)
      open_item(item)

      input = find("#new_price_line_proxy_order_item_#{item.id} input[name='proxy_order_price_line[quantity]']")
      expect(input.value).to eq("1")
    end
  end

  describe "[C2] Initial quantity value for allocation add form with remaining quantity" do
    it "sets allocation quantity to remaining amount when price lines > allocations" do
      item = create(:proxy_order_item, proxy_order: create(:proxy_order, event:), card_name: "Test Card")
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 3)
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 2)
      create(:proxy_order_allocation, proxy_order_item: item, quantity: 2)
      visit admin_event_proxy_order_path(event)
      open_item(item)

      input = find("#new_allocation_proxy_order_item_#{item.id} input[name='proxy_order_allocation[quantity]']")
      expect(input.value).to eq("3")
    end
  end

  describe "[C3] Initial quantity defaults to 1 when allocations >= price lines" do
    it "sets allocation quantity to 1 when already allocated all" do
      item = create(:proxy_order_item, proxy_order: create(:proxy_order, event:), card_name: "Test Card")
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 2)
      create(:proxy_order_allocation, proxy_order_item: item, quantity: 3)
      visit admin_event_proxy_order_path(event)
      open_item(item)

      input = find("#new_allocation_proxy_order_item_#{item.id} input[name='proxy_order_allocation[quantity]']")
      expect(input.value).to eq("1")
    end
  end

  describe "[C4] Allocation quantity updates after adding allocation" do
    it "updates the remaining quantity in add form after adding allocation" do
      item = create(:proxy_order_item, proxy_order: create(:proxy_order, event:), card_name: "Test Card")
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 5)
      visit admin_event_proxy_order_path(event)
      open_item(item)

      within "#new_allocation_proxy_order_item_#{item.id}" do
        find("input[role='combobox']").set(user.username)
        find("[role='listbox'] [role='option']", text: user.username, match: :first).click
        fill_in "proxy_order_allocation[quantity]", with: "2"
        click_button "追加"
      end
      expect(page).to have_content("注文を追加しました")

      input = find("#new_allocation_proxy_order_item_#{item.id} input[name='proxy_order_allocation[quantity]']")
      expect(input.value).to eq("3")
    end
  end

  describe "[C5] Enter moves focus from price line quantity to next unit price" do
    it "focuses next line unit price when Enter pressed on quantity" do
      item = create(:proxy_order_item, proxy_order: create(:proxy_order, event:), card_name: "Test Card")
      line1 = create(:proxy_order_price_line, proxy_order_item: item, quantity: 3)
      line2 = create(:proxy_order_price_line, proxy_order_item: item, quantity: 2)
      visit admin_event_proxy_order_path(event)
      open_item(item)

      quantity_input = find("##{dom_id(line1)} input[name='proxy_order_price_line[quantity]']")
      quantity_input.send_keys(:enter)

      expect(page).to have_css("##{dom_id(line2, :unit_price)}:focus")
    end
  end

  describe "[C6] Enter on last price line focuses new price line unit price" do
    it "focuses new price line form unit price when Enter on last line" do
      item = create(:proxy_order_item, proxy_order: create(:proxy_order, event:), card_name: "Test Card")
      line = create(:proxy_order_price_line, proxy_order_item: item, quantity: 3)
      visit admin_event_proxy_order_path(event)
      open_item(item)

      quantity_input = find("##{dom_id(line)} input[name='proxy_order_price_line[quantity]']")
      quantity_input.send_keys(:enter)

      expect(page).to have_css("##{dom_id(item, :new_price_line_unit_price)}:focus")
    end
  end

  describe "[C7] Enter on add form quantity focuses new add form unit price" do
    it "focuses new form unit price after adding price line via Enter" do
      proxy_order = create(:proxy_order, event:)
      item = create(:proxy_order_item, proxy_order:, card_name: "Test Card")
      # Create a price line to have quantity data available
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 1)
      visit admin_event_proxy_order_path(event)
      open_item(item)

      find("##{dom_id(item, :new_price_line)} input[name='proxy_order_price_line[unit_price_usd]']").set("3.00")
      quantity_input = find("##{dom_id(item, :new_price_line)} input[name='proxy_order_price_line[quantity]']")
      quantity_input.set("2")
      quantity_input.send_keys(:enter)

      expect(page).to have_content("価格行を追加しました")
      expect(page).to have_css("##{dom_id(item, :new_price_line_unit_price)}:focus")
      expect(ProxyOrderPriceLine.count).to eq(2)
    end
  end

  describe "[C8] No update button in edit form" do
    it "does not show update button in card edit form" do
      proxy_order = create(:proxy_order, event:)
      item = create(:proxy_order_item, proxy_order:, card_name: "Test Card")
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 1)
      visit admin_event_proxy_order_path(event)
      open_item(item)

      within "##{dom_id(item, :edit_form)}" do
        expect(page).not_to have_button("更新")
      end
    end
  end

  describe "[C9] Auto-save on field change in edit form" do
    it "saves changes without update button for card name" do
      proxy_order = create(:proxy_order, event:)
      item = create(:proxy_order_item, proxy_order:, card_name: "Original")
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 1)
      visit admin_event_proxy_order_path(event)
      open_item(item)

      field = find("##{dom_id(item, :edit_form)} input[name='proxy_order_item[card_name]']")
      field.set("Updated Name")
      field.send_keys(:tab)
      expect(page).to have_content("カードを更新しました")
      expect(item.reload.card_name).to eq("Updated Name")
    end

    it "saves changes on foil select change" do
      proxy_order = create(:proxy_order, event:)
      item = create(:proxy_order_item, proxy_order:, card_name: "Test", foil: :foil)
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 1)
      visit admin_event_proxy_order_path(event)
      open_item(item)

      within "##{dom_id(item, :edit_form)}" do
        select "non-foil", from: "proxy_order_item[foil]"
      end
      expect(page).to have_content("カードを更新しました")
      expect(item.reload.foil).to eq("non_foil")
    end

    it "saves changes on frame select change" do
      proxy_order = create(:proxy_order, event:)
      item = create(:proxy_order_item, proxy_order:, card_name: "Test", frame: :normal)
      create(:proxy_order_price_line, proxy_order_item: item, quantity: 1)
      visit admin_event_proxy_order_path(event)
      open_item(item)

      within "##{dom_id(item, :edit_form)}" do
        select "拡張アート", from: "proxy_order_item[frame]"
      end
      expect(page).to have_content("カードを更新しました")
      expect(item.reload.frame).to eq("extended")
    end
  end

  describe "[C10] Enter on existing price line quantity updates with message" do
    it "saves quantity change and shows message when Enter pressed" do
      item = create(:proxy_order_item, proxy_order: create(:proxy_order, event:), card_name: "Test Card")
      line = create(:proxy_order_price_line, proxy_order_item: item, quantity: 3)
      visit admin_event_proxy_order_path(event)
      open_item(item)

      quantity_input = find("##{dom_id(line)} input[name='proxy_order_price_line[quantity]']")
      quantity_input.set("4")
      quantity_input.send_keys(:enter)

      expect(page).to have_content("価格行を更新しました")
      expect(line.reload.quantity).to eq(4)
    end
  end
end
