require "rails_helper"

RSpec.describe "Admin Proxy Order Item Search and Sort", type: :system do
  include ActionView::RecordIdentifier

  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
  let(:proxy_order) { create(:proxy_order, event:, status: :ordered) }

  before do
    sign_in admin
    resize_window_to(1280, 900)
    proxy_order  # Ensure proxy_order is created before tests
  end

  describe "[C1] sorting by name A→Z" do
    it "sorts card names in ascending alphabetical order" do
      create(:proxy_order_item, proxy_order:, card_name: "Gamma")
      create(:proxy_order_item, proxy_order:, card_name: "alpha")
      create(:proxy_order_item, proxy_order:, card_name: "Beta")

      visit admin_event_proxy_order_path(event)
      select "名称（A→Z）", from: "proxy_order_item_sort"
      expect(page).to have_current_path(%r{sort=name_asc})

      card_names = all("[data-role=card-name]").map(&:text)
      expect(card_names).to eq([ "alpha", "Beta", "Gamma" ])
    end
  end

  describe "[C2] sorting by name Z→A" do
    it "sorts card names in descending alphabetical order" do
      create(:proxy_order_item, proxy_order:, card_name: "Gamma")
      create(:proxy_order_item, proxy_order:, card_name: "alpha")
      create(:proxy_order_item, proxy_order:, card_name: "Beta")

      visit admin_event_proxy_order_path(event)
      select "名称（Z→A）", from: "proxy_order_item_sort"
      expect(page).to have_current_path(%r{sort=name_desc})

      card_names = all("[data-role=card-name]").map(&:text)
      expect(card_names).to eq([ "Gamma", "Beta", "alpha" ])
    end
  end

  describe "[C3] sorting by unit price" do
    it "sorts by unit price ascending (low to high)" do
      item_a = create(:proxy_order_item, proxy_order:, card_name: "Card A")
      create(:proxy_order_price_line, proxy_order_item: item_a, unit_price_usd: 5.0, quantity: 1)

      item_b = create(:proxy_order_item, proxy_order:, card_name: "Card B")
      create(:proxy_order_price_line, proxy_order_item: item_b, unit_price_usd: 1.0, quantity: 1)

      item_c = create(:proxy_order_item, proxy_order:, card_name: "Card C")
      create(:proxy_order_price_line, proxy_order_item: item_c, unit_price_usd: 3.0, quantity: 1)

      visit admin_event_proxy_order_path(event)
      select "一枚あたり金額（安い順）", from: "proxy_order_item_sort"
      expect(page).to have_current_path(%r{sort=unit_price_asc})

      card_names = all("[data-role=card-name]").map(&:text)
      expect(card_names).to eq([ "Card B", "Card C", "Card A" ])
    end

    it "sorts by unit price descending (high to low)" do
      item_a = create(:proxy_order_item, proxy_order:, card_name: "Card A")
      create(:proxy_order_price_line, proxy_order_item: item_a, unit_price_usd: 5.0, quantity: 1)

      item_b = create(:proxy_order_item, proxy_order:, card_name: "Card B")
      create(:proxy_order_price_line, proxy_order_item: item_b, unit_price_usd: 1.0, quantity: 1)

      item_c = create(:proxy_order_item, proxy_order:, card_name: "Card C")
      create(:proxy_order_price_line, proxy_order_item: item_c, unit_price_usd: 3.0, quantity: 1)

      visit admin_event_proxy_order_path(event)
      select "一枚あたり金額（高い順）", from: "proxy_order_item_sort"
      expect(page).to have_current_path(%r{sort=unit_price_desc})

      card_names = all("[data-role=card-name]").map(&:text)
      expect(card_names).to eq([ "Card A", "Card C", "Card B" ])
    end
  end

  describe "[C4] default sort order is registered" do
    it "shows cards in order of registration by default" do
      create(:proxy_order_item, proxy_order:, card_name: "Gamma")
      create(:proxy_order_item, proxy_order:, card_name: "Alpha")
      create(:proxy_order_item, proxy_order:, card_name: "Beta")

      visit admin_event_proxy_order_path(event)

      # Select should show "登録順" as default
      expect(find("#proxy_order_item_sort").value).to eq("registered")

      card_names = all("[data-role=card-name]").map(&:text)
      expect(card_names).to eq([ "Gamma", "Alpha", "Beta" ])
    end
  end

  describe "[C5] sort persists and updates immediately after editing" do
    it "keeps sort parameter in URL and reorders when card name changes" do
      item1 = create(:proxy_order_item, proxy_order:, card_name: "Alpha")
      create(:proxy_order_item, proxy_order:, card_name: "Mid")
      create(:proxy_order_item, proxy_order:, card_name: "Zulu")

      visit admin_event_proxy_order_path(event)
      select "名称（A→Z）", from: "proxy_order_item_sort"
      expect(page).to have_current_path(%r{sort=name_asc})

      # Edit the first card
      find("##{dom_id(item1)} summary").click
      expect(page).to have_selector("##{dom_id(item1)}[open]")

      find("##{dom_id(item1, :card_name_input)}").fill_in(with: "Zzz")
      find("##{dom_id(item1, :card_name_input)}").send_keys(:tab)

      expect(page).to have_text("カードを更新しました")
      expect(page).to have_current_path(%r{sort=name_asc})

      card_names = all("[data-role=card-name]").map(&:text)
      expect(card_names).to eq([ "Mid", "Zulu", "Zzz" ])
    end
  end

  describe "[C6] open state and focus are preserved when items reorder" do
    it "keeps edited card open with focus when it moves" do
      item1 = create(:proxy_order_item, proxy_order:, card_name: "Alpha")
      create(:proxy_order_item, proxy_order:, card_name: "Mid")
      create(:proxy_order_item, proxy_order:, card_name: "Zulu")

      visit admin_event_proxy_order_path(event)
      select "名称（A→Z）", from: "proxy_order_item_sort"

      # Open and edit
      find("##{dom_id(item1)} summary").click
      find("##{dom_id(item1, :card_name_input)}").fill_in(with: "Zzz")
      find("##{dom_id(item1, :card_name_input)}").send_keys(:tab)

      expect(page).to have_text("カードを更新しました")

      # Check that the item is still open
      expect(page).to have_selector("##{dom_id(item1)}[open]")

      # Check that focus is in the expansion input
      focused_element = evaluate_script("document.activeElement.id")
      expect(focused_element).to eq(dom_id(item1, :expansion_input))
    end
  end

  describe "[C7] page does not fully reload" do
    it "uses Turbo for updates" do
      create(:proxy_order_item, proxy_order:, card_name: "Test Card")

      visit admin_event_proxy_order_path(event)
      execute_script("window.__marker = 1")

      select "名称（A→Z）", from: "proxy_order_item_sort"
      expect(page).to have_current_path(%r{sort=name_asc})

      # Page should not reload
      expect(evaluate_script("window.__marker")).to eq(1)
    end
  end

  describe "[C8] search and sort work together" do
    it "filters and sorts simultaneously" do
      create(:proxy_order_item, proxy_order:, card_name: "Card Alpha")
      create(:proxy_order_item, proxy_order:, card_name: "Other Beta")
      create(:proxy_order_item, proxy_order:, card_name: "Card Zulu")

      visit admin_event_proxy_order_path(event)

      find("#proxy_order_item_search").fill_in(with: "card")
      find("#proxy_order_item_search").send_keys(:enter)
      expect(page).to have_current_path(%r{q=card})

      select "名称（Z→A）", from: "proxy_order_item_sort"
      expect(page).to have_current_path(%r{q=card.*sort=name_desc})

      card_names = all("[data-role=card-name]").map(&:text)
      expect(card_names).to eq([ "Card Zulu", "Card Alpha" ])
    end
  end

  describe "[C9] search filters by card name case-insensitively" do
    it "finds cards matching search term ignoring case" do
      create(:proxy_order_item, proxy_order:, card_name: "TestCardBeta")
      create(:proxy_order_item, proxy_order:, card_name: "OtherCard")
      create(:proxy_order_item, proxy_order:, card_name: "AnotherBeta")

      visit admin_event_proxy_order_path(event)

      find("#proxy_order_item_search").fill_in(with: "BETA")
      find("#proxy_order_item_search").send_keys(:enter)

      expect(page).to have_current_path(%r{q=BETA})

      card_names = all("[data-role=card-name]").map(&:text)
      expect(card_names).to eq([ "TestCardBeta", "AnotherBeta" ])
    end
  end

  describe "[C10] item count display" do
    it "shows filtered and total count when searching" do
      3.times { |i| create(:proxy_order_item, proxy_order:, card_name: "Test Card #{i}") }
      create(:proxy_order_item, proxy_order:, card_name: "Other")

      visit admin_event_proxy_order_path(event)

      # Check count with no filter
      expect(find("#proxy_order_item_count")).to have_text("全 4 件")

      # Search for items
      find("#proxy_order_item_search").fill_in(with: "Test")
      find("#proxy_order_item_search").send_keys(:enter)

      expect(find("#proxy_order_item_count")).to have_text("3 件 / 全 4 件")
    end
  end

  describe "[C11] zero search results" do
    it "shows zero results message and clear button" do
      create(:proxy_order_item, proxy_order:, card_name: "Alpha")

      visit admin_event_proxy_order_path(event)

      find("#proxy_order_item_search").fill_in(with: "nomatch")
      find("#proxy_order_item_search").send_keys(:enter)

      expect(page).to have_text("『nomatch』に一致するカードはありません")
      expect(page).to have_link("検索をクリア")

      click_link "検索をクリア"
      expect(page).to have_current_path(admin_event_proxy_order_path(event))
      expect(find("#proxy_order_item_count")).to have_text("全 1 件")
    end
  end

  describe "[C12] clear search with × button" do
    it "clears search using the × icon" do
      create(:proxy_order_item, proxy_order:, card_name: "Test Card")
      create(:proxy_order_item, proxy_order:, card_name: "Other Card")

      visit admin_event_proxy_order_path(event)

      find("#proxy_order_item_search").fill_in(with: "Test")
      find("#proxy_order_item_search").send_keys(:enter)

      expect(page).to have_current_path(%r{q=Test})
      expect(find("#proxy_order_item_count")).to have_text("1 件")

      click_link "×"

      expect(page).to have_current_path(admin_event_proxy_order_path(event))
      expect(find("#proxy_order_item_count")).to have_text("全 2 件")
      expect(find("#proxy_order_item_search").value).to be_empty
    end
  end

  describe "[C13] search persists after editing" do
    it "keeps search query and reorders when matching content is edited" do
      item1 = create(:proxy_order_item, proxy_order:, card_name: "Card Alpha")
      create(:proxy_order_item, proxy_order:, card_name: "Other Card")

      visit admin_event_proxy_order_path(event)

      find("#proxy_order_item_search").fill_in(with: "card")
      find("#proxy_order_item_search").send_keys(:enter)

      expect(page).to have_current_path(%r{q=card})
      expect(find("#proxy_order_item_count")).to have_text("2 件")

      # Edit the card name
      find("##{dom_id(item1)} summary").click
      find("##{dom_id(item1, :card_name_input)}").fill_in(with: "Card Alpha2")
      find("##{dom_id(item1, :card_name_input)}").send_keys(:tab)

      expect(page).to have_text("カードを更新しました")
      expect(page).to have_current_path(%r{q=card})
      expect(find("#proxy_order_item_count")).to have_text("2 件")
    end
  end

  describe "[C14] item removed from results when no longer matching" do
    it "removes item from list and shows toast when it no longer matches search" do
      item1 = create(:proxy_order_item, proxy_order:, card_name: "Alpha Card")
      create(:proxy_order_item, proxy_order:, card_name: "Other Card")

      visit admin_event_proxy_order_path(event)

      find("#proxy_order_item_search").fill_in(with: "alpha")
      find("#proxy_order_item_search").send_keys(:enter)

      expect(find("#proxy_order_item_count")).to have_text("1 件 / 全 2 件")

      # Edit to no longer match
      find("##{dom_id(item1)} summary").click
      find("##{dom_id(item1, :card_name_input)}").fill_in(with: "Gamma")
      find("##{dom_id(item1, :card_name_input)}").send_keys(:tab)

      expect(page).to have_text("「Gamma」は検索語「alpha」に一致しないため、一覧から外れました")
      expect(find("#proxy_order_item_count")).to have_text("0 件 / 全 2 件")
    end
  end
end
