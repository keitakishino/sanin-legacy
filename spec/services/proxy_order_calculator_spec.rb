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

  describe '#shipping_per_person' do
    it '送料 $50・正味のある参加者 6 人なら $8.34' do
      proxy_order = create(:proxy_order, shipping_usd: 50)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 1)

      6.times do
        participant = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "participant_#{SecureRandom.hex(4)}")
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)
      end

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.fee_payer_count).to eq(6)
      expect(calculator.shipping_per_person).to eq(BigDecimal("8.34"))
    end

    it '全員全損・参加者 0 人でも $0 でエラーにならない' do
      proxy_order = create(:proxy_order, shipping_usd: 50)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 1, lost_quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "total_loss")
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1, lost_quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect { calculator.shipping_per_person }.not_to raise_error
      expect(calculator.shipping_per_person).to eq(BigDecimal("0"))
    end

    it '参加者 0 人のときもエラーにならない' do
      proxy_order = create(:proxy_order, shipping_usd: 50)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect { calculator.shipping_per_person }.not_to raise_error
      expect(calculator.shipping_per_person).to eq(BigDecimal("0"))
    end
  end

  describe 'rate-based calculation' do
    it '[C1] 商品$10・送料$2・参加者1人・率 4.1/4/10 で purchase 12、決済手数料 0.492、関税 0.48、消費税 1.248、支払合計 $14.22' do
      proxy_order = create(:proxy_order, shipping_usd: 2, payment_fee_rate: 4.1, customs_rate: 4, consumption_tax_rate: 10)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.goods_total(participant)).to eq(BigDecimal("10"))
      expect(calculator.purchase_usd(participant)).to eq(BigDecimal("12"))
      expect(calculator.payment_fee_for(participant)).to eq(BigDecimal("0.492"))
      expect(calculator.customs_for(participant)).to eq(BigDecimal("0.48"))
      expect(calculator.consumption_tax_for(participant)).to eq(BigDecimal("1.248"))
      expect(calculator.payment_usd(participant)).to eq(BigDecimal("14.22"))
    end

    it '[C2] 支払合計 $14.22・レート 150 で ¥2,200' do
      proxy_order = create(:proxy_order, shipping_usd: 2, payment_fee_rate: 4.1, customs_rate: 4, consumption_tax_rate: 10, usd_jpy_rate: 150)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.payment_jpy(participant)).to eq(2200)
    end

    it '[C4] ロストで按分が変わり、全ロストの参加者は支払 0 円' do
      proxy_order = create(:proxy_order, shipping_usd: 20, payment_fee_rate: 4.1, customs_rate: 4, consumption_tax_rate: 10, usd_jpy_rate: 150)
      item_a = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item_a, unit_price_usd: 10, quantity: 1)

      item_b = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item_b, unit_price_usd: 3, quantity: 4, lost_quantity: 2)

      item_c = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item_c, unit_price_usd: 4, quantity: 6)

      a = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "A")
      create(:proxy_order_allocation, proxy_order_item: item_a, proxy_order_participant: a, quantity: 1)
      create(:proxy_order_allocation, proxy_order_item: item_b, proxy_order_participant: a, quantity: 1)
      create(:proxy_order_allocation, proxy_order_item: item_c, proxy_order_participant: a, quantity: 1)

      b = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "B")
      create(:proxy_order_allocation, proxy_order_item: item_a, proxy_order_participant: b, quantity: 1)
      create(:proxy_order_allocation, proxy_order_item: item_b, proxy_order_participant: b, quantity: 1)
      create(:proxy_order_allocation, proxy_order_item: item_c, proxy_order_participant: b, quantity: 6)

      c = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "C")
      create(:proxy_order_allocation, proxy_order_item: item_a, proxy_order_participant: c, quantity: 1, lost_quantity: 1)
      create(:proxy_order_allocation, proxy_order_item: item_b, proxy_order_participant: c, quantity: 2, lost_quantity: 2)
      create(:proxy_order_allocation, proxy_order_item: item_c, proxy_order_participant: c, quantity: 1, lost_quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.fee_payer_count).to eq(2)
      expect(calculator.total_loss?(c)).to eq(true)
      expect(calculator.shipping_for(c)).to eq(BigDecimal("0"))
      expect(calculator.payment_usd(c)).to eq(BigDecimal("0"))
      expect(calculator.payment_jpy(c)).to eq(0)
      expect(calculator.shipping_for(a)).to eq(BigDecimal("10"))
    end

    it '[C5] 送料は全ロストでない参加者で等分される' do
      proxy_order = create(:proxy_order, shipping_usd: 20, payment_fee_rate: 4.1, customs_rate: 4, consumption_tax_rate: 10)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 1)

      a = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "A")
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: a, quantity: 1)

      b = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "B")
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: b, quantity: 1)

      c = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "C")
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: c, quantity: 1, lost_quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.shipping_per_person).to eq(BigDecimal("10"))
      expect(calculator.shipping_for(a)).to eq(BigDecimal("10"))
      expect(calculator.shipping_for(b)).to eq(BigDecimal("10"))
      expect(calculator.shipping_for(c)).to eq(BigDecimal("0"))
    end

    it '[C6] レート未入力なら payment_jpy は nil' do
      proxy_order = create(:proxy_order, shipping_usd: 2, payment_fee_rate: 4.1, customs_rate: 4, consumption_tax_rate: 10, usd_jpy_rate: nil)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.payment_jpy(participant)).to be_nil
    end

    it 'charges_for の確認' do
      proxy_order = create(:proxy_order, shipping_usd: 2, payment_fee_rate: 4.1, customs_rate: 4, consumption_tax_rate: 10)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.charges_for(participant)).to eq(BigDecimal("2.22"))
    end
  end

  describe '.ceil_100' do
    it '100 円単位に切り上げる' do
      expect(ProxyOrderCalculator.ceil_100(4125)).to eq(4200)
      expect(ProxyOrderCalculator.ceil_100(4500)).to eq(4500)
      expect(ProxyOrderCalculator.ceil_100(4501)).to eq(4600)
      expect(ProxyOrderCalculator.ceil_100(1)).to eq(100)
      expect(ProxyOrderCalculator.ceil_100(400)).to eq(400)
      expect(ProxyOrderCalculator.ceil_100(0)).to eq(0)
      expect(ProxyOrderCalculator.ceil_100(BigDecimal("1612.5"))).to eq(1700)
    end
  end

  describe '#payment_jpy' do
    it 'payment_usd × レートを丸める' do
      proxy_order = create(:proxy_order, shipping_usd: 0, usd_jpy_rate: 137.5, payment_fee_rate: 0, customs_rate: 0, consumption_tax_rate: 0)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 30, quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      # payment_usd = $30.00、rate 137.5 → 4125 → 4200
      expect(calculator.payment_usd(participant)).to eq(BigDecimal("30"))
      expect(calculator.payment_jpy(participant)).to eq(4200)
    end

    it 'payment_usd × レート（150）を丸める' do
      proxy_order = create(:proxy_order, shipping_usd: 0, usd_jpy_rate: 150, payment_fee_rate: 0, customs_rate: 0, consumption_tax_rate: 0)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 30, quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      # payment_usd = $30.00、rate 150 → 4500 → 4500
      expect(calculator.payment_usd(participant)).to eq(BigDecimal("30"))
      expect(calculator.payment_jpy(participant)).to eq(4500)
    end

    it 'レート未設定なら nil' do
      proxy_order = create(:proxy_order, shipping_usd: 0, usd_jpy_rate: nil, payment_fee_rate: 0, customs_rate: 0, consumption_tax_rate: 0)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 30, quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.payment_jpy(participant)).to be_nil
    end

    it '換算額が 500 円未満でも 0 円にならず 100 円単位に切り上げる' do
      proxy_order = create(:proxy_order, shipping_usd: 0, usd_jpy_rate: 150, payment_fee_rate: 0, customs_rate: 0, consumption_tax_rate: 0)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 3, quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      # $3 × 150 = 450 → 500
      expect(calculator.payment_jpy(participant)).to eq(500)
    end

    it '$4 × 100 円/$ は 400 円' do
      proxy_order = create(:proxy_order, shipping_usd: 0, usd_jpy_rate: 100, payment_fee_rate: 0, customs_rate: 0, consumption_tax_rate: 0)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 4, quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      # $4 × 100 = 400 → 400（100 の倍数なのでそのまま）
      expect(calculator.payment_jpy(participant)).to eq(400)
    end
  end

  describe 'preload 済みの明細' do
    it '明細・価格行・割り当てが読み込み済みなら追加のクエリを出さない' do
      proxy_order = create(:proxy_order, shipping_usd: 0, usd_jpy_rate: 150, payment_fee_rate: 0, customs_rate: 0, consumption_tax_rate: 0)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 30, quantity: 1)
      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      loaded = ProxyOrder.preload(:proxy_order_participants,
                                  proxy_order_items: [ :proxy_order_price_lines, :proxy_order_allocations ])
                         .find(proxy_order.id)
      loaded_participant = loaded.proxy_order_participants.to_a.first
      calculator = nil
      queries = []
      counter = ->(*, payload) { queries << payload[:sql] unless %w[SCHEMA CACHE].include?(payload[:name]) || payload[:cached] }

      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
        calculator = ProxyOrderCalculator.new(loaded)
        expect(calculator.payment_jpy(loaded_participant)).to eq(4500)
      end

      expect(queries).to be_empty
    end
  end
end
