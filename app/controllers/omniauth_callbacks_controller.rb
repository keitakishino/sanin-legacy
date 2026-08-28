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
        user = nil
        ActiveRecord::Base.transaction do
          user = create_user_from_oauth(email)
          create_identity_for_user(user, :google, uid)
        end
        log_in(user)
        redirect_to root_path
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
        # Transaction has been rolled back, so no orphaned User remains
        # TOCTOU race condition: another request may have created the identity
        existing_identity = Identity.find_by(provider: :google, uid: uid)
        if existing_identity
          # Log in with the user linked to the existing identity
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
    user.identities.create!(provider: provider, uid: uid)
  end

  def generate_unique_username(email)
    base_username = email.split("@").first if email.present?
    base_username = "user" if base_username.blank?

    base_username = base_username.gsub(/[^a-zA-Z0-9_]/, "_")[0..49]
    base_username = "user" if base_username.blank?

    max_attempts = 100

    # Generate all candidate usernames (base + numbered variants)
    candidates = [ base_username ] + (1..max_attempts).map { |i| "#{base_username}#{i}" }

    # Fetch existing usernames in a single query (addresses N+1 issue)
    existing_usernames = User.where(username: candidates).pluck(:username).to_set

    # Find the first non-existing username
    selected_username = candidates.find { |u| !existing_usernames.include?(u) }

    if selected_username.nil?
      # All attempts exhausted, use timestamp-based fallback
      # Trim base_username to ensure final username doesn't exceed 50 chars:
      # base_username (37) + "_" (1) + timestamp (10) = 48 chars (with 2 char margin)
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
    else
      "ユーザー作成に失敗しました（#{errors.full_messages.join(', ')}）"
    end
  end
end
