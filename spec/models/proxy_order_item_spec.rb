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

    it "rejects duplicate when card_name differs only in letter case" do
      create(:proxy_order_item, proxy_order:, card_name: "Ponder", expansion:, foil: :foil, frame: :normal)
      duplicate = build(:proxy_order_item, proxy_order:, card_name: "ponder", expansion:, foil: :foil, frame: :normal)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.of_kind?(:base, :duplicate_card_entry)).to be true
      expect { duplicate.save }.not_to change { proxy_order.proxy_order_items.count }

      uppercase_variant = build(:proxy_order_item, proxy_order:, card_name: "PONDER", expansion:, foil: :foil, frame: :normal)
      expect(uppercase_variant).not_to be_valid
      expect(uppercase_variant.errors.of_kind?(:base, :duplicate_card_entry)).to be true
    end

    it "rejects updating an item to a case-variant of another item's card_name" do
      create(:proxy_order_item, proxy_order:, card_name: "Ponder", expansion:, foil: :foil, frame: :normal)
      brainstorm_item = create(:proxy_order_item, proxy_order:, card_name: "Brainstorm", expansion:, foil: :foil, frame: :normal)

      brainstorm_item.card_name = "ponder"
      expect(brainstorm_item).not_to be_valid
      expect(brainstorm_item.errors.of_kind?(:base, :duplicate_card_entry)).to be true
    end

    it "keeps the card_name as entered" do
      item = create(:proxy_order_item, proxy_order:, card_name: "Ponder", expansion:, foil: :foil, frame: :normal)
      expect(item.card_name).to eq("Ponder")

      duplicate = build(:proxy_order_item, proxy_order:, card_name: "ponder", expansion:, foil: :foil, frame: :normal)
      expect(duplicate.save).to be false

      item.reload
      expect(item.card_name).to eq("Ponder")

      other_card = create(:proxy_order_item, proxy_order:, card_name: "Jace, the Mind Sculptor", expansion:, foil: :foil, frame: :extended)
      other_card.reload
      expect(other_card.card_name).to eq("Jace, the Mind Sculptor")
    end

    it "allows a case-variant card_name when expansion / foil / frame differ" do
      create(:proxy_order_item, proxy_order:, card_name: "Ponder", expansion:, foil: :foil, frame: :normal)

      different_expansion = create(:expansion)
      item1 = build(:proxy_order_item, proxy_order:, card_name: "ponder", expansion: different_expansion, foil: :foil, frame: :normal)
      expect(item1).to be_valid

      item2 = build(:proxy_order_item, proxy_order:, card_name: "ponder", expansion:, foil: :non_foil, frame: :normal)
      expect(item2).to be_valid

      item3 = build(:proxy_order_item, proxy_order:, card_name: "ponder", expansion:, foil: :foil, frame: :extended)
      expect(item3).to be_valid
    end

    it "excludes discarded items from case-insensitive duplicate check" do
      create(:proxy_order_item, proxy_order:, card_name: "Ponder", expansion:, foil: :foil, frame: :normal, discarded_at: Time.current)
      item = build(:proxy_order_item, proxy_order:, card_name: "ponder", expansion:, foil: :foil, frame: :normal)
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

  describe "quantity aggregation methods" do
    let(:proxy_order) { create(:proxy_order) }
    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }

    describe "#ordered_quantity" do
      it "sums quantities from all price lines" do
        create(:proxy_order_price_line, proxy_order_item: item, quantity: 2)
        create(:proxy_order_price_line, proxy_order_item: item, quantity: 3)
        expect(item.ordered_quantity).to eq(5)
      end

      it "returns 0 when no price lines exist" do
        expect(item.ordered_quantity).to eq(0)
      end
    end

    describe "#allocated_quantity" do
      it "sums quantities from all allocations" do
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 2)
        other_participant = create(:proxy_order_participant, proxy_order:)
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: other_participant, quantity: 3)
        expect(item.allocated_quantity).to eq(5)
      end

      it "returns 0 when no allocations exist" do
        expect(item.allocated_quantity).to eq(0)
      end
    end

    describe "#quantity_mismatch?" do
      it "returns false when ordered and allocated quantities match" do
        create(:proxy_order_price_line, proxy_order_item: item, quantity: 5)
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 5)
        expect(item.quantity_mismatch?).to be false
      end

      it "returns true when ordered and allocated quantities differ" do
        create(:proxy_order_price_line, proxy_order_item: item, quantity: 5)
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 4)
        expect(item.quantity_mismatch?).to be true
      end

      it "returns false when both are zero" do
        expect(item.quantity_mismatch?).to be false
      end
    end

    describe "#remaining_allocation_quantity" do
      it "returns remaining quantity when price lines > allocations" do
        create(:proxy_order_price_line, proxy_order_item: item, quantity: 5)
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 2)
        expect(item.remaining_allocation_quantity).to eq(3)
      end

      it "returns 1 when allocations >= price lines" do
        create(:proxy_order_price_line, proxy_order_item: item, quantity: 2)
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 3)
        expect(item.remaining_allocation_quantity).to eq(1)
      end

      it "returns 1 when no price lines exist" do
        expect(item.remaining_allocation_quantity).to eq(1)
      end
    end
  end
end
