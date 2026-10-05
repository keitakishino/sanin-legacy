require 'rails_helper'

RSpec.describe CardDetailList do
  let!(:trade) { create(:trade, status: :pending) }
  let!(:expansion) { create(:expansion) }

  describe "with TradeCardOffer" do
    let(:offers) { trade.trade_card_offers }
    let(:scope) { offers.includes(:expansion) }

    describe "search_card_name scope" do
      before do
        create(:trade_card_offer, trade:, card_name: "Lightning Bolt")
        create(:trade_card_offer, trade:, card_name: "Dark Ritual")
        create(:trade_card_offer, trade:, card_name: "Island")
      end

      it "returns all records when query is empty" do
        list = CardDetailList.new(scope, prefix: "offers", params: {})
        expect(list.records.count).to eq 3
      end

      it "returns matching records by partial match" do
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_q" => "Bolt" })
        expect(list.records.map(&:card_name)).to eq([ "Lightning Bolt" ])
      end

      it "is case insensitive" do
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_q" => "lightning bolt" })
        expect(list.records.map(&:card_name)).to eq([ "Lightning Bolt" ])
      end

      it "escapes SQL wildcard characters" do
        create(:trade_card_offer, trade:, card_name: "100% Card")
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_q" => "100%" })
        expect(list.records.map(&:card_name)).to eq([ "100% Card" ])
      end

      it "does not match unescaped wildcard" do
        create(:trade_card_offer, trade:, card_name: "1000 Card")
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_q" => "100%" })
        expect(list.records.map(&:card_name)).to_not include("1000 Card")
      end

      it "escapes underscore wildcard" do
        create(:trade_card_offer, trade:, card_name: "a_b")
        create(:trade_card_offer, trade:, card_name: "axb")
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_q" => "a_b" })
        expect(list.records.map(&:card_name)).to eq([ "a_b" ])
      end
    end

    describe "sorted_by scope" do
      before do
        create(:trade_card_offer, trade:, card_name: "Zebra", quantity: 1, amount: 100)
        create(:trade_card_offer, trade:, card_name: "Apple", quantity: 5, amount: 50)
        create(:trade_card_offer, trade:, card_name: "Middle", quantity: 3, amount: nil)
      end

      it "sorts by card_name ascending" do
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_sort" => "card_name_asc" })
        names = list.records.map(&:card_name)
        expect(names).to eq([ "Apple", "Middle", "Zebra" ])
      end

      it "sorts by card_name descending" do
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_sort" => "card_name_desc" })
        names = list.records.map(&:card_name)
        expect(names).to eq([ "Zebra", "Middle", "Apple" ])
      end

      it "sorts by quantity ascending" do
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_sort" => "quantity_asc" })
        quantities = list.records.map(&:quantity)
        expect(quantities).to eq([ 1, 3, 5 ])
      end

      it "sorts by quantity descending" do
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_sort" => "quantity_desc" })
        quantities = list.records.map(&:quantity)
        expect(quantities).to eq([ 5, 3, 1 ])
      end

      it "sorts by amount ascending with nulls last" do
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_sort" => "amount_asc" })
        amounts = list.records.map(&:amount)
        expect(amounts).to eq([ 50, 100, nil ])
      end

      it "sorts by amount descending with nulls last" do
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_sort" => "amount_desc" })
        amounts = list.records.map(&:amount)
        expect(amounts).to eq([ 100, 50, nil ])
      end

      it "uses id ascending as secondary sort" do
        offer1 = create(:trade_card_offer, trade:, card_name: "Same", quantity: 5, amount: 100)
        offer2 = create(:trade_card_offer, trade:, card_name: "Same", quantity: 5, amount: 100)
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_sort" => "quantity_asc" })
        ids = list.records.where(card_name: "Same").map(&:id)
        expect(ids).to eq([ offer1.id, offer2.id ])
      end

      it "handles invalid sort values as nil sort" do
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_sort" => "invalid" })
        expect(list.sort).to be_nil
      end

      it "defaults to id ascending when sort is nil" do
        create(:trade_card_offer, trade:, card_name: "Z", quantity: 9)
        create(:trade_card_offer, trade:, card_name: "A", quantity: 1)
        list = CardDetailList.new(scope, prefix: "offers", params: {})
        ids = list.records.map(&:id)
        expect(ids).to eq(ids.sort)
      end
    end

    describe "pagination" do
      before do
        20.times { |i| create(:trade_card_offer, trade:, card_name: "Card #{i}") }
      end

      it "returns 20 records per page" do
        list = CardDetailList.new(scope, prefix: "offers", params: {})
        expect(list.records.count).to eq 20
        expect(list.records.total_pages).to eq 1
      end

      it "returns next page when page parameter is set" do
        create(:trade_card_offer, trade:, card_name: "Card 21")
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_page" => "2" })
        expect(list.records.count).to eq 1
        expect(list.records.current_page).to eq 2
      end

      it "handles out of range page by returning last page" do
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_page" => "99" })
        expect(list.records.current_page).to eq 1
      end

      it "returns correct from and to" do
        create(:trade_card_offer, trade:, card_name: "Card 21")
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_page" => "2" })
        expect(list.from).to eq 21
        expect(list.to).to eq 21
      end

      it "returns 0 for from when no records" do
        scope_empty = trade.trade_card_offers.where(card_name: "Nonexistent").includes(:expansion)
        list = CardDetailList.new(scope_empty, prefix: "offers", params: {})
        expect(list.from).to eq 0
        expect(list.to).to eq 0
      end
    end

    describe "total_count" do
      it "returns count after filtering" do
        10.times { |i| create(:trade_card_offer, trade:, card_name: "Apple #{i}") }
        5.times { |i| create(:trade_card_offer, trade:, card_name: "Banana #{i}") }
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_q" => "Apple" })
        expect(list.total_count).to eq 10
      end

      it "respects discarded records" do
        offer = create(:trade_card_offer, trade:, card_name: "Test")
        offer.discard!
        list = CardDetailList.new(scope, prefix: "offers", params: {})
        expect(list.total_count).to eq 0
      end
    end

    describe "sort_indicator" do
      it "returns ▲ for ascending sort" do
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_sort" => "card_name_asc" })
        expect(list.sort_indicator("card_name")).to eq "▲"
      end

      it "returns ▼ for descending sort" do
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_sort" => "card_name_desc" })
        expect(list.sort_indicator("card_name")).to eq "▼"
      end

      it "returns ↕ for no sort" do
        list = CardDetailList.new(scope, prefix: "offers", params: {})
        expect(list.sort_indicator("card_name")).to eq "↕"
      end
    end

    describe "next_sort" do
      it "cycles through asc -> desc -> nil -> asc" do
        list1 = CardDetailList.new(scope, prefix: "offers", params: { "offers_sort" => "card_name_asc" })
        expect(list1.next_sort("card_name")).to eq "card_name_desc"

        list2 = CardDetailList.new(scope, prefix: "offers", params: { "offers_sort" => "card_name_desc" })
        expect(list2.next_sort("card_name")).to be_nil

        list3 = CardDetailList.new(scope, prefix: "offers", params: {})
        expect(list3.next_sort("card_name")).to eq "card_name_asc"
      end
    end

    describe "searching?" do
      it "returns true when query is present" do
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_q" => "test" })
        expect(list.searching?).to be true
      end

      it "returns false when query is empty" do
        list = CardDetailList.new(scope, prefix: "offers", params: {})
        expect(list.searching?).to be false
      end
    end

    describe "state isolation between lists" do
      before do
        5.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i}") }
        5.times { |i| create(:trade_card_want, trade:, card_name: "Want #{i}") }
      end

      it "filters independently" do
        params = { "offers_q" => "Offer 1", "wants_q" => "Want 2" }
        offers_list = CardDetailList.new(trade.trade_card_offers.includes(:expansion), prefix: "offers", params:)
        wants_list = CardDetailList.new(trade.trade_card_wants.includes(:expansion), prefix: "wants", params:)
        expect(offers_list.records.map(&:card_name)).to eq([ "Offer 1" ])
        expect(wants_list.records.map(&:card_name)).to eq([ "Want 2" ])
      end

      it "sorts independently" do
        params = { "offers_sort" => "card_name_desc", "wants_sort" => "card_name_asc" }
        offers_list = CardDetailList.new(trade.trade_card_offers.includes(:expansion), prefix: "offers", params:)
        wants_list = CardDetailList.new(trade.trade_card_wants.includes(:expansion), prefix: "wants", params:)
        expect(offers_list.records.first.card_name).to eq("Offer 4")
        expect(wants_list.records.first.card_name).to eq("Want 0")
      end

      it "pages independently" do
        20.times { |i| create(:trade_card_offer, trade:, card_name: "Offer #{i + 100}") }
        20.times { |i| create(:trade_card_want, trade:, card_name: "Want #{i + 100}") }
        params = { "offers_page" => "2", "wants_page" => "1" }
        offers_list = CardDetailList.new(trade.trade_card_offers.includes(:expansion), prefix: "offers", params:)
        wants_list = CardDetailList.new(trade.trade_card_wants.includes(:expansion), prefix: "wants", params:)
        expect(offers_list.records.current_page).to eq 2
        expect(wants_list.records.current_page).to eq 1
      end
    end
  end

  describe "with TradeCardWant" do
    let(:wants) { trade.trade_card_wants }
    let(:scope) { wants.includes(:expansion) }

    describe "search_card_name scope" do
      before do
        create(:trade_card_want, trade:, card_name: "Counterspell")
        create(:trade_card_want, trade:, card_name: "Force of Will")
        create(:trade_card_want, trade:, card_name: "Swan Song")
      end

      it "returns all records when query is empty" do
        list = CardDetailList.new(scope, prefix: "wants", params: {})
        expect(list.records.count).to eq 3
      end

      it "returns matching records by partial match" do
        list = CardDetailList.new(scope, prefix: "wants", params: { "wants_q" => "Force" })
        expect(list.records.map(&:card_name)).to eq([ "Force of Will" ])
      end

      it "is case insensitive" do
        list = CardDetailList.new(scope, prefix: "wants", params: { "wants_q" => "counterspell" })
        expect(list.records.map(&:card_name)).to eq([ "Counterspell" ])
      end
    end

    describe "sorted_by scope" do
      before do
        create(:trade_card_want, trade:, card_name: "Zebra", quantity: 2, amount: 200)
        create(:trade_card_want, trade:, card_name: "Apex", quantity: 4, amount: nil)
        create(:trade_card_want, trade:, card_name: "Beta", quantity: 1, amount: 300)
      end

      it "sorts by card_name ascending" do
        list = CardDetailList.new(scope, prefix: "wants", params: { "wants_sort" => "card_name_asc" })
        names = list.records.map(&:card_name)
        expect(names).to eq([ "Apex", "Beta", "Zebra" ])
      end

      it "sorts by amount with nulls last" do
        list = CardDetailList.new(scope, prefix: "wants", params: { "wants_sort" => "amount_asc" })
        amounts = list.records.map(&:amount)
        expect(amounts).to eq([ 200, 300, nil ])
      end
    end

    describe "total_count respects discarded records" do
      it "excludes discarded wants" do
        want = create(:trade_card_want, trade:, card_name: "Test")
        want.discard!
        list = CardDetailList.new(scope, prefix: "wants", params: {})
        expect(list.total_count).to eq 0
      end
    end
  end

  describe ".state_keys" do
    it "returns the correct parameter keys" do
      keys = CardDetailList.state_keys("offers")
      expect(keys).to eq([ "offers_q", "offers_sort", "offers_page" ])
    end

    it "works with different prefixes" do
      keys = CardDetailList.state_keys("wants")
      expect(keys).to eq([ "wants_q", "wants_sort", "wants_page" ])
    end
  end

  describe "#page_of with TradeCardOffer" do
    let(:offers) { trade.trade_card_offers }
    let(:scope) { offers.includes(:expansion) }

    context "with 21 records" do
      before do
        21.times { |i| create(:trade_card_offer, trade:, card_name: "Card #{format('%02d', i)}") }
      end

      it "returns page 1 for the first 20 records" do
        record = offers.order(id: :asc).first
        list = CardDetailList.new(scope, prefix: "offers", params: {})
        expect(list.page_of(record)).to eq 1
      end

      it "returns page 2 for the 21st record without sort" do
        record = offers.order(id: :asc).last
        list = CardDetailList.new(scope, prefix: "offers", params: {})
        expect(list.page_of(record)).to eq 2
      end

      it "returns page 1 for the first record when sorted by card_name ascending" do
        record = offers.find_by(card_name: "Card 00")
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_sort" => "card_name_asc" })
        expect(list.page_of(record)).to eq 1
      end

      it "returns nil for records that don't match the search query" do
        record = offers.find_by(card_name: "Card 00")
        list = CardDetailList.new(scope, prefix: "offers", params: { "offers_q" => "Lotus" })
        expect(list.page_of(record)).to be_nil
      end
    end
  end

  describe "#page_of with TradeCardWant" do
    let(:wants) { trade.trade_card_wants }
    let(:scope) { wants.includes(:expansion) }

    context "with 21 records" do
      before do
        21.times { |i| create(:trade_card_want, trade:, card_name: "Card #{format('%02d', i)}") }
      end

      it "returns page 2 for the 21st record" do
        record = wants.order(id: :asc).last
        list = CardDetailList.new(scope, prefix: "wants", params: {})
        expect(list.page_of(record)).to eq 2
      end

      it "returns nil for records that don't match the search query" do
        record = wants.find_by(card_name: "Card 00")
        list = CardDetailList.new(scope, prefix: "wants", params: { "wants_q" => "Nonexistent" })
        expect(list.page_of(record)).to be_nil
      end
    end
  end
end
