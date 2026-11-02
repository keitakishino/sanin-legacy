require "rails_helper"

RSpec.describe ProxyOrder, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:event) }
    it { is_expected.to have_many(:proxy_order_items).dependent(:destroy) }
    it { is_expected.to have_many(:proxy_order_participants).dependent(:destroy) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(ordered: 0, arrived: 1, completed: 2) }
  end

  describe "validations" do
    let(:event) { create(:event, :proxy_order) }

    it { is_expected.to validate_presence_of(:tax_usd) }
    it { is_expected.to validate_presence_of(:customs_usd) }
    it { is_expected.to validate_presence_of(:shipping_usd) }
    it { is_expected.to validate_presence_of(:usd_jpy_rate).on(:create).allow_nil }
    it { is_expected.to validate_numericality_of(:tax_usd).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:customs_usd).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:shipping_usd).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:usd_jpy_rate).is_greater_than(0).allow_nil }
  end

  describe "unique event_id" do
    it "can create a ProxyOrder with a proxy_order event" do
      event = create(:event, :proxy_order)
      proxy_order = build(:proxy_order, event:)
      expect(proxy_order).to be_valid
      expect { proxy_order.save! }.not_to raise_error
    end

    it "cannot create a second ProxyOrder for the same event" do
      event = create(:event, :proxy_order)
      create(:proxy_order, event:)
      second = build(:proxy_order, event:)
      expect(second).not_to be_valid
      expect(second.errors).to have_key(:event_id)
      expect(second.errors.of_kind?(:event_id, :taken)).to be true
    end

    it "raises ActiveRecord::RecordNotUnique on save without validation" do
      event = create(:event, :proxy_order)
      create(:proxy_order, event:)
      second = build(:proxy_order, event:)
      expect { second.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "event_must_be_proxy_order_type validation" do
    it "is valid for a proxy_order event" do
      event = create(:event, :proxy_order)
      proxy_order = build(:proxy_order, event:)
      expect(proxy_order).to be_valid
    end

    it "is invalid for a trade event" do
      event = create(:event, :trade)
      proxy_order = build(:proxy_order, event:)
      expect(proxy_order).not_to be_valid
      expect(proxy_order.errors.of_kind?(:event, :must_be_proxy_order_event)).to be true
    end

    it "is invalid for a tournament event" do
      event = create(:event, :tournament)
      proxy_order = build(:proxy_order, event:)
      expect(proxy_order).not_to be_valid
      expect(proxy_order.errors.of_kind?(:event, :must_be_proxy_order_event)).to be true
    end
  end

  describe "status enum default" do
    it "defaults to ordered" do
      event = create(:event, :proxy_order)
      proxy_order = create(:proxy_order, event:)
      expect(proxy_order.status).to eq("ordered")
    end
  end

  describe "logical deletion" do
    let(:event) { create(:event, :proxy_order) }
    let(:proxy_order) { create(:proxy_order, event:) }

    it "responds to discarded?" do
      expect(proxy_order.discarded?).to be false
      proxy_order.update(discarded_at: Time.current)
      expect(proxy_order.discarded?).to be true
    end

    it "excludes discarded records by default" do
      proxy_order.update(discarded_at: Time.current)
      expect(ProxyOrder.find_by(id: proxy_order.id)).to be_nil
    end

    it "includes discarded records with .with_discarded" do
      proxy_order.update(discarded_at: Time.current)
      expect(ProxyOrder.with_discarded.find(proxy_order.id)).to eq(proxy_order)
    end
  end

  describe "CRUD operations" do
    let(:event) { create(:event, :proxy_order) }

    it "can be created" do
      proxy_order = build(:proxy_order, event:)
      expect { proxy_order.save! }.not_to raise_error
    end

    it "can be updated" do
      proxy_order = create(:proxy_order, event:)
      expect { proxy_order.update!(status: :arrived) }.not_to raise_error
      expect(proxy_order.reload.status).to eq("arrived")
    end

    it "can be destroyed" do
      proxy_order = create(:proxy_order, event:)
      expect { proxy_order.destroy }.not_to raise_error
      expect(ProxyOrder.find_by(id: proxy_order.id)).to be_nil
    end
  end

  describe "#discard!" do
    let(:event) { create(:event, :proxy_order) }
    let(:proxy_order) { create(:proxy_order, event:) }

    it "logically deletes proxy order and all related records" do
      item = create(:proxy_order_item, proxy_order:)
      price_line = create(:proxy_order_price_line, proxy_order_item: item)
      participant = create(:proxy_order_participant, proxy_order:)
      allocation = create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant)

      expect(proxy_order.discarded?).to be false
      expect(item.discarded?).to be false
      expect(price_line.discarded?).to be false
      expect(participant.discarded?).to be false
      expect(allocation.discarded?).to be false

      result = proxy_order.discard!

      expect(result).to be true
      expect(proxy_order.reload.discarded?).to be true
      expect(item.reload.discarded?).to be true
      expect(price_line.reload.discarded?).to be true
      expect(participant.reload.discarded?).to be true
      expect(allocation.reload.discarded?).to be true
    end

    it "returns false and does not delete children when update fails" do
      item = create(:proxy_order_item, proxy_order:)
      price_line = create(:proxy_order_price_line, proxy_order_item: item)
      participant = create(:proxy_order_participant, proxy_order:)
      allocation = create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant)

      allow_any_instance_of(ProxyOrder).to receive(:update).and_return(false)

      result = proxy_order.discard!

      expect(result).to be false
      expect(proxy_order.discard_failures).to include(proxy_order)
      expect(item.reload.discarded?).to be false
      expect(price_line.reload.discarded?).to be false
      expect(participant.reload.discarded?).to be false
      expect(allocation.reload.discarded?).to be false
    end
  end

  describe "association to Event" do
    it "can be accessed via event.proxy_order" do
      event = create(:event, :proxy_order)
      proxy_order = create(:proxy_order, event:)
      expect(event.proxy_order).to eq(proxy_order)
    end
  end
end
