# Whenever gem schedule configuration
# Note: On production deployment or initial setup, run `bundle exec whenever --update-crontab`
# to register these scheduled tasks with the system crontab.
# For Kamal deployment integration, consider adding this to the deployment hook (future enhancement).

env :PATH, ENV["PATH"]
env :GEM_PATH, ENV["GEM_PATH"]

every 1.day, at: "2:00 am" do
  rake "invitations:expire"
end
