class InvitationsEntriesController < ApplicationController
  include RateLimitable

  # 招待コードの総当たり対策。コード自体は 12 桁の英数字で総当たりは現実的でないが、
  # 招待制の入口なので試行回数そのものを絞っておく。
  rate_limit_auth to: 10, within: 10.minutes, name: "invitation-code",
                  only: :create, with: :rate_limited_response

  def new
    @invitation = Invitation.new
  end

  def create
    code = params[:invitation][:code]&.strip

    if code.blank?
      flash.now[:alert] = "招待コードを入力してください"
      @invitation = Invitation.new
      render :new, status: :unprocessable_entity
      return
    end

    invitation = Invitation.find_by_code(code)

    if invitation.blank?
      flash.now[:alert] = "無効な招待コードです"
      @invitation = Invitation.new
      render :new, status: :unprocessable_entity
      return
    end

    unless invitation.available?
      flash.now[:alert] = "この招待コードは使用できません"
      @invitation = Invitation.new
      render :new, status: :unprocessable_entity
      return
    end

    # Use pessimistic lock to prevent race condition: ensures only one request
    # can generate signup_token for the same invitation code even if multiple
    # concurrent requests arrive simultaneously. After acquiring lock, re-check
    # availability to handle edge case where another concurrent request already
    # processed this code between the above check and lock acquisition.
    # If token already exists, return it (idempotent behavior for same code).
    token = invitation.with_lock do
      if invitation.available?
        invitation.signup_token.presence || invitation.generate_signup_token
      else
        nil
      end
    end

    if token.nil?
      flash.now[:alert] = "この招待コードは使用できません"
      @invitation = Invitation.new
      render :new, status: :unprocessable_entity
      return
    end

    redirect_to signup_path(token: token)
  end

  private

  def rate_limited_response
    @invitation = Invitation.new
    render_rate_limited(:new)
  end
end
