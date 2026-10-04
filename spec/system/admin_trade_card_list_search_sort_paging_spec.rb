require 'rails_helper'

RSpec.describe "Admin trade card list search, sort, and paging", type: :system do
  let(:expansion) { create(:expansion) }
  let(:admin_user) { create(:user, :admin) }

  def offer_rows_selector = "tbody tr[id^='trade_card_offer_']:not([id^='trade_card_offer_expand']):not([id^='trade_card_offer_edit_form'])"
  def want_rows_selector = "tbody tr[id^='trade_card_want_']:not([id^='trade_card_want_expand']):not([id^='trade_card_want_edit_form'])"

  describe "C1: Paging with 20 items per page" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(admin_user)
    end

    it "displays 20 records and shows pager when 21+ exist" do
      21.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
      visit admin_event_trade_path(event, trade)

      within("#trade_card_offers") do
        expect(page).to have_css(offer_rows_selector, count: 20)
      end
      expect(find("#offers_pagination")).to be_visible
    end

    it "shows page 2 content when navigating" do
      21.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
      visit admin_event_trade_path(event, trade)

      within("#offers_pagination") { click_link "2" }
      expect(page).to have_css("#offers_pagination [aria-current='page']", text: "2")
      expect(page).to have_current_path(/offers_page=2/)
      within("#trade_card_offers") do
        expect(page).to have_css(offer_rows_selector, count: 1)
      end
    end

    it "does not show pager when 20 or fewer items" do
      20.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
      visit admin_event_trade_path(event, trade)

      expect(find("#trade_card_offers")).not_to have_selector("#offers_pagination")
    end

    it "displays 20 records for wants and shows pager when 21+ exist" do
      21.times { |i| create(:trade_card_want, trade:, card_name: "Want #{i}") }
      visit admin_event_trade_path(event, trade)

      within("#trade_card_wants") do
        expect(page).to have_css(want_rows_selector, count: 20)
      end
      expect(find("#wants_pagination")).to be_visible
    end
  end

  describe "C2: PC click sort with cycle asc -> desc -> none" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(admin_user)
      resize_window_to(1280, 900)
    end

    it "sorts offers by card name with cycle asc -> desc -> none" do
      create(:trade_card_offer, trade:, card_name: "Banana", quantity: 1)
      create(:trade_card_offer, trade:, card_name: "Apple", quantity: 1)
      create(:trade_card_offer, trade:, card_name: "Cherry", quantity: 1)
      visit admin_event_trade_path(event, trade)

      # First click: asc
      click_link(id: "offers_sort_card_name")
      expect(page).to have_current_path(%r{offers_sort=card_name_asc})

      # Second click: desc
      click_link(id: "offers_sort_card_name")
      expect(page).to have_current_path(%r{offers_sort=card_name_desc})

      # Third click: clear
      click_link(id: "offers_sort_card_name")
      expect(page).not_to have_current_path(%r{offers_sort=})
    end

    it "sorts offers by quantity with cycle asc -> desc -> none" do
      create(:trade_card_offer, trade:, card_name: "Banana", quantity: 3)
      create(:trade_card_offer, trade:, card_name: "Apple", quantity: 1)
      create(:trade_card_offer, trade:, card_name: "Cherry", quantity: 2)
      visit admin_event_trade_path(event, trade)

      click_link(id: "offers_sort_quantity")
      expect(page).to have_current_path(%r{offers_sort=quantity_asc})

      click_link(id: "offers_sort_quantity")
      expect(page).to have_current_path(%r{offers_sort=quantity_desc})

      click_link(id: "offers_sort_quantity")
      expect(page).not_to have_current_path(%r{offers_sort=})
    end

    it "sorts offers by amount with cycle asc -> desc -> none" do
      create(:trade_card_offer, trade:, card_name: "Banana", amount: 200)
      create(:trade_card_offer, trade:, card_name: "Apple", amount: 100)
      create(:trade_card_offer, trade:, card_name: "Cherry", amount: 150)
      visit admin_event_trade_path(event, trade)

      click_link(id: "offers_sort_amount")
      expect(page).to have_current_path(%r{offers_sort=amount_asc})

      click_link(id: "offers_sort_amount")
      expect(page).to have_current_path(%r{offers_sort=amount_desc})

      click_link(id: "offers_sort_amount")
      expect(page).not_to have_current_path(%r{offers_sort=})
    end
  end

  describe "C3: Mobile dropdown sort" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(admin_user)
      resize_window_to(375, 800)
    end

    it "changes offers sort via dropdown at 375px width" do
      create(:trade_card_offer, trade:, card_name: "Banana", quantity: 1)
      create(:trade_card_offer, trade:, card_name: "Apple", quantity: 1)
      visit admin_event_trade_path(event, trade)

      select "数量 降順", from: "offers_sort"
      expect(page).to have_current_path(%r{offers_sort=quantity_desc})
    end

    it "changes wants sort via dropdown at 375px width" do
      create(:trade_card_want, trade:, card_name: "Banana", quantity: 1)
      create(:trade_card_want, trade:, card_name: "Apple", quantity: 1)
      visit admin_event_trade_path(event, trade)

      select "単価 昇順", from: "wants_sort"
      expect(page).to have_current_path(%r{wants_sort=amount_asc})
    end
  end

  describe "C4: Sort correctness with nil amount at end" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(admin_user)
    end

    it "sorts card_name_asc correctly" do
      create(:trade_card_offer, trade:, card_name: "Cherry")
      create(:trade_card_offer, trade:, card_name: "Apple")
      visit admin_event_trade_path(event, trade, offers_sort: "card_name_asc")

      within("#trade_card_offers") do
        rows = page.all(offer_rows_selector)
        expect(rows[0]).to have_text("Apple")
        expect(rows[1]).to have_text("Cherry")
      end
    end

    it "sorts amount_asc with nil at end" do
      create(:trade_card_offer, trade:, card_name: "A", amount: 100)
      create(:trade_card_offer, trade:, card_name: "B", amount: nil)
      create(:trade_card_offer, trade:, card_name: "C", amount: 50)
      visit admin_event_trade_path(event, trade, offers_sort: "amount_asc")

      within("#trade_card_offers") do
        rows = page.all(offer_rows_selector)
        expect(rows[0]).to have_text("C")
        expect(rows[1]).to have_text("A")
        expect(rows[2]).to have_text("B")
      end
    end

    it "sorts amount_desc with nil at end" do
      create(:trade_card_offer, trade:, card_name: "A", amount: 100)
      create(:trade_card_offer, trade:, card_name: "B", amount: nil)
      create(:trade_card_offer, trade:, card_name: "C", amount: 50)
      visit admin_event_trade_path(event, trade, offers_sort: "amount_desc")

      within("#trade_card_offers") do
        rows = page.all(offer_rows_selector)
        expect(rows[0]).to have_text("A")
        expect(rows[1]).to have_text("C")
        expect(rows[2]).to have_text("B")
      end
    end
  end

  describe "C5: Search with partial match" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(admin_user)
    end

    it "searches offers by card name at 1280px" do
      create(:trade_card_offer, trade:, card_name: "Apple")
      create(:trade_card_offer, trade:, card_name: "Banana")
      visit admin_event_trade_path(event, trade)

      resize_window_to(1280, 900)
      fill_in "offers_q", with: "Apple"
      find("#offers_search_submit").click

      expect(page).to have_current_path(%r{offers_q=Apple})
      within("#trade_card_offers") do
        expect(page).to have_text("Apple")
        expect(page).not_to have_text("Banana")
      end
    end

    it "shows search result count for offers" do
      5.times { |i| create(:trade_card_offer, trade:, card_name: "Apple #{i}") }
      create(:trade_card_offer, trade:, card_name: "Banana")
      visit admin_event_trade_path(event, trade, offers_q: "Apple")

      expect(find("#offers_count")).to have_text("「Apple」の検索結果 5件中 1–5件")
    end

    it "searches wants by card name at 375px" do
      create(:trade_card_want, trade:, card_name: "Apple")
      create(:trade_card_want, trade:, card_name: "Banana")
      visit admin_event_trade_path(event, trade)

      resize_window_to(375, 800)
      fill_in "wants_q", with: "Banana"
      find("#wants_search_submit").click

      expect(page).to have_current_path(%r{wants_q=Banana})
      within("#trade_card_wants") do
        expect(page).to have_text("Banana")
        expect(page).not_to have_text("Apple")
      end
    end
  end

  describe "C6: Search or sort resets page to 1" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(admin_user)
      resize_window_to(1280, 900)
    end

    it "resets offers page to 1 when changing sort" do
      25.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
      visit admin_event_trade_path(event, trade, offers_page: 2, offers_sort: "card_name_asc")

      click_link(id: "offers_sort_card_name")
      expect(page).not_to have_current_path(%r{offers_page=2})
      expect(page).to have_current_path(%r{offers_sort=})
    end

    it "resets offers page to 1 when searching" do
      25.times { |i| create(:trade_card_offer, trade:, card_name: "Apple #{i}") }
      visit admin_event_trade_path(event, trade, offers_page: 2)

      fill_in "offers_q", with: "Apple"
      find("#offers_search_submit").click
      expect(page).not_to have_current_path(%r{offers_page=2})
    end
  end

  describe "C7: Zero result message" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(admin_user)
    end

    it "shows no match message when search returns no results" do
      create(:trade_card_offer, trade:, card_name: "Apple")
      visit admin_event_trade_path(event, trade, offers_q: "Banana")

      expect(find("#trade_card_offers_empty")).to have_text("該当するカード明細はありません")
    end

    it "shows no items message when no items exist" do
      visit admin_event_trade_path(event, trade)

      expect(find("#trade_card_offers_empty")).to have_text("カード明細はまだありません")
    end
  end

  describe "C8: Independent list operations" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(admin_user)
    end

    it "searching offers does not affect wants" do
      5.times { |i| create(:trade_card_offer, trade:, card_name: "Apple #{i}") }
      5.times { |i| create(:trade_card_want, trade:, card_name: "Want #{i}") }
      visit admin_event_trade_path(event, trade)

      fill_in "offers_q", with: "Apple"
      click_button "検索", id: "offers_search_submit"

      expect(find("#offers_q").value).to eq("Apple")
      expect(find("#wants_q").value).to be_empty
      within("#trade_card_wants") do
        expect(page).to have_css(want_rows_selector, count: 5)
      end
    end

    it "sorting offers does not affect wants sort" do
      3.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
      3.times { |i| create(:trade_card_want, trade:, card_name: "Want #{i}") }
      visit admin_event_trade_path(event, trade)

      find("#offers_sort_card_name").click
      expect(page).to have_current_path(%r{offers_sort=card_name_asc})
      expect(page).not_to have_current_path(%r{wants_sort=})
    end
  end

  describe "C9: Parameter preservation across operations" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(admin_user)
      resize_window_to(1280, 900)
    end

    it "preserves wants parameters when modifying offers" do
      3.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
      3.times { |i| create(:trade_card_want, trade:, card_name: "Want #{i}") }
      visit admin_event_trade_path(event, trade, wants_q: "Want")

      fill_in "offers_q", with: "Offer"
      find("#offers_search_submit").click

      expect(page).to have_current_path(%r{offers_q=Offer})
      expect(page).to have_current_path(%r{wants_q=Want})
    end

    it "restores all parameters after page reload" do
      3.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
      3.times { |i| create(:trade_card_want, trade:, card_name: "Want #{i}") }
      url = admin_event_trade_path(event, trade, offers_q: "Offer", wants_sort: "card_name_asc")
      visit url

      # Parameter should be in URL
      expect(page).to have_current_path(%r{offers_q=Offer})
      expect(page).to have_current_path(%r{wants_sort=card_name_asc})
      # Form fields should be populated
      expect(find("#offers_q").value).to eq("Offer")
      # Check that search result shows the filter is active
      expect(page).to have_text("Offer")
    end
  end

  describe "C10: Edit form toggle with sort" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(admin_user)
      resize_window_to(1280, 900)
    end

    it "toggles edit form and remains accessible after sort" do
      offer = create(:trade_card_offer, trade:, card_name: "Apple")
      create(:trade_card_offer, trade:, card_name: "Banana")
      visit admin_event_trade_path(event, trade)

      # Toggle open - find edit button in the row
      within("#trade_card_offer_#{offer.id}") do
        click_button "編集"
      end
      expect(find("#edit_form_trade_card_offer_#{offer.id}")).to be_visible

      # Sort
      click_link(id: "offers_sort_card_name")
      expect(page).to have_current_path(%r{offers_sort=card_name_asc})
      expect(page).to have_css("#offers_sort_card_name", text: "▲")
      expect(page).to have_css("#edit_form_trade_card_offer_#{offer.id}", visible: :hidden)

      # Toggle should still work
      within("#trade_card_offer_#{offer.id}") do
        click_button "編集"
      end
      expect(find("#edit_form_trade_card_offer_#{offer.id}")).to be_visible
    end
  end

  describe "C11: Mobile expand with sort" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(admin_user)
      resize_window_to(375, 800)
    end

    it "toggles expand and remains accessible after sort at mobile" do
      offer = create(:trade_card_offer, trade:, card_name: "Apple")
      create(:trade_card_offer, trade:, card_name: "Banana")
      visit admin_event_trade_path(event, trade)

      # Toggle open
      find("button[data-toggle-expand='trade_card_offer_#{offer.id}']").click
      expect(find("#expand_trade_card_offer_#{offer.id}")).to be_visible

      # Sort via dropdown
      select "数量 昇順", from: "offers_sort"
      expect(page).to have_current_path(%r{offers_sort=quantity_asc})
      expect(page).to have_css("#offers_sort_quantity", text: "▲", visible: :all)
      expect(page).to have_css("#expand_trade_card_offer_#{offer.id}", visible: :hidden)

      # Toggle should still work
      find("button[data-toggle-expand='trade_card_offer_#{offer.id}']").click
      expect(find("#expand_trade_card_offer_#{offer.id}")).to be_visible
    end
  end

  describe "C12: Button visibility by trade status" do
    let(:event) { create(:event) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let!(:pending_trade) { create(:trade, event:, user: user1, status: :pending) }
    let!(:completed_trade) { create(:trade, event:, user: user2, status: :completed) }

    before do
      sign_in(admin_user)
    end

    it "shows add/edit/delete buttons for pending trade" do
      create(:trade_card_offer, trade: pending_trade, card_name: "Apple")
      visit admin_event_trade_path(event, pending_trade)

      expect(page).to have_button("カード明細を追加", id: "add_offer_btn_admin")
      expect(page).to have_button("編集")
      expect(page).to have_button("削除")
    end

    it "hides add/edit/delete buttons for completed trade" do
      create(:trade_card_offer, trade: completed_trade, card_name: "Apple")
      visit admin_event_trade_path(event, completed_trade)

      expect(page).not_to have_button("カード明細を追加")
      expect(page).not_to have_button("編集")
      expect(page).not_to have_button("削除")
    end

    it "buttons remain hidden when searching completed trade" do
      create(:trade_card_offer, trade: completed_trade, card_name: "Apple")
      visit admin_event_trade_path(event, completed_trade, offers_q: "Apple")

      expect(page).not_to have_button("カード明細を追加")
    end
  end

  describe "C13: Soft-deleted items not shown" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(admin_user)
    end

    it "does not show discarded offers" do
      offer = create(:trade_card_offer, trade:, card_name: "Apple")
      create(:trade_card_offer, trade:, card_name: "Banana")
      offer.discard!

      visit admin_event_trade_path(event, trade)

      expect(page).not_to have_text("Apple")
      expect(page).to have_text("Banana")
    end

    it "does not include discarded items in count" do
      3.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
      @offers = trade.trade_card_offers
      @offers.first.discard!

      visit admin_event_trade_path(event, trade)

      expect(find("#offers_count")).to have_text("2件中")
    end
  end

  describe "C14: Completed trade viewing" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :completed) }

    before do
      sign_in(admin_user)
    end

    it "allows viewing completed trade" do
      create(:trade_card_offer, trade:, card_name: "Apple")
      visit admin_event_trade_path(event, trade)

      expect(page).to have_current_path(admin_event_trade_path(event, trade))
      expect(page).to have_text("Apple")
    end

    it "does not show add/edit/delete buttons for completed trade" do
      create(:trade_card_offer, trade:, card_name: "Apple")
      visit admin_event_trade_path(event, trade)

      expect(page).not_to have_button("カード明細を追加")
    end
  end

  describe "C15: Aggregates remain unchanged on search/paging" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(admin_user)
    end

    it "aggregates stay same across page changes" do
      5.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}", quantity: 2, amount: 100) }
      visit admin_event_trade_path(event, trade)

      initial_text = find("#trade_aggregates").text
      fill_in "offers_q", with: "Offer"
      click_button "検索", id: "offers_search_submit"

      expect(find("#trade_aggregates").text).to eq(initial_text)
    end
  end

  describe "C16: No JS error on sort then add" do
    let(:event) { create(:event) }
    let(:user) { create(:user) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }

    before do
      sign_in(admin_user)
    end

    it "add button works after sorting without JS error" do
      create(:trade_card_offer, trade:, card_name: "Apple")
      create(:trade_card_offer, trade:, card_name: "Banana")
      visit admin_event_trade_path(event, trade)

      find("#offers_sort_card_name").click
      expect(page).to have_current_path(%r{offers_sort=card_name_asc})
      expect(page).to have_css("#offers_sort_card_name", text: "▲")

      find("#add_offer_btn_admin").click

      expect(find("#new_trade_card_offer_admin")).to be_visible
      # No JS error check - if form appears, JS is working
    end
  end
end
