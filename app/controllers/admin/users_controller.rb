class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [ :show ]

  def index
    @users = if params[:q].present?
      User.where("username ILIKE ? OR email ILIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
          .order(created_at: :desc)
    else
      User.order(created_at: :desc)
    end

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @trades = @user.trades.includes(:event).order(created_at: :desc)
  end

  private

  def set_user
    @user = User.find(params[:id])
  end
end
