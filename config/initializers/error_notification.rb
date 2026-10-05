# Error reporting is unified under Rails.error, and external notifications are sent via this subscription only.
# To switch notification services, replace the subscription handler.

Rails.application.config.after_initialize do
  Rails.error.subscribe(ErrorNotification::Subscriber.new)
end
