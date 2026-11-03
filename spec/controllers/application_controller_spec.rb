require "rails_helper"

# セッションの中身を直接組み立てて、失効判定の入口（discard_invalid_session）を確かめる。
# リクエストスペックからは「user_id だけが入ったセッション」を作れないため、
# ここだけコントローラスペックを使う。
RSpec.describe ApplicationController, type: :controller do
  controller do
    before_action :authenticate_user!

    def index
      render plain: "signed in"
    end
  end

  let(:user) { create(:user, email: "guarded@example.com", password: "password123") }

  describe "#discard_invalid_session" do
    it "user_id・issued_at・auth_token がそろっていれば通す" do
      session[:user_id] = user.id
      session[:issued_at] = Time.current.to_i
      session[:auth_token] = user.session_auth_token

      get :index

      expect(response).to have_http_status(:ok)
      expect(session[:user_id]).to eq(user.id)
    end

    it "issued_at を持たない（この対応より前に発行された）セッションは通さない" do
      session[:user_id] = user.id
      session[:auth_token] = user.session_auth_token

      get :index

      expect(response).to redirect_to(signin_path)
      expect(session[:user_id]).to be_nil
    end

    it "auth_token を持たないセッションは通さない" do
      session[:user_id] = user.id
      session[:issued_at] = Time.current.to_i

      get :index

      expect(response).to redirect_to(signin_path)
      expect(session[:user_id]).to be_nil
    end

    it "auth_token が現在の値と合わないセッションは通さない" do
      session[:user_id] = user.id
      session[:issued_at] = Time.current.to_i
      session[:auth_token] = "stale-token"

      get :index

      expect(response).to redirect_to(signin_path)
      expect(session[:user_id]).to be_nil
    end

    it "サインインしていないときはセッションに触らない" do
      session[:cart] = "keep-me"

      get :index

      expect(response).to redirect_to(signin_path)
      expect(session[:cart]).to eq("keep-me")
    end
  end
end
