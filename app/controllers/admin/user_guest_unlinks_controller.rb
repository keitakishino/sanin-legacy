class Admin::UserGuestUnlinksController < Admin::BaseController
  before_action :set_user
  before_action :set_group

  def new
    @errors = [ t("admin.users.guest_link.unlink_not_found") ] if @group.nil?
  end

  def create
    result = GuestParticipantUnlinker.new(user: @user, name_key: @name_key, actor: current_user, request_id: request.request_id).call

    if result.success?
      @message = t("admin.users.guest_link.unlink_success", name: result.guest_names.uniq.join(" / "), count: result.count)
      @linked_groups = GuestParticipantUnlinker.linked_groups(@user)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_user_path(@user), notice: @message }
      end
    else
      @errors = result.errors
      set_group
      render :new, status: :unprocessable_entity, formats: [ :html ]
    end
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def set_group
    @name_key = params[:name_key].to_s
    @group = GuestParticipantUnlinker.linked_groups(@user).find { |g| g.normalized_name == GuestParticipantUnlinker.normalize(@name_key) }
  end
end
