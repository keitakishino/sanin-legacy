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

    token = invitation.generate_signup_token
    redirect_to signup_path(token: token)
  end
end
