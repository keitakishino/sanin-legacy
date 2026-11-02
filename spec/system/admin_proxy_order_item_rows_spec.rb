# System spec for existing proxy order item functionality  (C10, C12)
# Ensures that price lines, allocations, and other non-combobox features continue to work
require "rails_helper"

RSpec.describe "Admin Proxy Order Item Rows", type: :system do
  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
  let!(:buyer) { create(:user, username: "buyer") }

  def set_and_commit(selector, value)
    field = find(selector)
    field.set(value)
    field.send_keys(:tab)
  end

  before do
    sign_in(admin)
    resize_window_to(1280, 900)
  end

  describe "C10: Price line and allocation operations" do
    it "can add and delete price lines in ordered state" do
      proxy_order = create(:proxy_order, event:, status: :ordered)
      item = create(:proxy_order_item, proxy_order:, card_name: "Test Card")
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 2.00, quantity: 3)

      visit admin_event_proxy_order_path(event)

      # details element が open されるまで待つ
      details = find("#proxy_order_item_#{item.id}")
      find("#proxy_order_item_#{item.id} summary").click unless details[:open]
      expect(page).to have_selector("#proxy_order_item_#{item.id}[open]", visible: :all, wait: 5)

      # Add new price line
      expect(page).to have_selector("#new_price_line_proxy_order_item_#{item.id}", visible: true, wait: 3)
      within "#new_price_line_proxy_order_item_#{item.id}" do
        fill_in "proxy_order_price_line[unit_price_usd]", with: "1.00"
        fill_in "proxy_order_price_line[quantity]", with: "1"
        click_button "＋ 価格行を追加"
      end
      expect(page).to have_content("価格行を追加しました")
      expect(ProxyOrderPriceLine.count).to eq(2)

      # Delete price line
      new_line = ProxyOrderPriceLine.order(:id).last
      within "#delete_proxy_order_price_line_#{new_line.id}" do
        accept_confirm { click_button "削除" }
      end
      expect(page).to have_content("価格行を削除しました")
      expect(ProxyOrderPriceLine.count).to eq(1)
    end

    it "can update lost quantity in arrived state" do
      proxy_order = create(:proxy_order, event:, status: :arrived, usd_jpy_rate: 150)
      item = create(:proxy_order_item, proxy_order:, card_name: "Arrived Card")
      participant = create(:proxy_order_participant, proxy_order:, user: buyer)
      allocation = create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 2)

      visit admin_event_proxy_order_path(event)

      # details element を開く
      details = find("#proxy_order_item_#{item.id}")
      find("#proxy_order_item_#{item.id} summary").click unless details[:open]
      expect(page).to have_selector("#proxy_order_item_#{item.id}[open]", visible: :all, wait: 5)

      # Update lost quantity: form の中の lost_quantity input を探す
      # form_with で model: allocation が指定されているので、id は dom_id(allocation) になる
      form_id = "proxy_order_allocation_#{allocation.id}"
      selector = "[id='#{form_id}'] input[name='proxy_order_allocation[lost_quantity]']"
      expect(page).to have_selector(selector, visible: true, wait: 3)
      set_and_commit selector, "1"
      expect(page).to have_content("注文を更新しました")
      expect(allocation.reload.lost_quantity).to eq(1)
    end
  end

  describe "C12: new_allocation visibility" do
    it "is not shown when proxy order is in arrived state" do
      proxy_order = create(:proxy_order, event:, status: :arrived, usd_jpy_rate: 150)
      item = create(:proxy_order_item, proxy_order:, card_name: "Arrived Card")

      visit admin_event_proxy_order_path(event)
      find("#proxy_order_item_#{item.id} summary").click

      expect(page).not_to have_selector("input[role='combobox']")
    end

    it "is not shown when proxy order is completed" do
      proxy_order = create(:proxy_order, event:, status: :completed, usd_jpy_rate: 150)
      item = create(:proxy_order_item, proxy_order:, card_name: "Completed Card")

      visit admin_event_proxy_order_path(event)
      find("#proxy_order_item_#{item.id} summary").click

      expect(page).not_to have_selector("input[role='combobox']")
    end
  end
end
