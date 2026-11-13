class CardNamesController < ApplicationController
  before_action :authenticate_user!

  def index
    @query = params[:q].to_s.strip
    @card_names = CardName.suggest(@query)
    @frame_id = params[:frame].presence || "card_name_suggestions"
    render :index, layout: false
  end
end
