class Admin::AuditLogsController < Admin::BaseController
  PER_PAGE = 50

  def index
    logs = AuditLog.includes(:user).recent_first
    logs = logs.where(result: params[:result]) if AuditLog.results.key?(params[:result])
    logs = logs.where(target_type: params[:target_type]) if params[:target_type].present?
    logs = logs.where(target_id: params[:target_id]) if params[:target_id].to_s.match?(/\A\d+\z/)
    @audit_logs = logs.page(params[:page]).per(PER_PAGE)
    @target_types = AuditLog.where.not(target_type: nil).distinct.order(:target_type).pluck(:target_type)
  end
end
