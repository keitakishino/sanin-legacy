class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def show
    @incomplete_trades = current_user.trades
                                      .where(status: [ :pending, :in_progress ])
                                      .includes(:event)
                                      .order(created_at: :desc)
                                      .limit(3)
  end
end
