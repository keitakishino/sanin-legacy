require "rails_helper"

RSpec.describe ProxyOrderAllocation, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:proxy_order_item) }
    it { is_expected.to belong_to(:proxy_order_participant) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_presence_of(:lost_quantity) }
    it { is_expected.to validate_numericality_of(:quantity).only_integer.is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:lost_quantity).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "uniqueness of proxy_order_participant_id per proxy_order_item_id (C4)" do
    let(:proxy_order) { create(:proxy_order) }
    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }

    it "allows the same item with different participants" do
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant)
      other_participant = create(:proxy_order_participant, proxy_order:)
      allocation = build(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: other_participant)
      expect(allocation).to be_valid
    end

    it "rejects duplicate (same item and participant)" do
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant)
      duplicate = build(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.of_kind?(:proxy_order_participant_id, :taken)).to be true
    end

    it "allows the same participant in different items" do
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant)
      other_item = create(:proxy_order_item, proxy_order:)
      allocation = build(:proxy_order_allocation, proxy_order_item: other_item, proxy_order_participant: participant)
      expect(allocation).to be_valid
    end
  end

  describe "lost_quantity_not_exceed_quantity validation (C7)" do
    let(:proxy_order) { create(:proxy_order) }
    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }

    it "allows lost_quantity <= quantity" do
      allocation = build(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 5, lost_quantity: 3)
      expect(allocation).to be_valid
    end

    it "allows lost_quantity == quantity" do
      allocation = build(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 5, lost_quantity: 5)
      expect(allocation).to be_valid
    end

    it "rejects lost_quantity > quantity" do
      allocation = build(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 5, lost_quantity: 6)
      expect(allocation).not_to be_valid
      expect(allocation.errors.of_kind?(:lost_quantity, :exceeds_quantity)).to be true
    end

    it "allows lost_quantity == 0" do
      allocation = build(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 5, lost_quantity: 0)
      expect(allocation).to be_valid
    end
  end

  describe "quantity validation (C7)" do
    let(:proxy_order) { create(:proxy_order) }
    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }

    it "rejects quantity == 0" do
      allocation = build(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 0)
      expect(allocation).not_to be_valid
    end

    it "rejects negative quantity" do
      allocation = build(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: -1)
      expect(allocation).not_to be_valid
    end

    it "allows positive quantity" do
      allocation = build(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)
      expect(allocation).to be_valid
    end
  end

  describe "participant_in_same_order validation" do
    let(:proxy_order) { create(:proxy_order) }
    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:other_order) { create(:proxy_order) }
    let(:other_participant) { create(:proxy_order_participant, proxy_order: other_order) }

    it "rejects participant from a different order" do
      allocation = build(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: other_participant)
      expect(allocation).not_to be_valid
      expect(allocation.errors.of_kind?(:proxy_order_participant, :must_belong_to_same_order)).to be true
    end

    it "allows participant from the same order" do
      participant = create(:proxy_order_participant, proxy_order:)
      allocation = build(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant)
      expect(allocation).to be_valid
    end
  end

  describe "logical deletion" do
    let(:proxy_order) { create(:proxy_order) }
    let(:item) { create(:proxy_order_item, proxy_order:) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }
    let(:allocation) { create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant) }

    it "excludes discarded records by default scope" do
      allocation.update(discarded_at: Time.current)
      expect(ProxyOrderAllocation.find_by(id: allocation.id)).to be_nil
    end

    it "includes discarded records with .with_discarded" do
      allocation.update(discarded_at: Time.current)
      expect(ProxyOrderAllocation.with_discarded.find(allocation.id)).to eq(allocation)
    end

    it "returns only discarded records with .only_discarded" do
      other_participant = create(:proxy_order_participant, proxy_order:)
      other_allocation = create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: other_participant)
      allocation.update(discarded_at: Time.current)
      expect(ProxyOrderAllocation.only_discarded).to contain_exactly(allocation)
      expect(ProxyOrderAllocation.only_discarded).not_to include(other_allocation)
    end
  end
end
