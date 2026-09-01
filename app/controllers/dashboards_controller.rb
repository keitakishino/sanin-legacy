class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def show
    # Dashboard displays only the empty turbo-frame with src attribute
    # Actual content is loaded lazily via turbo-frame
  end

  def incomplete_trades
    @incomplete_trades = current_user.trades
                                      .where(status: [ :pending, :in_progress ])
                                      .includes(:event)
                                      .order(created_at: :desc)
                                      .limit(3)
    render :incomplete_trades, layout: false
  end
end
