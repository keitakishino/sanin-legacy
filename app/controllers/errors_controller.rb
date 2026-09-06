class ErrorsController < ApplicationController
  skip_before_action :authenticate_user! if respond_to?(:authenticate_user!)
  layout "error"

  def unauthorized
    @status_code = 401
    @title = t("errors.unauthorized.title", default: "認証が必要です")
    @message = t("errors.unauthorized.message", default: "このページを表示するにはサインインが必要です")
    @button_path = signin_path
    render :show, status: :unauthorized
  end

  def forbidden
    @status_code = 403
    @title = t("errors.forbidden.title", default: "アクセスが拒否されました")
    @message = t("errors.forbidden.message", default: "このページにアクセスする権限がありません")
    @button_path = user_signed_in? ? root_path : signin_path
    render :show, status: :forbidden
  end

  def not_found
    @status_code = 404
    @title = t("errors.not_found.title", default: "ページが見つかりません")
    @message = t("errors.not_found.message", default: "お探しのページは見つかりませんでした")
    @button_path = user_signed_in? ? root_path : signin_path
    render :show, status: :not_found
  end
end
