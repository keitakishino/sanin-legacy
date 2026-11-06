class ProxyOrderCalculator
  # 計算: 設計書「金額計算ルール」に従い、カード単価・参加者別合計・手数料・円換算を計算
  def initialize(proxy_order)
    @proxy_order = proxy_order
    # 呼び出し側が preload 済みならそれを使い、そうでなければ従来どおり読み込む
    assoc = proxy_order.proxy_order_items
    @items = (assoc.loaded? ? assoc : assoc.includes(:proxy_order_price_lines, :proxy_order_allocations)).to_a
    @participants = proxy_order.proxy_order_participants.to_a
    @unit_prices = {}
  end

  def unit_price(item)
    return @unit_prices[item.id] if @unit_prices.key?(item.id)

    net = item.proxy_order_price_lines.sum { |l| l.quantity - l.lost_quantity }
    if net.zero?
      @unit_prices[item.id] = BigDecimal("0")
    else
      total = item.proxy_order_price_lines.sum { |l| l.unit_price_usd * (l.quantity - l.lost_quantity) }
      @unit_prices[item.id] = ceil2(total / net)
    end
  end

  def subtotal(allocation)
    item = @items.find { |i| i.id == allocation.proxy_order_item_id }
    (allocation.quantity - allocation.lost_quantity) * unit_price(item)
  end

  def goods_total(participant)
    @items.flat_map(&:proxy_order_allocations)
         .select { |a| a.proxy_order_participant_id == participant.id }
         .sum { |a| subtotal(a) }
  end

  def net_quantity(participant)
    @items.flat_map(&:proxy_order_allocations)
         .select { |a| a.proxy_order_participant_id == participant.id }
         .sum { |a| a.quantity - a.lost_quantity }
  end

  def total_loss?(participant)
    net_quantity(participant).zero?
  end

  def fee_total
    @proxy_order.tax_usd + @proxy_order.customs_usd + @proxy_order.shipping_usd + @proxy_order.payment_fee_usd
  end

  def fee_payer_count
    @participants.count { |p| !total_loss?(p) }
  end

  def fee_per_person
    return BigDecimal("0") if fee_payer_count.zero?

    ceil2(fee_total / fee_payer_count)
  end

  def fee_for(participant)
    return BigDecimal("0") if total_loss?(participant)

    fee_per_person
  end

  def payment_usd(participant)
    goods_total(participant) + fee_for(participant)
  end

  def payment_jpy(participant)
    return 0 if total_loss?(participant)
    return nil if @proxy_order.usd_jpy_rate.nil?

    self.class.ceil_100(payment_usd(participant) * @proxy_order.usd_jpy_rate)
  end

  def self.ceil_100(yen)
    (BigDecimal(yen.to_s) / 100).ceil.to_i * 100
  end

  private

  def ceil2(value)
    BigDecimal(value.to_s).ceil(2)
  end
end
