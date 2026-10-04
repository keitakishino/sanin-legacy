module CardDetailListsHelper
  def card_detail_list_url(list, overrides)
    trade_path(@trade.event_id, @list_params.merge(overrides.transform_keys { |k| list.param_key(k) }).compact_blank)
  end

  def card_detail_sort_header(list, column, label)
    link_to "#{label} #{list.sort_indicator(column)}", card_detail_list_url(list, sort: list.next_sort(column), page: nil), id: "#{list.prefix}_sort_#{column}", class: "hover:text-stone-800"
  end
end
