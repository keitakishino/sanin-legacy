class OmniauthCallbacksController < ApplicationController
  def create
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

    provider = auth_hash.dig("provider")
    email = auth_hash.dig("info", "email")

    link_user_id = session.delete(:oauth_link_user_id)
    if link_user_id.present? && user_signed_in? && current_user.id == link_user_id
      link_identity_to(current_user, provider, uid)
      return
    end

    identity = Identity.find_by(provider: provider, uid: uid)

    if identity.present?
      user = identity.user
      handle_signup_token_if_present(user)
      log_in(user)
      redirect_to root_path
    else
      unless signup_invitation_available?
        flash[:alert] = "未登録の外部アカウントです。招待コードを入力して登録してください。"
        redirect_to signin_path
        return
      end

      begin
        user = nil
        ActiveRecord::Base.transaction do
          user = create_user_from_oauth(email)
          create_identity_for_user(user, provider, uid)
          handle_signup_token_if_present(user)
        end
        log_in(user)
        redirect_to root_path
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
        # Transaction has been rolled back, so no orphaned User remains
        # TOCTOU race condition: another request may have created the identity
        existing_identity = Identity.find_by(provider: provider, uid: uid)
        if existing_identity
          # Log in with the user linked to the existing identity
          handle_signup_token_if_present(existing_identity.user)
          log_in(existing_identity.user)
          redirect_to root_path
        else
          # Other validation error occurred
          if e.is_a?(ActiveRecord::RecordInvalid)
            flash[:alert] = build_error_message(e.record)
          else
            flash[:alert] = "ユーザー作成に失敗しました（username重複。別の方法で再試行してください）"
          end
          redirect_to signin_path
        end
      end
    end
  end

  def failure
    session.delete(:oauth_link_user_id)
    flash[:alert] = "OAuth認可がキャンセルされました"
    redirect_to signin_path
  end

  private

  def handle_signup_token_if_present(user)
    token = session[:signup_token]
    return unless token.present?

    invitation = Invitation.find_by_signup_token(token)
    if invitation.present? && invitation.available?
      invitation.use_by(user)
    end
    session.delete(:signup_token)
  end

  def create_user_from_oauth(email)
    username = generate_unique_username(email)
    User.create!(
      username: username,
      email: email,
      role: :general
    )
  end

  def create_identity_for_user(user, provider, uid)
    user.identities.create!(provider: provider, uid: uid)
  end

  def link_identity_to(user, provider, uid)
    name = Identity.new(provider: provider).provider_display_name
    existing = Identity.find_by(provider: provider, uid: uid)

    if existing.present? && existing.user_id != user.id
      flash[:alert] = "この#{name}アカウントはすでに別のユーザーに連携されているため、連携できません。"
      redirect_to mypage_path
    elsif existing.present? || user.identities.exists?(provider: provider)
      flash[:notice] = "#{name}アカウントはすでに連携済みです。"
      redirect_to mypage_path
    else
      begin
        user.identities.create!(provider: provider, uid: uid)
        flash[:notice] = "#{name}アカウントを連携しました。"
        redirect_to mypage_path
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        flash[:alert] = "この#{name}アカウントはすでに別のユーザーに連携されているため、連携できません。"
        redirect_to mypage_path
      end
    end
  end

  def signup_invitation_available?
    token = session[:signup_token]
    return false unless token.present?

    invitation = Invitation.find_by_signup_token(token)
    if invitation.present? && invitation.available?
      true
    else
      session.delete(:signup_token)
      false
    end
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
