module CardDetailListAssignment
  extend ActiveSupport::Concern

  private

  def assign_card_detail_lists
    @list_base_path = request.path
    @offers_list = CardDetailList.new(@trade.trade_card_offers.includes(:expansion), prefix: "offers", params: params)
    @wants_list = CardDetailList.new(@trade.trade_card_wants.includes(:expansion), prefix: "wants", params: params)
    @list_params = request.query_parameters.slice(*CardDetailList.state_keys("offers"), *CardDetailList.state_keys("wants")).compact_blank
  end

  def assign_card_detail_lists_from_referer
    uri = URI.parse(request.referer.to_s)
    path = uri.path
    state = {}

    expected_user_path = "/trades/#{@trade.event_id}"
    expected_admin_path = "/admin/events/#{@trade.event_id}/trades/#{@trade.id}"

    if path == expected_user_path || path == expected_admin_path
      @list_base_path = path
      state = Rack::Utils.parse_query(uri.query.to_s)
    else
      @list_base_path = @trade.user == current_user ? expected_user_path : expected_admin_path
    end

    @list_params = state.slice(*CardDetailList.state_keys("offers"), *CardDetailList.state_keys("wants")).compact_blank
  rescue URI::InvalidURIError
    @list_base_path = @trade.user == current_user ? expected_user_path : expected_admin_path
    @list_params = {}
  end

  def build_card_detail_lists
    @offers_list = CardDetailList.new(@trade.trade_card_offers.includes(:expansion), prefix: "offers", params: @list_params)
    @wants_list = CardDetailList.new(@trade.trade_card_wants.includes(:expansion), prefix: "wants", params: @list_params)
  end

  def set_list_page(prefix, page)
    key = "#{prefix}_page"
    if page.nil? || page == 1
      @list_params.delete(key)
    else
      @list_params[key] = page.to_s
    end
  end
end
