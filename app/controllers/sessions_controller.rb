class SessionsController < ApplicationController
  include RateLimitable

  # パスワードの総当たり・パスワードスプレー対策。
  # ロックアウトは用意していないので、同一 IP からの試行回数だけで絞る。
  rate_limit_auth to: 10, within: 5.minutes, name: "signin",
                  only: :create, with: :rate_limited_response

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

  private

  def rate_limited_response
    render_rate_limited(:new)
  end
end
