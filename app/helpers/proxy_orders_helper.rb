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
end
