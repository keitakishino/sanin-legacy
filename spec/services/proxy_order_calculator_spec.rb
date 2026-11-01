require 'rails_helper'

RSpec.describe ProxyOrderCalculator do
  describe '#unit_price' do
    it '$3×4（うち 2 ロスト）と $4×6 で $3.75' do
      proxy_order = create(:proxy_order)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 3, quantity: 4, lost_quantity: 2)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 4, quantity: 6, lost_quantity: 0)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.unit_price(item)).to eq(BigDecimal("3.75"))
    end

    it '正味 0 枚のカードは 0' do
      proxy_order = create(:proxy_order)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 5, quantity: 2, lost_quantity: 2)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.unit_price(item)).to eq(BigDecimal("0"))
    end
  end

  describe '検算例' do
    it '単価 $2.25、tanaka の小計 $2.25、yoshioka の小計 $6.75' do
      proxy_order = create(:proxy_order)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 1, quantity: 1, lost_quantity: 1)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 2, quantity: 5, lost_quantity: 2)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 3, quantity: 1, lost_quantity: 0)

      tanaka = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "tanaka")
      yoshioka = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "yoshioka")

      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: tanaka, quantity: 2, lost_quantity: 1)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: yoshioka, quantity: 5, lost_quantity: 2)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.unit_price(item)).to eq(BigDecimal("2.25"))
      expect(calculator.goods_total(tanaka)).to eq(BigDecimal("2.25"))
      expect(calculator.goods_total(yoshioka)).to eq(BigDecimal("6.75"))
    end
  end

  describe '#fee_per_person' do
    it '手数料総額 $50・N=6 で $8.34' do
      proxy_order = create(:proxy_order, tax_usd: 20, customs_usd: 10, shipping_usd: 20)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 1)

      6.times do
        participant = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "participant_#{SecureRandom.hex(4)}")
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)
      end

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.fee_total).to eq(BigDecimal("50"))
      expect(calculator.fee_payer_count).to eq(6)
      expect(calculator.fee_per_person).to eq(BigDecimal("8.34"))
    end

    it '全損の参加者は手数料なし・N に含めない' do
      proxy_order = create(:proxy_order, tax_usd: 20, customs_usd: 10, shipping_usd: 20, usd_jpy_rate: 150)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 1)

      6.times do
        participant = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "participant_#{SecureRandom.hex(4)}")
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)
      end

      # 全損の参加者: allocation が全数ロスト
      total_loss_item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: total_loss_item, unit_price_usd: 10, quantity: 1, lost_quantity: 1)
      total_loss_participant = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "total_loss_participant")
      create(:proxy_order_allocation, proxy_order_item: total_loss_item, proxy_order_participant: total_loss_participant, quantity: 1, lost_quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.fee_payer_count).to eq(6)
      expect(calculator.fee_per_person).to eq(BigDecimal("8.34"))
      expect(calculator.fee_for(total_loss_participant)).to eq(BigDecimal("0"))
      expect(calculator.payment_usd(total_loss_participant)).to eq(BigDecimal("0"))
      expect(calculator.payment_jpy(total_loss_participant)).to eq(0)

      # 正味 1 枚以上の参加者の手数料は 8.34
      payer = calculator.instance_variable_get(:@participants).find { |p| !calculator.total_loss?(p) && p != total_loss_participant }
      expect(calculator.fee_for(payer)).to eq(BigDecimal("8.34"))
    end

    it '参加者が 0 人（全員全損）なら $0.00 でエラーにならない' do
      proxy_order = create(:proxy_order, tax_usd: 20, customs_usd: 10, shipping_usd: 20)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 1, lost_quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "total_loss")
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1, lost_quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect { calculator.fee_per_person }.not_to raise_error
      expect(calculator.fee_per_person).to eq(BigDecimal("0"))
    end

    it '参加者 0 人のときもエラーにならない' do
      proxy_order = create(:proxy_order, tax_usd: 20, customs_usd: 10, shipping_usd: 20)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect { calculator.fee_per_person }.not_to raise_error
      expect(calculator.fee_per_person).to eq(BigDecimal("0"))
    end
  end

  describe '.round_1000' do
    it '1,000 円単位に四捨五入し 500 円は切り上げ' do
      expect(ProxyOrderCalculator.round_1000(4125)).to eq(4000)
      expect(ProxyOrderCalculator.round_1000(4500)).to eq(5000)
      expect(ProxyOrderCalculator.round_1000(4499)).to eq(4000)
    end
  end

  describe '#payment_jpy' do
    it 'payment_usd × レートを丸める' do
      proxy_order = create(:proxy_order, tax_usd: 0, customs_usd: 0, shipping_usd: 0, usd_jpy_rate: 137.5)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 30, quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      # payment_usd = $30.00、rate 137.5 → 4125 → 4000
      expect(calculator.payment_usd(participant)).to eq(BigDecimal("30"))
      expect(calculator.payment_jpy(participant)).to eq(4000)
    end

    it 'payment_usd × レート（150）を丸める' do
      proxy_order = create(:proxy_order, tax_usd: 0, customs_usd: 0, shipping_usd: 0, usd_jpy_rate: 150)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 30, quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      # payment_usd = $30.00、rate 150 → 4500 → 5000
      expect(calculator.payment_usd(participant)).to eq(BigDecimal("30"))
      expect(calculator.payment_jpy(participant)).to eq(5000)
    end

    it 'レート未設定なら nil' do
      proxy_order = create(:proxy_order, tax_usd: 0, customs_usd: 0, shipping_usd: 0, usd_jpy_rate: nil)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 30, quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.payment_jpy(participant)).to be_nil
    end
  end
end
