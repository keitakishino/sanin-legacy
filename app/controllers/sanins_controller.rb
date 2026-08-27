class SaninsController < ApplicationController
  def index
    @trade = Trade.first
  end
end
