class ProxyOrderCalculator
  # 計算: 率ベースの手数料・送料等分・円換算に基づき、カード単価・参加者別合計・手数料・円換算を計算
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

  def fee_payer_count
    @participants.count { |p| !total_loss?(p) }
  end

  def shipping_per_person
    return BigDecimal("0") if fee_payer_count.zero?

    ceil2(@proxy_order.shipping_usd / fee_payer_count)
  end

  def shipping_for(participant)
    return BigDecimal("0") if total_loss?(participant)

    shipping_per_person
  end

  def purchase_usd(participant)
    goods_total(participant) + shipping_for(participant)
  end

  def payment_fee_for(participant)
    purchase_usd(participant) * @proxy_order.payment_fee_rate / 100
  end

  def customs_for(participant)
    purchase_usd(participant) * @proxy_order.customs_rate / 100
  end

  def consumption_tax_for(participant)
    purchase_usd(participant) * (1 + @proxy_order.customs_rate / 100) * @proxy_order.consumption_tax_rate / 100
  end

  def payment_usd(participant)
    return BigDecimal("0") if total_loss?(participant)

    ceil2(raw_payment_usd(participant))
  end

  def charges_for(participant)
    return 0 if total_loss?(participant)

    payment_usd(participant) - purchase_usd(participant)
  end

  def payment_jpy(participant)
    return 0 if total_loss?(participant)
    return nil if @proxy_order.usd_jpy_rate.nil?

    self.class.ceil_100(raw_payment_usd(participant) * @proxy_order.usd_jpy_rate)
  end

  def self.ceil_100(yen)
    (BigDecimal(yen.to_s) / 100).ceil.to_i * 100
  end

  private

  def raw_payment_usd(participant)
    purchase_usd(participant) + payment_fee_for(participant) + customs_for(participant) + consumption_tax_for(participant)
  end

  def ceil2(value)
    BigDecimal(value.to_s).ceil(2)
  end
end
