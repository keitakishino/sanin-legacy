class OmniauthCallbacksController < ApplicationController
  def google
    auth_hash = request.env["omniauth.auth"]
    if auth_hash.blank?
      flash[:alert] = "OAuth認可に失敗しました"
      redirect_to signin_path
      return
    end

    uid = auth_hash["uid"]
    email = auth_hash["info"]["email"]

    identity = Identity.find_by(provider: :google, uid: uid)

    if identity.present?
      user = identity.user
      log_in(user)
      redirect_to root_path
    else
      user = create_user_from_oauth(email)
      if user.persisted?
        identity = create_identity_for_user(user, :google, uid)
        log_in(user)
        redirect_to root_path
      else
        flash[:alert] = "ユーザー作成に失敗しました"
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
    User.create(
      username: username,
      email: email,
      password: SecureRandom.hex(16),
      password_confirmation: SecureRandom.hex(16),
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

    existing_username = base_username
    counter = 1
    while User.exists?(username: existing_username)
      existing_username = "#{base_username}#{counter}"
      counter += 1
    end

    existing_username
  end
end
