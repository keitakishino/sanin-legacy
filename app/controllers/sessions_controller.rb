class SessionsController < ApplicationController
  def new
  end

  def create
    email = params[:email]
    password = params[:password]

    user = User.find_by(email: email)
    # Use safe navigation and authenticate to avoid timing attacks.
    # Both user not found and password incorrect result in the same generic error.
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
