namespace :audit do
  desc "対象1件の監査ログ履歴を表示 (例: rake audit:show[Event,17])"
  task :show, [:target_type, :target_id] => :environment do |_t, args|
    if args[:target_type].blank? || args[:target_id].blank?
      warn "Usage: rake audit:show[TargetType,ID]"
      exit(1)
    end

    logs = AuditLog.where(target_type: args[:target_type], target_id: args[:target_id])
                   .includes(:user)
                   .chronological

    if logs.empty?
      puts "該当する監査ログはありません"
    else
      logs.each { |log| puts log.to_line }
    end
  end

  desc "直近N時間の監査ログを表示 (例: rake audit:recent[24])"
  task :recent, [:hours] => :environment do |_t, args|
    hours = (args[:hours].presence || 24).to_i
    logs = AuditLog.where(created_at: hours.hours.ago..)
                   .includes(:user)
                   .chronological

    if logs.empty?
      puts "該当する監査ログはありません"
    else
      logs.each { |log| puts log.to_line }
    end
  end

  desc "失敗した操作の監査ログを表示"
  task failures: :environment do
    logs = AuditLog.result_failure
                   .includes(:user)
                   .chronological

    if logs.empty?
      puts "該当する監査ログはありません"
    else
      logs.each { |log| puts log.to_line }
    end
  end
end
