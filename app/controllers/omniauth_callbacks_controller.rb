class OmniauthCallbacksController < ApplicationController
  def google
    auth_hash = request.env["omniauth.auth"]
    if auth_hash.blank?
      flash[:alert] = "OAuth認可に失敗しました"
      redirect_to signin_path
      return
    end

    uid = auth_hash.dig("uid")
    if uid.blank?
      flash[:alert] = "OAuth認可に失敗しました（ユーザーID取得エラー）"
      redirect_to signin_path
      return
    end

    email = auth_hash.dig("info", "email")

    identity = Identity.find_by(provider: :google, uid: uid)

    if identity.present?
      user = identity.user
      log_in(user)
      redirect_to root_path
    else
      begin
        user = create_user_from_oauth(email)
        identity = create_identity_for_user(user, :google, uid)
        log_in(user)
        redirect_to root_path
      rescue ActiveRecord::RecordInvalid => e
        flash[:alert] = build_error_message(e.record)
        redirect_to signin_path
      rescue ActiveRecord::RecordNotUnique => e
        flash[:alert] = "ユーザー作成に失敗しました（username重複。別の方法で再試行してください）"
        redirect_to signin_path
      end
    end
  end

  def failure
    flash[:alert] = "OAuth認可がキャンセルされました"
    redirect_to signin_path
  end

  private

  def create_user_from_oauth(email)
    username = generate_unique_username(email)
    User.create!(
      username: username,
      email: email,
      role: :general
    )
  end

  def create_identity_for_user(user, provider, uid)
    user.identities.create(provider: provider, uid: uid)
  end

  def generate_unique_username(email)
    base_username = email.split("@").first if email.present?
    base_username = "user" if base_username.blank?

    base_username = base_username.gsub(/[^a-zA-Z0-9_]/, "_")[0..49]
    base_username = "user" if base_username.blank?

    candidate_username = base_username
    counter = 1
    max_attempts = 100

    while counter <= max_attempts && User.exists?(username: candidate_username)
      candidate_username = "#{base_username}#{counter}"
      counter += 1
    end

    # If all attempts exhausted, use timestamp-based fallback
    counter > max_attempts ? "#{base_username}_#{Time.current.to_i}" : candidate_username
  end

  def build_error_message(record)
    errors = record.errors
    if errors.key?(:username)
      "ユーザー作成に失敗しました（ユーザー名: #{errors[:username].join(', ')}）"
    elsif errors.key?(:email)
      "ユーザー作成に失敗しました（メール: #{errors[:email].join(', ')}）"
    else
      "ユーザー作成に失敗しました（#{errors.full_messages.join(', ')}）"
    end
  end
end
