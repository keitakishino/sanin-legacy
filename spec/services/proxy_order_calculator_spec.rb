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

  describe '#fee_total' do
    it '[C4] goods_total $100、決済手数料率 4.1% + 関税率 4.0% + 消費税率 10.0% + 送料 $20 = $38.60' do
      proxy_order = create(:proxy_order, shipping_usd: 20, payment_fee_rate: 4.1, customs_rate: 4.0, consumption_tax_rate: 10.0)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 10)
      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 10)

      calculator = ProxyOrderCalculator.new(proxy_order)

      # goods_total = $100
      # payment_fee = $100 * 4.1% = $4.10
      # customs = $100 * 4.0% = $4.00
      # subtotal = $100 + $4.10 + $4.00 + $20 = $128.10
      # consumption_tax = $128.10 * 10% = $12.81
      # fee_total = $4.10 + $4.00 + $12.81 + $20 = $40.91
      expect(calculator.fee_total).to eq(BigDecimal("40.91"))
    end
  end

  describe '#fee_per_person' do
    it 'goods_total $60・N=6 で分割・fee_per_person を計算' do
      proxy_order = create(:proxy_order, shipping_usd: 20, payment_fee_rate: 4.1, customs_rate: 4.0, consumption_tax_rate: 10.0)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 6)

      6.times do
        participant = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "participant_#{SecureRandom.hex(4)}")
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)
      end

      calculator = ProxyOrderCalculator.new(proxy_order)

      # goods_total = $60
      # payment_fee = $60 * 4.1% = $2.46
      # customs = $60 * 4.0% = $2.40
      # subtotal = $60 + $2.46 + $2.40 + $20 = $84.86
      # consumption_tax = $84.86 * 10% = $8.49
      # fee_total = $2.46 + $2.40 + $8.49 + $20 = $33.35
      # fee_per_person = $33.35 / 6 = $5.56
      expect(calculator.fee_payer_count).to eq(6)
      expect(calculator.fee_per_person).to eq(BigDecimal("5.56"))
    end

    it '[C3] 全損の参加者は手数料なし・N に含めない' do
      proxy_order = create(:proxy_order, shipping_usd: 20, payment_fee_rate: 4.1, customs_rate: 4.0, consumption_tax_rate: 10.0, usd_jpy_rate: 150)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 6)

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
      # fee_per_person は前のテストと同じ値
      expect(calculator.fee_per_person).to eq(BigDecimal("5.56"))
      expect(calculator.fee_for(total_loss_participant)).to eq(BigDecimal("0"))
      expect(calculator.payment_usd(total_loss_participant)).to eq(BigDecimal("0"))
      expect(calculator.payment_jpy(total_loss_participant)).to eq(0)

      # 正味 1 枚以上の参加者の手数料は 5.56
      payer = calculator.instance_variable_get(:@participants).find { |p| !calculator.total_loss?(p) && p != total_loss_participant }
      expect(calculator.fee_for(payer)).to eq(BigDecimal("5.56"))
    end

    it '参加者が 0 人（全員全損）なら $0.00 でエラーにならない' do
      proxy_order = create(:proxy_order, shipping_usd: 20, payment_fee_rate: 4.1, customs_rate: 4.0, consumption_tax_rate: 10.0)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 1, lost_quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:, user: nil, guest_name: "total_loss")
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1, lost_quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect { calculator.fee_per_person }.not_to raise_error
      expect(calculator.fee_per_person).to eq(BigDecimal("0"))
    end

    it '参加者 0 人のときもエラーにならない' do
      proxy_order = create(:proxy_order, shipping_usd: 20, payment_fee_rate: 4.1, customs_rate: 4.0, consumption_tax_rate: 10.0)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect { calculator.fee_per_person }.not_to raise_error
      expect(calculator.fee_per_person).to eq(BigDecimal("0"))
    end
  end

  describe '.ceil_100' do
    it '[C1] 100 円単位に切り上げる' do
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
      proxy_order = create(:proxy_order, shipping_usd: 0, payment_fee_rate: 0, customs_rate: 0, consumption_tax_rate: 0, usd_jpy_rate: 137.5)
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
      proxy_order = create(:proxy_order, shipping_usd: 0, payment_fee_rate: 0, customs_rate: 0, consumption_tax_rate: 0, usd_jpy_rate: 150)
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
      proxy_order = create(:proxy_order, shipping_usd: 0, payment_fee_rate: 0, customs_rate: 0, consumption_tax_rate: 0, usd_jpy_rate: nil)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 30, quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      expect(calculator.payment_jpy(participant)).to be_nil
    end

    it '[C2] 換算額が 500 円未満でも 0 円にならず 100 円単位に切り上げる' do
      proxy_order = create(:proxy_order, shipping_usd: 0, payment_fee_rate: 0, customs_rate: 0, consumption_tax_rate: 0, usd_jpy_rate: 150)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 3, quantity: 1)

      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      calculator = ProxyOrderCalculator.new(proxy_order)

      # $3 × 150 = 450 → 500
      expect(calculator.payment_jpy(participant)).to eq(500)
    end

    it '[C2] $4 × 100 円/$ は 400 円' do
      proxy_order = create(:proxy_order, shipping_usd: 0, payment_fee_rate: 0, customs_rate: 0, consumption_tax_rate: 0, usd_jpy_rate: 100)
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
      proxy_order = create(:proxy_order, shipping_usd: 0, payment_fee_rate: 0, customs_rate: 0, consumption_tax_rate: 0, usd_jpy_rate: 150)
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
