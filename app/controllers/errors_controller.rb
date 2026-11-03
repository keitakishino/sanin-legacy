class ErrorsController < ApplicationController
  skip_before_action :authenticate_user! if respond_to?(:authenticate_user!)
  layout "error"

  AUDIT_TIMEOUT_SECONDS = 3

  def unauthorized
    @status_code = 401
    @title = t("errors.unauthorized.title", default: "認証が必要です")
    @message = t("errors.unauthorized.message", default: "このページを表示するにはサインインが必要です")
    @button_path = signin_path
    render :show, status: :unauthorized, formats: [ :html ]
  end

  def forbidden
    @status_code = 403
    @title = t("errors.forbidden.title", default: "アクセスが拒否されました")
    @message = t("errors.forbidden.message", default: "このページにアクセスする権限がありません")
    @button_path = user_signed_in? ? root_path : signin_path
    render :show, status: :forbidden, formats: [ :html ]
  end

  def not_found
    @status_code = 404
    @title = t("errors.not_found.title", default: "ページが見つかりません")
    @message = t("errors.not_found.message", default: "お探しのページは見つかりませんでした")
    @button_path = user_signed_in? ? root_path : signin_path
    render :show, status: :not_found, formats: [ :html ]
  end

  def internal_server_error
    record_internal_server_error
    @status_code = 500
    @title = t("errors.internal_server_error.title", default: "サーバーエラーが発生しました")
    @message = t("errors.internal_server_error.message", default: "しばらくしてからもう一度お試しください")
    @button_path = session[:user_id].present? ? root_path : signin_path
    render :show, status: :internal_server_error, formats: [ :html ]
  end

  private

  def record_internal_server_error
    exception = request.get_header("action_dispatch.exception")
    original = request.get_header("action_dispatch.original_path") || request.path_info
    original_filtered_path = ActionDispatch::Request.new(request.env.merge("PATH_INFO" => original)).filtered_path
    original_request_method = request.get_header("action_dispatch.original_request_method") || request.request_method

    begin
      Timeout.timeout(AUDIT_TIMEOUT_SECONDS) do
        AuditLog.record!(
          user_id: session[:user_id],
          action: "system.error",
          result: :failure,
          status_code: 500,
          request_id: request.request_id,
          details: AuditLog.exception_details(exception, path: original_filtered_path, http_method: original_request_method)
        )
      end
    rescue StandardError => e
      Rails.logger.error("[ErrorsController] audit record failed: #{e.class}: #{e.message}")
    end
  end
end
