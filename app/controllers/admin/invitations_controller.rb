class Admin::InvitationsController < Admin::BaseController
  INVITATION_CODE_LENGTH = 12
  MAX_CODE_RETRIES = 2

  def index
    @invitations = Invitation.all.includes(:issued_by, :used_by).order(created_at: :desc)
    @invitation = Invitation.new
  end

  def create
    retries = 0

    begin
      @invitation = build_invitation
      @invitation.save!
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_invitations_path, notice: t("admin.invitations.created") }
      end
    rescue ActiveRecord::RecordInvalid => e
      if e.record.errors.key?(:code) && retries < MAX_CODE_RETRIES
        retries += 1
        retry
      else
        handle_creation_error
      end
    end
  end

  private

  def build_invitation
    Invitation.new(
      code: SecureRandom.alphanumeric(INVITATION_CODE_LENGTH),
      expires_at: 30.days.from_now,
      status: :active,
      issued_by: current_user
    )
  end

  def handle_creation_error
    @invitation.errors.add(:base, t("admin.invitations.creation_failed"))
    respond_to do |format|
      format.turbo_stream { render :create, status: :unprocessable_entity }
      format.html do
        @invitations = Invitation.all.includes(:issued_by, :used_by).order(created_at: :desc)
        render :index, status: :unprocessable_entity
      end
    end
  end
end
