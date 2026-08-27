# Disable or configure host authorization for test environment
if Rails.env.test?
  # Set empty hosts list to allow all hosts
  Rails.application.config.hosts = []
end
