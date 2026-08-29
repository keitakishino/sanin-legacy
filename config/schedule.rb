env :PATH, ENV["PATH"]
env :GEM_PATH, ENV["GEM_PATH"]

every 1.day, at: "2:00 am" do
  rake "invitations:expire"
end
