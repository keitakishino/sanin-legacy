namespace :invitations do
  desc "Expire active invitation codes that have passed their expiration date"
  task expire: :environment do
    count = Invitation.where(status: :active).where("expires_at < ?", Time.current).count
    Invitation.expire_old_codes
    puts "Expired #{count} invitation codes"
  end
end
