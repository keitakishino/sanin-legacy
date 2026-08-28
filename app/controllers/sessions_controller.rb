class SessionsController < ApplicationController
  def new
  end

  def create
    email = params[:email] || params["email"]
    password = params[:password] || params["password"]

    # Log debug info to response for testing
    if Rails.env.test?
      @debug_email = email.inspect
      @debug_password = password.inspect
      @debug_all_params = params.except(:controller, :action, :authenticity_token).inspect
    end

    user = User.find_by(email: email)
    if user&.authenticate(password)
      log_in(user)
      redirect_to root_path
    else
      flash.now[:alert] = "メールアドレスまたはパスワードが正しくありません"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    log_out
    redirect_to signin_path
  end
end
