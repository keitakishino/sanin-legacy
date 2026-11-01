require "rails_helper"

RSpec.describe ProxyOrderItem, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:proxy_order) }
    it { is_expected.to belong_to(:expansion).optional }
    it { is_expected.to have_many(:proxy_order_price_lines).dependent(:destroy) }
    it { is_expected.to have_many(:proxy_order_allocations).dependent(:destroy) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:foil).with_values(foil: 0, non_foil: 1, special: 2) }
    it { is_expected.to define_enum_for(:frame).with_values(normal: 0, extended: 1, borderless: 2, showcase: 3, retro: 4) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:card_name) }
    it { is_expected.to validate_presence_of(:foil) }
    it { is_expected.to validate_presence_of(:frame) }
  end

  describe "no_duplicate_card_entry validation" do
    let(:proxy_order) { create(:proxy_order) }
    let(:expansion) { create(:expansion) }

    it "allows the same card in different orders" do
      item1 = create(:proxy_order_item, proxy_order:, card_name: "Test Card", expansion:, foil: :foil, frame: :normal)
      other_order = create(:proxy_order)
      item2 = build(:proxy_order_item, proxy_order: other_order, card_name: "Test Card", expansion:, foil: :foil, frame: :normal)
      expect(item2).to be_valid
    end

    it "rejects duplicate with same card_name, expansion, foil, and frame" do
      create(:proxy_order_item, proxy_order:, card_name: "Test Card", expansion:, foil: :foil, frame: :normal)
      duplicate = build(:proxy_order_item, proxy_order:, card_name: "Test Card", expansion:, foil: :foil, frame: :normal)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.of_kind?(:base, :duplicate_card_entry)).to be true
    end

    it "allows when card_name differs" do
      create(:proxy_order_item, proxy_order:, card_name: "Card A", expansion:, foil: :foil, frame: :normal)
      item = build(:proxy_order_item, proxy_order:, card_name: "Card B", expansion:, foil: :foil, frame: :normal)
      expect(item).to be_valid
    end

    it "allows when expansion differs" do
      create(:proxy_order_item, proxy_order:, card_name: "Test Card", expansion:, foil: :foil, frame: :normal)
      other_expansion = create(:expansion)
      item = build(:proxy_order_item, proxy_order:, card_name: "Test Card", expansion: other_expansion, foil: :foil, frame: :normal)
      expect(item).to be_valid
    end

    it "allows when foil differs" do
      create(:proxy_order_item, proxy_order:, card_name: "Test Card", expansion:, foil: :foil, frame: :normal)
      item = build(:proxy_order_item, proxy_order:, card_name: "Test Card", expansion:, foil: :non_foil, frame: :normal)
      expect(item).to be_valid
    end

    it "allows when frame differs" do
      create(:proxy_order_item, proxy_order:, card_name: "Test Card", expansion:, foil: :foil, frame: :normal)
      item = build(:proxy_order_item, proxy_order:, card_name: "Test Card", expansion:, foil: :foil, frame: :extended)
      expect(item).to be_valid
    end

    it "allows when updating the same item (self-update)" do
      item = create(:proxy_order_item, proxy_order:, card_name: "Test Card", expansion:, foil: :foil, frame: :normal)
      item.card_name = "Test Card"
      expect(item).to be_valid
    end

    it "excludes discarded items from duplicate check" do
      create(:proxy_order_item, proxy_order:, card_name: "Test Card", expansion:, foil: :foil, frame: :normal, discarded_at: Time.current)
      item = build(:proxy_order_item, proxy_order:, card_name: "Test Card", expansion:, foil: :foil, frame: :normal)
      expect(item).to be_valid
    end
  end

  describe "logical deletion" do
    let(:proxy_order) { create(:proxy_order) }

    it "excludes discarded items by default" do
      item = create(:proxy_order_item, proxy_order:)
      item.update(discarded_at: Time.current)
      expect(ProxyOrderItem.find_by(id: item.id)).to be_nil
    end

    it "includes discarded items with .with_discarded" do
      item = create(:proxy_order_item, proxy_order:)
      item.update(discarded_at: Time.current)
      expect(ProxyOrderItem.with_discarded.find(item.id)).to eq(item)
    end

    it "responds to discarded?" do
      item = create(:proxy_order_item, proxy_order:)
      expect(item.discarded?).to be false
      item.update(discarded_at: Time.current)
      expect(item.discarded?).to be true
    end
  end
end
