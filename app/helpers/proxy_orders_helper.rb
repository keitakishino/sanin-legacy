module ProxyOrdersHelper
  def usd(value)
    return "$0.00" if value.nil?
    format("$%.2f", value)
  end

  def jpy_or_pending(value)
    return t("common.pending") if value.nil?
    number_to_currency(value, unit: "¥", precision: 0, format: "%u%n")
  end

  def participant_display_name(participant)
    if participant.user.present?
      participant.user.username
    else
      "#{participant.guest_name}（自由入力）"
    end
  end

  # カード明細の見出しに出す「セット ／ フォイル ／ フレーム」
  def card_meta(item)
    [
      item.expansion&.scryfall_set_code&.upcase,
      t("activerecord.enums.trade_card_offer.foil.#{item.foil}"),
      t("activerecord.enums.trade_card_offer.frame.#{item.frame}")
    ].compact_blank.join(t("admin.proxy_order.card_meta_separator"))
  end

  # 参加者全員の支払い合計。レート未設定の参加者が一人でもいれば nil（未確定）
  def total_payment_jpy(calculator, participants)
    amounts = participants.map { |p| calculator.payment_jpy(p) }
    return nil if amounts.any?(&:nil?)

    amounts.sum
  end
end
