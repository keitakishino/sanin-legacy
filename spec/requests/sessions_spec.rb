require "rails_helper"

RSpec.describe "Sessions Controller", type: :request do
  let(:user) { create(:user, email: "test@example.com", password: "password123") }

  describe "User Factory" do
    it "creates a user with correct email and password" do
      test_user = build(:user, email: "factory@example.com", password: "password123")
      test_user.save!

      fetched_user = User.find_by(email: "factory@example.com")
      expect(fetched_user).to be_present
      expect(fetched_user.authenticate("password123")).to be_truthy
    end
  end

  describe "Sign In" do
    it "displays the sign in form" do
      get signin_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sign In")
      expect(response.body).to include('type="email"')
      expect(response.body).to include('type="password"')
    end
  end

  describe "Sign In with valid credentials" do
    it "logs in the user and redirects to root" do
      post signin_path, params: { email: user.email, password: "password123" }
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "sets the session[:user_id]" do
      post signin_path, params: { email: user.email, password: "password123" }
      expect(session[:user_id]).to eq(user.id)
    end

    it "shows the user is logged in on the home page" do
      post signin_path, params: { email: user.email, password: "password123" }
      follow_redirect!
      expect(response.body).to include(user.username)
      expect(response.body).to include("Signout")
    end
  end

  describe "Sign In with invalid email" do
    it "does not log in and shows error message" do
      post signin_path, params: { email: "nonexistent@example.com", password: "password123" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("メールアドレスまたはパスワードが正しくありません")
      expect(session[:user_id]).to be_nil
    end
  end

  describe "Sign In with invalid password" do
    it "does not log in and shows error message" do
      post signin_path, params: { email: user.email, password: "wrongpassword" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("メールアドレスまたはパスワードが正しくありません")
      expect(session[:user_id]).to be_nil
    end
  end

  describe "Sign Out" do
    before do
      post signin_path, params: { email: user.email, password: "password123" }
    end

    it "logs out the user and clears the session" do
      delete signout_path
      expect(session[:user_id]).to be_nil
    end

    it "redirects to the sign in page" do
      delete signout_path
      expect(response).to redirect_to(signin_path)
    end

    it "shows sign in link after logout" do
      delete signout_path
      follow_redirect!
      expect(response.body).to include("Sign In")
      expect(response.body).not_to include("Signout")
    end
  end

  describe "Session persistence" do
    before do
      post signin_path, params: { email: user.email, password: "password123" }
    end

    it "maintains login across requests" do
      get root_path
      expect(response.body).to include(user.username)
      expect(response.body).to include("Signout")

      get root_path
      expect(response.body).to include(user.username)
      expect(response.body).to include("Signout")
    end
  end
end
