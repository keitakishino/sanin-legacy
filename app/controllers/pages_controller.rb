class PagesController < ApplicationController
  # Home page is intentionally public to allow both authenticated and unauthenticated users.
  # The view conditionally displays different content based on user_signed_in?.
  def home
  end
end
