class Admin::UserGuestLinksController < Admin::BaseController
  MAX_CANDIDATES = 50

  before_action :set_user

  def new
    load_candidates
  end

  def create
    result = GuestParticipantLinker.new(
      user: @user,
      guest_name_key: params[:guest_name_key],
      actor: current_user,
      request_id: request.request_id
    ).call

    if result.success?
      @message = t("admin.users.guest_link.success", name: result.guest_names.uniq.join(" / "), count: result.count, username: @user.username)
      @linked_groups = GuestParticipantUnlinker.linked_groups(@user)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_user_path(@user), notice: @message }
      end
    else
      @errors = result.errors
      load_candidates
      render :new, status: :unprocessable_entity, formats: [ :html ]
    end
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def load_candidates
    @q = params[:q].to_s
    # Only show candidates if query parameter is present (initial open shows empty search form)
    if params.has_key?(:q)
      candidates = GuestParticipantLinker.new(user: @user).candidates(@q)
      @too_many = candidates.size > MAX_CANDIDATES
      @candidates = @too_many ? [] : candidates
    else
      @candidates = []
    end
    event_ids = @candidates.flat_map { |c| c.proxy_orders.map(&:event_id) }.uniq
    @events_by_id = Event.unscoped.where(id: event_ids).index_by(&:id)
  end
end
