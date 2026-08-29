class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  private

  def require_admin!
    head :forbidden unless current_user&.role_admin?
  end
end
