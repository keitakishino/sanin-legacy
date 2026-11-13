require "rails_helper"

RSpec.describe CardName do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }

    it "validates uniqueness of name" do
      create(:card_name, name: "Lightning Bolt")
      expect { create(:card_name, name: "Lightning Bolt") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it { is_expected.to validate_length_of(:name).is_at_most(255) }
  end

  describe ".suggest" do
    let! :bolt_bend do
      create(:card_name, name: "Bolt Bend")
    end

    let! :lightning_bolt do
      create(:card_name, name: "Lightning Bolt")
    end

    let! :thunderbolt do
      create(:card_name, name: "Thunderbolt")
    end

    it "[C4] 前方一致を先、単語先頭一致、部分一致の順で返す" do
      result = CardName.suggest("Bolt")
      expect(result.pluck(:name)).to eq([ "Bolt Bend", "Lightning Bolt", "Thunderbolt" ])
    end

    it "大文字小文字を区別しない" do
      result = CardName.suggest("bolt")
      expect(result.pluck(:name)).to eq([ "Bolt Bend", "Lightning Bolt", "Thunderbolt" ])
    end

    it "空文字で0件を返す" do
      result = CardName.suggest("")
      expect(result).to be_empty
    end

    it "8件の上限を守る" do
      8.times { |i| create(:card_name, name: "Test #{i}") }
      result = CardName.suggest("test")
      expect(result.count).to eq(8)
    end

    it "% と _ がワイルドカードにならない" do
      create(:card_name, name: "Test_Card")
      create(:card_name, name: "TestCard")
      result = CardName.suggest("Test_")
      expect(result.pluck(:name)).to eq([ "Test_Card" ])
    end
  end
end
