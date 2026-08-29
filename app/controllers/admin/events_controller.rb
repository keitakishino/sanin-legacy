class Admin::EventsController < Admin::BaseController
  before_action :set_event, only: [ :edit, :update, :destroy ]

  def index
    @events = Event.all.order(event_date: :desc).includes(:created_by)
  end

  def new
    @event = Event.new
  end

  def create
    @event = Event.new(event_params)
    @event.created_by = current_user

    if @event.save
      redirect_to admin_events_path, notice: t("admin.events.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @event.update(event_params)
      redirect_to admin_events_path, notice: t("admin.events.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.discard!
    redirect_to admin_events_path, notice: t("admin.events.deleted")
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(:title, :description, :event_date)
  end
end
