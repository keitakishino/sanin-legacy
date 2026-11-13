RSpec.describe ProxyOrderItemList do
  let(:calculator) { double("calculator") }
  let(:item1) { instance_double("ProxyOrderItem", id: 1, card_name: "Alpha") }
  let(:item2) { instance_double("ProxyOrderItem", id: 2, card_name: "Beta") }
  let(:item3) { instance_double("ProxyOrderItem", id: 3, card_name: "Gamma") }
  let(:items) { [ item1, item2, item3 ] }

  before do
    allow(calculator).to receive(:unit_price).with(item1).and_return(5)
    allow(calculator).to receive(:unit_price).with(item2).and_return(1)
    allow(calculator).to receive(:unit_price).with(item3).and_return(3)
  end

  describe "filtering" do
    it "filters by card name with case-insensitive partial match" do
      list = described_class.new(items, calculator:, query: "alpha")
      expect(list.items).to eq([ item1 ])
    end

    it "returns all items when query is blank" do
      list = described_class.new(items, calculator:, query: "")
      expect(list.items).to eq([ item1, item2, item3 ])
    end

    it "handles query with mixed case" do
      list = described_class.new(items, calculator:, query: "BETA")
      expect(list.items).to eq([ item2 ])
    end

    it "returns empty array when no items match" do
      list = described_class.new(items, calculator:, query: "nomatch")
      expect(list.items).to be_empty
    end

    it "strips whitespace from query" do
      list = described_class.new(items, calculator:, query: "  alpha  ")
      expect(list.items).to eq([ item1 ])
    end
  end

  describe "sorting" do
    it "sorts by registered order (id) by default" do
      list = described_class.new(items, calculator:)
      expect(list.items).to eq([ item1, item2, item3 ])
    end

    it "sorts by name ascending" do
      list = described_class.new(items, calculator:, sort: "name_asc")
      expect(list.items).to eq([ item1, item2, item3 ])
    end

    it "sorts by name descending" do
      list = described_class.new(items, calculator:, sort: "name_desc")
      expect(list.items).to eq([ item3, item2, item1 ])
    end

    it "sorts by unit price ascending" do
      list = described_class.new(items, calculator:, sort: "unit_price_asc")
      expect(list.items).to eq([ item2, item3, item1 ])
    end

    it "sorts by unit price descending" do
      list = described_class.new(items, calculator:, sort: "unit_price_desc")
      expect(list.items).to eq([ item1, item3, item2 ])
    end

    it "falls back to default sort when invalid sort is provided" do
      list = described_class.new(items, calculator:, sort: "invalid")
      expect(list.sort).to eq("registered")
      expect(list.items).to eq([ item1, item2, item3 ])
    end
  end

  describe "#filtering?" do
    it "returns true when query is present" do
      list = described_class.new(items, calculator:, query: "alpha")
      expect(list.filtering?).to be true
    end

    it "returns false when query is blank" do
      list = described_class.new(items, calculator:, query: "")
      expect(list.filtering?).to be false
    end

    it "returns false when query is nil" do
      list = described_class.new(items, calculator:, query: nil)
      expect(list.filtering?).to be false
    end
  end

  describe "#include?" do
    it "returns true when item id is in the list" do
      list = described_class.new(items, calculator:, query: "alpha")
      expect(list.include?(item1)).to be true
    end

    it "returns false when item id is not in the list" do
      list = described_class.new(items, calculator:, query: "alpha")
      expect(list.include?(item2)).to be false
    end
  end

  describe "#to_params" do
    it "returns empty hash when no filtering and default sort" do
      list = described_class.new(items, calculator:)
      expect(list.to_params).to eq({})
    end

    it "includes query when present" do
      list = described_class.new(items, calculator:, query: "alpha")
      expect(list.to_params).to include(q: "alpha")
    end

    it "includes sort when not default" do
      list = described_class.new(items, calculator:, sort: "name_asc")
      expect(list.to_params).to include(sort: "name_asc")
    end

    it "excludes sort when it is default" do
      list = described_class.new(items, calculator:, sort: "registered")
      expect(list.to_params).not_to include(:sort)
    end

    it "includes both q and sort when both are non-default" do
      list = described_class.new(items, calculator:, query: "beta", sort: "name_desc")
      expect(list.to_params).to eq(q: "beta", sort: "name_desc")
    end
  end

  describe "#counts" do
    it "returns total_count" do
      list = described_class.new(items, calculator:)
      expect(list.total_count).to eq(3)
    end

    it "returns visible_count when all items are visible" do
      list = described_class.new(items, calculator:)
      expect(list.visible_count).to eq(3)
    end

    it "returns visible_count when filtered" do
      list = described_class.new(items, calculator:, query: "alpha")
      expect(list.visible_count).to eq(1)
    end
  end
end
