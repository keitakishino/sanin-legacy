class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Disabled in test environment to allow RSpec request specs to run without User-Agent issues
  allow_browser versions: :modern unless Rails.env.test?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :user_signed_in?

  rescue_from ForbiddenError, with: :handle_forbidden

  private

  def handle_forbidden
    @status_code = 403
    @title = t("errors.forbidden.title", default: "アクセスが拒否されました")
    @message = t("errors.forbidden.message", default: "このページにアクセスする権限がありません")
    @button_path = user_signed_in? ? root_path : signin_path
    render "errors/show", status: :forbidden, layout: "error"
  end

  def current_user
    @current_user ||= session[:user_id] ? User.find_by(id: session[:user_id]) : nil
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_user!
    redirect_to signin_path unless user_signed_in?
  end

  def log_in(user)
    session[:user_id] = user.id
  end

  def log_out
    session.delete(:user_id)
    @current_user = nil
  end
end
