class Admin::InvitationsController < Admin::BaseController
  def index
    @invitations = Invitation.all.order(created_at: :desc)
    @invitation = Invitation.new
  end

  def create
    max_retries = 2
    retries = 0

    begin
      @invitation = build_invitation
      @invitation.save!
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_invitations_path, notice: "招待コードを発行しました" }
      end
    rescue ActiveRecord::RecordInvalid => e
      if e.record.errors.key?(:code) && retries < max_retries
        retries += 1
        retry
      else
        handle_creation_error(e)
      end
    end
  end

  private

  def build_invitation
    Invitation.new(
      code: SecureRandom.alphanumeric(12),
      expires_at: 30.days.from_now,
      status: :active,
      issued_by: current_user
    )
  end

  def handle_creation_error(error)
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = "招待コード発行に失敗しました"
        render :error, status: :unprocessable_entity
      end
      format.html do
        @invitations = Invitation.all.order(created_at: :desc)
        flash.now[:alert] = "招待コード発行に失敗しました"
        render :index, status: :unprocessable_entity
      end
    end
  end
end
