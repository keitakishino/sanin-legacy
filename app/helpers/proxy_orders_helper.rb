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
    participant.user&.username || participant.guest_name
  end

  def foil_label(item)
    return nil if item.foil.blank?
    t("activerecord.enums.trade_card_offer.foil.#{item.foil}")
  end

  def frame_label(item)
    return nil if item.frame.blank?
    t("activerecord.enums.trade_card_offer.frame.#{item.frame}")
  end

  # カード明細の見出しに出す「セット ／ フォイル ／ フレーム」
  def card_meta(item)
    [
      item.expansion&.scryfall_set_code&.upcase,
      foil_label(item),
      frame_label(item)
    ].compact_blank.join(t("admin.proxy_order.card_meta_separator"))
  end

  # 参加者全員の支払い合計。レート未設定の参加者が一人でもいれば nil（未確定）
  def total_payment_jpy(calculator, participants)
    amounts = participants.map { |p| calculator.payment_jpy(p) }
    return nil if amounts.any?(&:nil?)

    amounts.sum
  end

  # コンボボックスの候補データ。画面に埋め込むので id と username/label だけ
  def participant_candidates(users, participants)
    candidates = []

    # 先に参加者（order(:id) の順）
    participants.each do |p|
      candidates << {
        kind: "participant",
        label: p.user&.username || p.guest_name,
        participant_id: p.id,
        user_id: p.user_id,
        assigned_item_ids: p.proxy_order_allocations.map(&:proxy_order_item_id)
      }
    end

    # 次にユーザーのうち、参加者に含まれないもの（username 順）
    participant_user_ids = participants.map(&:user_id).compact
    users.reject { |u| participant_user_ids.include?(u.id) }.each do |u|
      candidates << {
        kind: "user",
        label: u.username,
        participant_id: nil,
        user_id: u.id,
        assigned_item_ids: []
      }
    end

    candidates
  end

  # ゲスト行を選べない条件の判定用。ProxyOrderParticipant の guest_name_not_conflict_with_username / guest_name_unique_in_order と同じ対象
  def participant_name_conflicts(users, participants)
    {
      usernames: users.map(&:username),
      guest_names: participants.select { |p| p.user_id.nil? }.map(&:guest_name)
    }
  end
end
