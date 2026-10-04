module CardDetailListAssignment
  extend ActiveSupport::Concern

  private

  def assign_card_detail_lists
    @offers_list = CardDetailList.new(@trade.trade_card_offers.includes(:expansion), prefix: "offers", params: params)
    @wants_list = CardDetailList.new(@trade.trade_card_wants.includes(:expansion), prefix: "wants", params: params)
    @list_params = request.query_parameters.slice(*CardDetailList.state_keys("offers"), *CardDetailList.state_keys("wants")).compact_blank
  end
end
