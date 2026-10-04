require 'rails_helper'

RSpec.describe "Trade card list search, sort, and paging", type: :system do
  let(:expansion) { create(:expansion) }

  def offer_rows_selector = "tbody tr[id^='trade_card_offer_']:not([id^='trade_card_offer_expand']):not([id^='trade_card_offer_edit_form'])"
  def want_rows_selector = "tbody tr[id^='trade_card_want_']:not([id^='trade_card_want_expand']):not([id^='trade_card_want_edit_form'])"

  describe "C1: Paging with 20 items per page" do
    let(:user) { create(:user) }
    let(:event) { create(:event) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(user)
    end
    it "displays 20 records and shows pager when 21+ exist" do
      21.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
      visit trade_path(event)

      within("#trade_card_offers") do
        expect(page).to have_css(offer_rows_selector, count: 20)
      end
      expect(find("#offers_pagination")).to be_visible
    end

    it "shows page 2 content when navigating" do
      21.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
      visit trade_path(event)

      within("#offers_pagination") { click_link "2" }
      expect(page).to have_css("#offers_pagination [aria-current='page']", text: "2")
      expect(page).to have_current_path(/offers_page=2/)
      within("#trade_card_offers") do
        expect(page).to have_css(offer_rows_selector, count: 1)
        expect(page).to have_css(offer_rows_selector, text: "Offer 20")
      end
    end

    it "does not show pager when 20 or fewer items" do
      20.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
      visit trade_path(event)

      expect(find("#trade_card_offers")).not_to have_selector("#offers_pagination")
    end
  end

  describe "C2: PC click sort with cycle asc -> desc -> none" do
    let(:user) { create(:user) }
    let(:event) { create(:event) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(user)
      resize_window_to(1280, 900)
    end

    it "cycles through sort states for card_name" do
      3.times { |i| create(:trade_card_offer, trade:, card_name: "Card #{i}") }
      visit trade_path(event)

      # Initial state should be ↕
      expect(find("#offers_sort_card_name")).to have_text("↕")

      # First click: ascending
      click_link(id: "offers_sort_card_name")
      expect(page).to have_current_path(trade_path(event, offers_sort: "card_name_asc"))
      expect(find("#offers_sort_card_name")).to have_text("▲")

      # Second click: descending
      click_link(id: "offers_sort_card_name")
      expect(page).to have_current_path(%r{offers_sort=card_name_desc})
      expect(find("#offers_sort_card_name")).to have_text("▼")

      # Third click: none
      click_link(id: "offers_sort_card_name")
      expect(page).not_to have_current_path(%r{offers_sort=})
      expect(find("#offers_sort_card_name")).to have_text("↕")
    end

    it "cycles sort for quantity" do
      3.times { |i| create(:trade_card_offer, trade:, card_name: "Card", quantity: i + 1) }
      visit trade_path(event)

      click_link(id: "offers_sort_quantity")
      expect(page).to have_current_path(%r{offers_sort=quantity_asc})
      expect(page).to have_css("#offers_sort_quantity", text: "▲")

      rows = find("#trade_card_offers").all(offer_rows_selector, count: 3)
      quantities = rows.map { |row| row.find("td:nth-child(2)").text.to_i }
      expect(quantities).to eq [ 1, 2, 3 ]
    end

    it "cycles sort for amount" do
      create(:trade_card_offer, trade:, card_name: "A", amount: 100)
      create(:trade_card_offer, trade:, card_name: "B", amount: nil)
      create(:trade_card_offer, trade:, card_name: "C", amount: 50)
      visit trade_path(event)

      click_link(id: "offers_sort_amount")
      expect(page).to have_current_path(%r{offers_sort=amount_asc})
    end
  end

  describe "C3: Mobile sort dropdown" do
    let(:user) { create(:user) }
    let(:event) { create(:event) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(user)
      resize_window_to(375, 800)
    end

    it "displays sort dropdown and changes sort on selection" do
      3.times { |i| create(:trade_card_offer, trade:, card_name: "Card #{i}") }
      visit trade_path(event)

      expect(find("#offers_sort", visible: :all)).to be_visible
      select "数量 降順", from: "offers_sort"

      expect(page).to have_current_path(%r{offers_sort=quantity_desc})
    end

    it "sort dropdown is hidden on desktop" do
      resize_window_to(1280, 900)
      create(:trade_card_offer, trade:)
      visit trade_path(event)

      expect(find("#offers_sort", visible: :all)).not_to be_visible
    end
  end

  describe "C4: Correct sort order with null amounts last" do
    let(:user) { create(:user) }
    let(:event) { create(:event) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(user)
      create(:trade_card_offer, trade:, card_name: "Zebra", quantity: 5, amount: 100)
      create(:trade_card_offer, trade:, card_name: "Apple", quantity: 2, amount: nil)
      create(:trade_card_offer, trade:, card_name: "Middle", quantity: 3, amount: 50)
    end

    it "sorts by card name correctly" do
      visit trade_path(event, offers_sort: "card_name_asc")
      rows = find("#trade_card_offers").all(offer_rows_selector, count: 3)
      names = rows.map { |row| row.find("td:nth-child(1)").text.strip }
      expect(names).to eq([ "Apple", "Middle", "Zebra" ])
    end

    it "sorts by amount ascending with nulls last" do
      visit trade_path(event, offers_sort: "amount_asc")
      rows = find("#trade_card_offers").all(offer_rows_selector, count: 3)
      expect(rows[0]).to have_text("Middle")
      expect(rows[1]).to have_text("Zebra")
      expect(rows[2]).to have_text("Apple")
    end

    it "sorts by amount descending with nulls last" do
      visit trade_path(event, offers_sort: "amount_desc")
      rows = find("#trade_card_offers").all(offer_rows_selector, count: 3)
      expect(rows[0]).to have_text("Zebra")
      expect(rows[1]).to have_text("Middle")
      expect(rows[2]).to have_text("Apple")
    end
  end

  describe "C5: Search by card name with count display" do
    let(:user) { create(:user) }
    let(:event) { create(:event) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(user)
      5.times { |i| create(:trade_card_offer, trade:, card_name: "Apple #{i}") }
      3.times { |i| create(:trade_card_offer, trade:, card_name: "Banana #{i}") }
    end

    it "filters by card name and displays correct count" do
      visit trade_path(event)

      fill_in "offers_q", with: "Apple"
      click_button "offers_search_submit"
      expect(page).to have_current_path(%r{offers_q=Apple})

      within("#trade_card_offers") do
        expect(page).to have_css(offer_rows_selector, count: 5)
      end
      expect(find("#offers_count")).to have_text("「Apple」の検索結果 5件中 1–5件")
    end

    it "displays search result count correctly" do
      visit trade_path(event)

      fill_in "offers_q", with: "Apple"
      click_button "offers_search_submit"
      expect(page).to have_current_path(%r{offers_q=Apple})

      expect(find("#offers_count")).to have_text("「Apple」の検索結果 5件中 1–5件")
    end

    it "shows search box on mobile" do
      resize_window_to(375, 800)
      visit trade_path(event)

      expect(find("#offers_q")).to be_visible
    end

    it "shows search box on desktop" do
      resize_window_to(1280, 900)
      visit trade_path(event)

      expect(find("#offers_q")).to be_visible
    end
  end

  describe "C6: Combined search, sort, and paging" do
    let(:user) { create(:user) }
    let(:event) { create(:event) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(user)
      21.times { |i| create(:trade_card_offer, trade:, card_name: "Apple #{i}") }
      5.times { |i| create(:trade_card_offer, trade:, card_name: "Banana #{i}") }
    end

    it "returns to page 1 when changing search" do
      visit trade_path(event, offers_sort: "card_name_asc", offers_page: "2")

      fill_in "offers_q", with: "Apple"
      click_button "offers_search_submit"

      expect(page).not_to have_current_path(%r{offers_page=})
      expect(page).to have_current_path(%r{offers_q=Apple})
    end

    it "returns to page 1 when changing sort" do
      21.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
      visit trade_path(event, offers_page: "2")

      click_link(id: "offers_sort_card_name")

      expect(page).not_to have_current_path(%r{offers_page=})
    end

    it "handles combined params correctly" do
      visit trade_path(event, offers_q: "Apple", offers_sort: "card_name_asc", offers_page: "2")

      rows = find("#trade_card_offers").all("tbody tr[id^='trade_card_offer_']:not([id^='trade_card_offer_expand']):not([id^='trade_card_offer_edit_form'])")
      expect(rows.count).to be > 0
    end
  end

  describe "C7: No results message" do
    let(:user) { create(:user) }
    let(:event) { create(:event) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(user)
      3.times { |i| create(:trade_card_offer, trade:, card_name: "Apple #{i}") }
    end

    it "shows no results message for empty search" do
      visit trade_path(event, offers_q: "Banana")

      expect(find("#trade_card_offers_empty")).to have_text("該当するカード明細はありません")
    end

    it "shows correct message when no offers exist" do
      trade.trade_card_offers.destroy_all
      visit trade_path(event)

      expect(find("#trade_card_offers_empty")).to have_text("カード明細はまだありません")
    end
  end

  describe "C8: List independence" do
    let(:user) { create(:user) }
    let(:event) { create(:event) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(user)
      5.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
      5.times { |i| create(:trade_card_want, trade:, card_name: "Want #{i}") }
    end

    it "offers list operations don't affect wants list" do
      visit trade_path(event)

      fill_in "offers_q", with: "Offer 1"
      click_button "offers_search_submit"
      expect(page).to have_current_path(%r{offers_q=Offer\+1})

      # Offers should be filtered
      within("#trade_card_offers") do
        expect(page).to have_css(offer_rows_selector, count: 1)
      end

      # Wants should show all
      within("#trade_card_wants") do
        expect(page).to have_css(want_rows_selector, count: 5)
      end

      # Wants search value should be empty
      expect(page).to have_field("wants_q", with: "")
    end

    it "wants list operations don't affect offers list" do
      visit trade_path(event)

      fill_in "wants_q", with: "Want 2"
      click_button "wants_search_submit"
      expect(page).to have_current_path(%r{wants_q=Want\+2})

      # Wants should be filtered
      within("#trade_card_wants") do
        expect(page).to have_css(want_rows_selector, count: 1)
      end

      # Offers should show all
      within("#trade_card_offers") do
        expect(page).to have_css(offer_rows_selector, count: 5)
      end
    end

    it "sort in offers doesn't affect wants sort" do
      visit trade_path(event)

      click_link(id: "offers_sort_card_name")

      expect(page).to have_current_path(%r{offers_sort=card_name_asc})
      expect(page).not_to have_current_path(%r{wants_sort=})
      expect(find("#wants_sort", visible: :all).value).to eq ""
    end
  end

  describe "C9: URL parameter preservation across operations" do
    let(:user) { create(:user) }
    let(:event) { create(:event) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(user)
      10.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
      10.times { |i| create(:trade_card_want, trade:, card_name: "Want #{i}") }
    end

    it "preserves wants params when modifying offers" do
      visit trade_path(event, wants_q: "Want", wants_sort: "card_name_desc")

      fill_in "offers_q", with: "Offer"
      click_button "offers_search_submit"

      expect(page).to have_current_path(%r{offers_q=Offer})
      expect(page).to have_current_path(%r{wants_q=Want})
      expect(page).to have_current_path(%r{wants_sort=card_name_desc})
    end

    it "preserves offers params when modifying wants" do
      visit trade_path(event, offers_q: "Offer", offers_sort: "card_name_asc")

      fill_in "wants_q", with: "Want"
      click_button "wants_search_submit"

      expect(page).to have_current_path(%r{offers_q=Offer})
      expect(page).to have_current_path(%r{offers_sort=card_name_asc})
      expect(page).to have_current_path(%r{wants_q=Want})
    end

    it "restores both list states after page reload" do
      resize_window_to(375, 800)
      visit trade_path(event)

      fill_in "offers_q", with: "Offer"
      click_button "offers_search_submit"
      expect(page).to have_current_path(%r{offers_q=Offer})

      select "カード名 降順", from: "wants_sort"
      expect(page).to have_current_path(%r{wants_sort=card_name_desc})

      # Verify URL parameters are preserved
      saved_url = current_url
      expect(saved_url).to match(%r{offers_q=Offer})
      expect(saved_url).to match(%r{wants_sort=card_name_desc})

      # Verify after reload
      visit saved_url
      expect(page).to have_current_path(%r{offers_q=Offer})
      expect(page).to have_current_path(%r{wants_sort=card_name_desc})
    end
  end

  describe "C13: Discarded records excluded" do
    let(:user) { create(:user) }
    let(:event) { create(:event) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(user)
      create(:trade_card_offer, trade:, card_name: "Visible")
      @discarded = create(:trade_card_offer, trade:, card_name: "Discarded")
      @discarded.discard!
    end

    it "excludes discarded offers from display" do
      visit trade_path(event)

      within("#trade_card_offers") do
        expect(page).to have_css(offer_rows_selector, count: 1)
        expect(page).to have_css(offer_rows_selector, text: "Visible")
      end
    end

    it "excludes discarded from count" do
      visit trade_path(event)

      expect(find("#offers_count")).to have_text("1件中 1–1件")
    end
  end

  describe "C15: Total amounts unchanged by search/paging" do
    let(:user) { create(:user) }
    let(:event) { create(:event) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(user)
      create(:trade_card_offer, trade:, card_name: "Match 1", quantity: 2, amount: 100)
      create(:trade_card_offer, trade:, card_name: "Match 2", quantity: 3, amount: 50)
      20.times { |i| create(:trade_card_offer, trade:, card_name: "Card #{i}", quantity: 1, amount: nil) }
    end

    it "shows same total before and after search" do
      visit trade_path(event)
      before_total = find("#trade_aggregates").text

      fill_in "offers_q", with: "Match"
      click_button "offers_search_submit"
      # Wait for Turbo to replace page content after navigation
      expect(page).to have_current_path(%r{offers_q=Match})
      # Wait for the count display to update with filtered results
      expect(page).to have_css("#offers_count", text: "「Match」の検索結果 2件中 1–2件", wait: 10)

      # The page shows filtered results but aggregates remain the same
      after_total = find("#trade_aggregates").text
      expect(before_total).to eq after_total
    end

    it "shows same total before and after paging" do
      visit trade_path(event)
      before_total = find("#trade_aggregates").text

      within("#offers_pagination") { click_link "2" }
      expect(page).to have_css("#offers_pagination [aria-current='page']", text: "2")

      after_total = find("#trade_aggregates").text
      expect(before_total).to eq after_total
    end
  end
end
