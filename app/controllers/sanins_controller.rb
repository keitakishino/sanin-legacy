class SaninsController < ActionController::Base
  def index
    @trade = Trade.first
  end
end
