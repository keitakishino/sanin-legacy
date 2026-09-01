require "rails_helper"

RSpec.describe "Authentication helpers", type: :request do
  let(:user) { create(:user, email: "test@example.com", password: "password123") }

  before do
    # Ensure host is set correctly for request specs
    host! "www.example.com"
  end

  describe "current_user helper" do
    it "returns nil when not logged in" do
      get root_path
      follow_redirect!
      expect(response.body).to include("Sign In")
      expect(response.body).not_to include("Signout")
    end

    it "returns the logged-in user after sign in" do
      post signin_path, params: { email: user.email, password: "password123" }
      follow_redirect!
      expect(response.body).to include(user.username)
      expect(response.body).to include("Signout")
    end

    it "displays current user in header when logged in" do
      post signin_path, params: { email: user.email, password: "password123" }
      get root_path
      expect(response.body).to include(user.username)
      expect(response.body).to include("Signout")
    end

    it "clears current_user after logout" do
      post signin_path, params: { email: user.email, password: "password123" }
      delete signout_path
      get root_path
      follow_redirect!
      expect(response.body).to include("Sign In")
      expect(response.body).not_to include("Signout")
    end
  end

  describe "user_signed_in? helper" do
    it "returns false when not logged in" do
      get root_path
      follow_redirect!
      expect(response.body).to include("Sign In")
      expect(response.body).not_to include("Signout")
    end

    it "returns true when logged in" do
      post signin_path, params: { email: user.email, password: "password123" }
      get root_path
      expect(response.body).to include("Signout")
      expect(response.body).not_to include("Sign In")
    end

    it "returns false after logout" do
      post signin_path, params: { email: user.email, password: "password123" }
      delete signout_path
      get root_path
      follow_redirect!
      expect(response.body).to include("Sign In")
      expect(response.body).not_to include("Signout")
    end
  end

  describe "authenticate_user! filter" do
    it "is available as a private method on ApplicationController" do
      expect(ApplicationController.private_method_defined?(:authenticate_user!)).to be true
    end
  end

  describe "Authentication workflow" do
    it "complete sign in and sign out flow works correctly" do
      # Start unauthenticated
      get root_path
      follow_redirect!
      expect(response.body).to include("Sign In")

      # Sign in
      post signin_path, params: { email: user.email, password: "password123" }
      expect(response).to redirect_to(root_path)

      # Verify logged in
      follow_redirect!
      expect(response.body).to include(user.username)
      expect(response.body).to include("Signout")
      expect(session[:user_id]).to eq(user.id)

      # Sign out
      delete signout_path
      expect(response).to redirect_to(signin_path)

      # Verify logged out
      follow_redirect!
      expect(response.body).to include("Sign In")
      expect(session[:user_id]).to be_nil
    end
  end
end
