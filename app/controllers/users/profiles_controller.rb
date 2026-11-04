module Users
  class ProfilesController < ApplicationController
    before_action :authenticate_user!
    around_action :set_locale_to_japanese

    def show
      @user = current_user
    end

    def edit
      @user = current_user
    end

    def update
      @user = current_user
      user_params = profile_update_params

      # Validate current_password if password is being changed
      if user_params[:password].present?
        current_password = params.dig(:user, :current_password)
        if current_password.blank?
          @user.errors.add(:current_password, I18n.t("activerecord.errors.models.user.attributes.current_password.blank"))
          render :edit, status: :unprocessable_entity
          return
        end

        unless @user.authenticate(current_password)
          @user.errors.add(:current_password, I18n.t("activerecord.errors.models.user.attributes.current_password.invalid"))
          render :edit, status: :unprocessable_entity
          return
        end
      end

      if @user.update(user_params)
        # パスワードを変えると session_auth_token が変わり、発行済みのセッションは
        # すべて失効する。操作中の本人まで締め出さないよう、ここで発行し直す。
        log_in(@user) if @user.saved_change_to_password_digest?
        redirect_to mypage_path, notice: "プロフィールが更新されました"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_locale_to_japanese
      I18n.with_locale(:ja) { yield }
    end

    def profile_update_params
      user_params = params.require(:user).permit(:username, :email, :password, :password_confirmation)
      # Convert empty email to nil
      user_params[:email] = nil if user_params[:email].blank?
      user_params
    end
  end
end
