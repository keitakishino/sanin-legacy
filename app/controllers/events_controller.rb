class EventsController < ApplicationController
  before_action :authenticate_user!

  def index
    # default_scope により論理削除済みイベント (discarded_at is not null) は自動的に除外される
    @events = Event.all.order(event_date: :desc)
  end

  def show
    @event = Event.find(params[:id])
    # layout: false is set in the view template for turbo_frame rendering
  end
end
