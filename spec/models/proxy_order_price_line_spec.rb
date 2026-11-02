require "rails_helper"

RSpec.describe ProxyOrderPriceLine, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:proxy_order_item) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:unit_price_usd) }
    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_presence_of(:lost_quantity) }
    it { is_expected.to validate_numericality_of(:unit_price_usd).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:quantity).only_integer.is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:lost_quantity).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "duplicate pricing allowed (C4)" do
    let(:item) { create(:proxy_order_item) }

    it "allows creating multiple lines with the same unit_price_usd and quantity" do
      line1 = create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 3.00, quantity: 1)
      line2 = create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 3.00, quantity: 1)
      expect(item.proxy_order_price_lines.count).to eq(2)
      expect(line1.unit_price_usd).to eq(line2.unit_price_usd)
      expect(line1.quantity).to eq(line2.quantity)
    end
  end

  describe "lost_quantity_not_exceed_quantity validation (C7)" do
    let(:item) { create(:proxy_order_item) }

    it "allows lost_quantity <= quantity" do
      line = build(:proxy_order_price_line, proxy_order_item: item, quantity: 5, lost_quantity: 3)
      expect(line).to be_valid
    end

    it "allows lost_quantity == quantity" do
      line = build(:proxy_order_price_line, proxy_order_item: item, quantity: 5, lost_quantity: 5)
      expect(line).to be_valid
    end

    it "allows lost_quantity == 0" do
      line = build(:proxy_order_price_line, proxy_order_item: item, quantity: 5, lost_quantity: 0)
      expect(line).to be_valid
    end

    it "rejects lost_quantity > quantity" do
      line = build(:proxy_order_price_line, proxy_order_item: item, quantity: 5, lost_quantity: 6)
      expect(line).not_to be_valid
      expect(line.errors.of_kind?(:lost_quantity, :exceeds_quantity)).to be true
    end

    it "rejects negative lost_quantity" do
      line = build(:proxy_order_price_line, proxy_order_item: item, quantity: 5, lost_quantity: -1)
      expect(line).not_to be_valid
    end
  end

  describe "quantity validation (C7)" do
    let(:item) { create(:proxy_order_item) }

    it "rejects quantity == 0" do
      line = build(:proxy_order_price_line, proxy_order_item: item, quantity: 0)
      expect(line).not_to be_valid
    end

    it "rejects negative quantity" do
      line = build(:proxy_order_price_line, proxy_order_item: item, quantity: -1)
      expect(line).not_to be_valid
    end

    it "allows positive quantity" do
      line = build(:proxy_order_price_line, proxy_order_item: item, quantity: 1)
      expect(line).to be_valid
    end
  end

  describe "unit_price_usd validation" do
    let(:item) { create(:proxy_order_item) }

    it "allows unit_price_usd == 0" do
      line = build(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 0)
      expect(line).to be_valid
    end

    it "allows positive unit_price_usd" do
      line = build(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 3.50)
      expect(line).to be_valid
    end

    it "rejects negative unit_price_usd" do
      line = build(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: -1.0)
      expect(line).not_to be_valid
    end
  end

  describe "logical deletion" do
    let(:item) { create(:proxy_order_item) }
    let(:price_line) { create(:proxy_order_price_line, proxy_order_item: item) }

    it "excludes discarded records by default scope" do
      price_line.update(discarded_at: Time.current)
      expect(ProxyOrderPriceLine.find_by(id: price_line.id)).to be_nil
    end

    it "includes discarded records with .with_discarded" do
      price_line.update(discarded_at: Time.current)
      expect(ProxyOrderPriceLine.with_discarded.find(price_line.id)).to eq(price_line)
    end

    it "returns only discarded records with .only_discarded" do
      other_line = create(:proxy_order_price_line, proxy_order_item: item)
      price_line.update(discarded_at: Time.current)
      expect(ProxyOrderPriceLine.only_discarded).to contain_exactly(price_line)
      expect(ProxyOrderPriceLine.only_discarded).not_to include(other_line)
    end
  end
end
