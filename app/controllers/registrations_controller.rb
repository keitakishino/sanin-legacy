class RegistrationsController < ApplicationController
  def new
    token = params[:token]

    if token.blank?
      render_forbidden
      return
    end

    invitation = Invitation.find_by_signup_token(token)

    if invitation.blank? || !invitation.available?
      render_forbidden
      return
    end

    session[:signup_token] = token
    @invitation = invitation
  end

  def create
    token = session[:signup_token]

    if token.blank?
      render_forbidden
      return
    end

    invitation = Invitation.find_by_signup_token(token)

    if invitation.blank? || !invitation.available?
      render_forbidden
      return
    end

    auth_method = params[:auth_method]

    case auth_method
    when "email"
      handle_email_signup(invitation)
    when "google", "twitter"
      handle_oauth_signup(auth_method)
    else
      flash.now[:alert] = "無効な認証方式です"
      render :new, status: :unprocessable_entity
    end
  end

  private

  def handle_email_signup(invitation)
    email = params[:email]
    password = params[:password]
    password_confirmation = params[:password_confirmation]

    user = User.new(
      email: email,
      password: password,
      password_confirmation: password_confirmation,
      role: :general
    )

    username = generate_unique_username(email)
    user.username = username

    begin
      user.save!
      invitation.use_by(user)
      log_in(user)
      session.delete(:signup_token)
      redirect_to root_path
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = build_error_message(e.record)
      render :new, status: :unprocessable_entity
    end
  end

  def handle_oauth_signup(provider)
    redirect_to "/auth/#{provider}", allow_other_host: true
  end

  def generate_unique_username(email)
    base_username = email.split("@").first if email.present?
    base_username = "user" if base_username.blank?

    base_username = base_username.gsub(/[^a-zA-Z0-9_]/, "_")[0..49]
    base_username = "user" if base_username.blank?

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

  def build_error_message(record)
    errors = record.errors
    if errors.key?(:username)
      "ユーザー作成に失敗しました（ユーザー名: #{errors[:username].join(', ')}）"
    elsif errors.key?(:email)
      "ユーザー作成に失敗しました（メール: #{errors[:email].join(', ')}）"
    elsif errors.key?(:password)
      "ユーザー作成に失敗しました（パスワード: #{errors[:password].join(', ')}）"
    else
      "ユーザー作成に失敗しました（#{errors.full_messages.join(', ')}）"
    end
  end

  def render_forbidden
    head :forbidden
  end
end
