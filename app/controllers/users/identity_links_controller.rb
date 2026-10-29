module Users
  class IdentityLinksController < ApplicationController
    before_action :authenticate_user!

    def create
      session[:oauth_link_user_id] = current_user.id
      redirect_to "/auth/#{params[:provider]}", status: :temporary_redirect
    end
  end
end
