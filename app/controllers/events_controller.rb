class EventsController < ApplicationController
  before_action :authenticate_user!

  def index
    # default_scope により論理削除済みイベント (discarded_at is not null) は自動的に除外される
    @events = Event.all.order(event_date: :desc)
  end

  def show
    @event = Event.find(params[:id])

    # Turbo Frame経由でない場合（直リンク）は404を返す
    return head :not_found unless turbo_frame_request?

    # Rails のTurboサポートにより、turbo_frameタグを含むレスポンスは自動的にレイアウトがスキップされます
    render :show, layout: false
  end
end
