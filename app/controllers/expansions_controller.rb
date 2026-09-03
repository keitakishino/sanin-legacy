class ExpansionsController < ApplicationController
  before_action :authenticate_user!

  def index
    query = params[:q].to_s.strip
    @expansions = Expansion.search_by_code(query)
    render :index, layout: false
  end
end
