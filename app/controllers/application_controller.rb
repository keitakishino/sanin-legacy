class ApplicationController < ActionController::Base
  include AuditRecordable

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Disabled in test environment to allow RSpec request specs to run without User-Agent issues
  allow_browser versions: :modern unless Rails.env.test?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # セッションの絶対的な上限。
  # クッキー側の expire_after（config/initializers/session_store.rb）はリクエストの
  # たびに延びるため、使われ続けている限り期限が来ない。盗まれたクッキーが
  # いつまでも通ることがないよう、発行時刻からの経過でも打ち切る。
  SESSION_MAX_AGE = 14.days

  helper_method :current_user, :user_signed_in?

  before_action :discard_invalid_session
  before_action :set_i18n_locale

  rescue_from ForbiddenError, with: :handle_forbidden

  private

  def set_i18n_locale
    I18n.locale = :ja
  end

  def handle_forbidden
    @status_code = 403
    @title = t("errors.forbidden.title", default: "アクセスが拒否されました")
    @message = t("errors.forbidden.message", default: "このページにアクセスする権限がありません")
    @button_path = user_signed_in? ? root_path : signin_path
    render "errors/show", status: :forbidden, layout: "error", formats: [ :html ]
  end

  # 失効したセッションのクッキーをリクエストの入口で捨てる。
  # 捨てておかないと、同じクッキーが次のリクエストでも送られ続ける。
  def discard_invalid_session
    return if session[:user_id].blank?
    return if current_user.present?

    reset_session
  end

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = authenticate_from_session
  end

  def authenticate_from_session
    return nil if session[:user_id].blank?
    return nil unless session_within_max_age?

    user = User.find_by(id: session[:user_id])
    return nil if user.nil?
    return nil unless session_credentials_current?(user)

    user
  end

  def session_within_max_age?
    issued_at = session[:issued_at]
    return false if issued_at.blank?

    Time.zone.at(issued_at.to_i) > SESSION_MAX_AGE.ago
  end

  # パスワード変更やユーザー削除のあとに発行済みだったセッションを通さない。
  # 値そのものは User#session_auth_token が作る。
  def session_credentials_current?(user)
    ActiveSupport::SecurityUtils.secure_compare(
      session[:auth_token].to_s,
      user.session_auth_token
    )
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_user!
    redirect_to signin_path unless user_signed_in?
  end

  # ログイン前のセッションをそのまま認証済みセッションに昇格させない（セッション固定対策）。
  # reset_session はセッションを作り直し、CSRF トークンも再発行するため、
  # ログイン直前に攻撃者が仕込んだセッション ID は認証後には使えなくなる。
  # 呼び出し側がセッションに入れた値（signup_token など）もここで消えるので、
  # log_in より前に読み終えておくこと。
  def log_in(user)
    reset_session
    session[:user_id] = user.id
    session[:issued_at] = Time.current.to_i
    session[:auth_token] = user.session_auth_token
    @current_user = user
  end

  def log_out
    reset_session
    @current_user = nil
  end

  def append_info_to_payload(payload)
    super
    payload[:user_id] = @current_user&.id || session[:user_id]
  end

  private

  def generate_unique_username(email, display_name: nil)
    base_username = display_name&.strip&.presence
    base_username = base_username&.gsub(/[^a-zA-Z0-9_]/, "_")&.[](0..49) if base_username.present?
    if base_username.blank? || base_username.length < 3 || !base_username.match?(/[a-zA-Z0-9]/)
      base_username = email.split("@").first if email.present?
      base_username = "user" if base_username.blank?
      base_username = base_username.gsub(/[^a-zA-Z0-9_]/, "_")[0..49]
      base_username = "user" if base_username.blank?
    end

    max_attempts = 100

    candidates = [ base_username ] + (1..max_attempts).map { |i| "#{base_username}#{i}" }

    existing_usernames = User.where(username: candidates).pluck(:username).to_set

    selected_username = candidates.find { |u| !existing_usernames.include?(u) }

    if selected_username.nil?
      "#{base_username[0..37]}_#{Time.current.to_i}"
    else
      selected_username
    end
  end
end
