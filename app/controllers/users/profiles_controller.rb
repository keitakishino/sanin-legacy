module Users
  class ProfilesController < ApplicationController
    before_action :authenticate_user!

    def show
      @user = current_user
      @twitter_identity = @user.identities.twitter_identities.first
    end

    def edit
      @user = current_user
    end

    def update
      @user = current_user
      if @user.update(profile_update_params)
        redirect_to mypage_path, notice: "プロフィールが更新されました"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def profile_update_params
      params.require(:user).permit(:username, :email, :password, :password_confirmation)
    end
  end
end
