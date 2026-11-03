require "rails_helper"

RSpec.describe ProxyOrderParticipant, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:proxy_order) }
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to have_many(:proxy_order_allocations).dependent(:destroy) }
  end

  describe "normalizes" do
    it "strips leading and trailing whitespace from guest_name" do
      participant = build(:proxy_order_participant, :guest, guest_name: "  Test  ")
      participant.valid?
      expect(participant.guest_name).to eq("Test")
    end

    it "converts empty string to nil" do
      participant = build(:proxy_order_participant, :guest, guest_name: "   ")
      participant.valid?
      expect(participant.guest_name).to be_nil
    end
  end

  describe ".normalize_name" do
    it "normalizes to lowercase" do
      expect(ProxyOrderParticipant.normalize_name("TestUser")).to eq("testuser")
    end

    it "normalizes NFKC: full-width to half-width" do
      expect(ProxyOrderParticipant.normalize_name("ｔｅｓｔ")).to eq("test")
    end

    it "normalizes whitespace" do
      expect(ProxyOrderParticipant.normalize_name("  Test  ")).to eq("test")
    end

    it "handles combined transformations" do
      expect(ProxyOrderParticipant.normalize_name("  Ｔｅｓｔ  ")).to eq("test")
    end
  end

  describe "user_or_guest_exclusive validation" do
    let(:proxy_order) { create(:proxy_order) }
    let(:user) { create(:user) }

    it "is valid with only user_id" do
      participant = build(:proxy_order_participant, proxy_order:, user:, guest_name: nil)
      expect(participant).to be_valid
    end

    it "is valid with only guest_name" do
      participant = build(:proxy_order_participant, :guest, proxy_order:)
      expect(participant).to be_valid
    end

    it "is invalid with both user_id and guest_name" do
      participant = build(:proxy_order_participant, proxy_order:, user:, guest_name: "Guest")
      expect(participant).not_to be_valid
      expect(participant.errors.of_kind?(:base, :user_or_guest_required)).to be true
    end

    it "is invalid with neither user_id nor guest_name" do
      participant = build(:proxy_order_participant, proxy_order:, user: nil, guest_name: nil)
      expect(participant).not_to be_valid
      expect(participant.errors.of_kind?(:base, :user_or_guest_required)).to be true
    end
  end

  describe "user_id uniqueness per order" do
    let(:proxy_order) { create(:proxy_order) }
    let(:user) { create(:user) }

    it "allows the same user in different orders" do
      other_order = create(:proxy_order)
      create(:proxy_order_participant, proxy_order:, user:)
      participant = build(:proxy_order_participant, proxy_order: other_order, user:)
      expect(participant).to be_valid
    end

    it "rejects duplicate user in the same order" do
      create(:proxy_order_participant, proxy_order:, user:)
      duplicate = build(:proxy_order_participant, proxy_order:, user:)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.of_kind?(:user_id, :taken)).to be true
    end

    it "allows nil user_id multiple times" do
      participant1 = build(:proxy_order_participant, :guest, proxy_order:)
      participant2 = build(:proxy_order_participant, :guest, proxy_order:, guest_name: "Another")
      expect(participant1).to be_valid
      expect(participant2).to be_valid
    end
  end

  describe "guest_name_unique_in_order validation (C3, C6)" do
    let(:proxy_order) { create(:proxy_order) }

    it "is valid with unique guest_name" do
      create(:proxy_order_participant, :guest, proxy_order:, guest_name: "Alice")
      participant = build(:proxy_order_participant, :guest, proxy_order:, guest_name: "Bob")
      expect(participant).to be_valid
    end

    it "rejects duplicate guest_name (exact match)" do
      create(:proxy_order_participant, :guest, proxy_order:, guest_name: "Alice")
      duplicate = build(:proxy_order_participant, :guest, proxy_order:, guest_name: "Alice")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.of_kind?(:guest_name, :taken)).to be true
    end

    it "rejects guest_name differing only in whitespace" do
      create(:proxy_order_participant, :guest, proxy_order:, guest_name: "Alice")
      duplicate = build(:proxy_order_participant, :guest, proxy_order:, guest_name: " Alice ")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.of_kind?(:guest_name, :taken)).to be true
    end

    it "rejects guest_name differing only in case" do
      create(:proxy_order_participant, :guest, proxy_order:, guest_name: "Alice")
      duplicate = build(:proxy_order_participant, :guest, proxy_order:, guest_name: "ALICE")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.of_kind?(:guest_name, :taken)).to be true
    end

    it "rejects guest_name differing only in full-width/half-width" do
      create(:proxy_order_participant, :guest, proxy_order:, guest_name: "Ａｌｉｃｅ")
      duplicate = build(:proxy_order_participant, :guest, proxy_order:, guest_name: "Alice")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors.of_kind?(:guest_name, :taken)).to be true
    end

    it "allows same normalized guest_name in different orders" do
      other_order = create(:proxy_order)
      create(:proxy_order_participant, :guest, proxy_order:, guest_name: "Alice")
      participant = build(:proxy_order_participant, :guest, proxy_order: other_order, guest_name: "alice")
      expect(participant).to be_valid
    end

    it "allows updating the same participant (self-update)" do
      participant = create(:proxy_order_participant, :guest, proxy_order:, guest_name: "Alice")
      participant.guest_name = "alice"
      expect(participant).to be_valid
    end
  end

  describe "guest_name_not_conflict_with_username validation (C3)" do
    let(:proxy_order) { create(:proxy_order) }

    before { create(:user, username: "tanaka") }

    it "rejects guest_name matching a username (case-insensitive)" do
      participant = build(:proxy_order_participant, :guest, proxy_order:, guest_name: "tanaka")
      expect(participant).not_to be_valid
      expect(participant.errors.of_kind?(:guest_name, :conflicts_with_username)).to be true
    end

    it "rejects guest_name with different case" do
      participant = build(:proxy_order_participant, :guest, proxy_order:, guest_name: "Tanaka")
      expect(participant).not_to be_valid
      expect(participant.errors.of_kind?(:guest_name, :conflicts_with_username)).to be true
    end

    it "rejects guest_name with whitespace" do
      participant = build(:proxy_order_participant, :guest, proxy_order:, guest_name: " Tanaka ")
      expect(participant).not_to be_valid
      expect(participant.errors.of_kind?(:guest_name, :conflicts_with_username)).to be true
    end

    it "rejects guest_name with full-width characters" do
      participant = build(:proxy_order_participant, :guest, proxy_order:, guest_name: "ｔａｎａｋａ")
      expect(participant).not_to be_valid
      expect(participant.errors.of_kind?(:guest_name, :conflicts_with_username)).to be true
    end

    it "allows guest_name that doesn't match any username" do
      participant = build(:proxy_order_participant, :guest, proxy_order:, guest_name: "tanaka2")
      expect(participant).to be_valid
    end
  end

  describe "linked_from_guest_name validation" do
    let(:proxy_order) { create(:proxy_order) }
    let(:user) { create(:user) }

    it "allows linked_from_guest_name when user_id is present" do
      participant = build(:proxy_order_participant, proxy_order:, user:, guest_name: nil, linked_from_guest_name: "Alice")
      expect(participant).to be_valid
    end

    it "rejects linked_from_guest_name when user_id is nil" do
      participant = build(:proxy_order_participant, :guest, proxy_order:, guest_name: "Bob", linked_from_guest_name: "Alice")
      expect(participant).not_to be_valid
      expect(participant.errors.of_kind?(:linked_from_guest_name, :requires_user)).to be true
    end

    it "allows nil linked_from_guest_name for guest participants" do
      participant = build(:proxy_order_participant, :guest, proxy_order:)
      expect(participant).to be_valid
    end

    it "has linked_from_guest_name column" do
      expect(ProxyOrderParticipant.column_names).to include("linked_from_guest_name")
    end

    it "clears linked_from_guest_name when updating user_id" do
      participant = create(:proxy_order_participant, proxy_order:, user:, guest_name: nil, linked_from_guest_name: "Alice")
      other_user = create(:user)
      participant.update(user_id: other_user.id)
      expect(participant.linked_from_guest_name).to be_nil
    end

    it "clears linked_from_guest_name when changing from user to guest" do
      participant = create(:proxy_order_participant, proxy_order:, user:, guest_name: nil, linked_from_guest_name: "Alice")
      participant.update(user_id: nil, guest_name: "Alice")
      expect(participant.linked_from_guest_name).to be_nil
    end

    it "normalizes linked_from_guest_name (strips whitespace)" do
      participant = build(:proxy_order_participant, proxy_order:, user:, guest_name: nil, linked_from_guest_name: "  Test  ")
      participant.valid?
      expect(participant.linked_from_guest_name).to eq("Test")
    end

    it "converts empty string linked_from_guest_name to nil" do
      participant = build(:proxy_order_participant, proxy_order:, user:, guest_name: nil, linked_from_guest_name: "   ")
      participant.valid?
      expect(participant.linked_from_guest_name).to be_nil
    end
  end

  describe "logical deletion" do
    let(:proxy_order) { create(:proxy_order) }
    let(:participant) { create(:proxy_order_participant, proxy_order:) }

    it "excludes discarded records by default scope" do
      participant.update(discarded_at: Time.current)
      expect(ProxyOrderParticipant.find_by(id: participant.id)).to be_nil
    end

    it "includes discarded records with .with_discarded" do
      participant.update(discarded_at: Time.current)
      expect(ProxyOrderParticipant.with_discarded.find(participant.id)).to eq(participant)
    end

    it "returns only discarded records with .only_discarded" do
      other_participant = create(:proxy_order_participant, proxy_order:)
      participant.update(discarded_at: Time.current)
      expect(ProxyOrderParticipant.only_discarded).to contain_exactly(participant)
      expect(ProxyOrderParticipant.only_discarded).not_to include(other_participant)
    end
  end
end
