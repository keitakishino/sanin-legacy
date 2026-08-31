class InvitationsEntriesController < ApplicationController
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
end
