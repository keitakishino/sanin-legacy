require "rails_helper"

RSpec.describe "Admin Proxy Order Clear Filter", type: :system do
  include ActionView::RecordIdentifier

  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
  let(:proxy_order) { create(:proxy_order, event:, status: :ordered) }

  before do
    sign_in admin
    resize_window_to(1280, 900)
    proxy_order  # Ensure proxy_order is created before tests
  end

  def wait_for_item_list_update
    execute_script("document.querySelector('#proxy_order_list_bar').setAttribute('data-stale', '')")
    yield
    expect(page).to have_css("#proxy_order_list_bar:not([data-stale])")
  end

  describe "[C1] clear filter button display" do
    it "displays the clear filter button with text during filtering" do
      create(:proxy_order_item, proxy_order:, card_name: "Test Card")
      create(:proxy_order_item, proxy_order:, card_name: "Other Card")

      visit admin_event_proxy_order_path(event)

      expect(page).to have_no_css("a[data-role=clear-search]")

      find("#proxy_order_item_search").fill_in(with: "Test")
      wait_for_item_list_update { find("#proxy_order_item_search").send_keys(:enter) }

      expect(page).to have_current_path(%r{q=Test})

      within("#proxy_order_list_bar") do
        expect(page).to have_css("a[data-role=clear-search]", text: "絞り込み解除", visible: true)
      end
    end
  end

  describe "[C2] clear filter button functionality" do
    it "clears the filter and returns to the unfiltered list" do
      create(:proxy_order_item, proxy_order:, card_name: "Test Card")
      create(:proxy_order_item, proxy_order:, card_name: "Other Card")

      visit admin_event_proxy_order_path(event)

      find("#proxy_order_item_search").fill_in(with: "Test")
      wait_for_item_list_update { find("#proxy_order_item_search").send_keys(:enter) }

      expect(find("#proxy_order_item_count")).to have_text("1 件")

      wait_for_item_list_update { find("a[data-role=clear-search]").click }

      expect(page).to have_current_path(admin_event_proxy_order_path(event))
      expect(find("#proxy_order_item_count")).to have_text("全 2 件")
      expect(find("#proxy_order_item_search").value).to be_empty
      card_names = all("[data-role=card-name]").map(&:text)
      expect(card_names).to include("Test Card", "Other Card")
      expect(page).to have_no_css("a[data-role=clear-search]")
    end
  end
end
