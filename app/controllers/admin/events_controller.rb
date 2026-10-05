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
      record_audit("event.create", target: @event, details: { title: @event.title, event_date: @event.event_date })
      redirect_to admin_events_path, notice: t("admin.events.created")
    else
      record_audit("event.create", target: nil, result: :failure, details: audit_failure_details(@event))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @event.update(event_params)
      record_audit("event.update", target: @event, details: @event.saved_changes.except("updated_at"))
      redirect_to admin_events_path, notice: t("admin.events.updated")
    else
      record_audit("event.update", target: @event, result: :failure, details: audit_failure_details(@event))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.discard!
    failures = @event.discard_failures
    if failures.include?(@event)
      report_operation_failure("event.discard", @event)
    else
      record_audit("event.discard", target: @event)
    end
    (failures - [ @event ]).each do |record|
      report_operation_failure("#{record.class.name.underscore}.discard", record, details: { event_id: @event.id })
    end
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
