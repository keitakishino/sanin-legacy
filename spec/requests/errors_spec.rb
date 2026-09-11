require "rails_helper"

RSpec.describe "Errors", type: :request do
  describe "GET /errors/unauthorized" do
    it "returns 401" do
      get "/errors/unauthorized"
      expect(response).to have_http_status(:unauthorized)
    end

    it "displays error title" do
      get "/errors/unauthorized"
      expect(response.body).to include("認証が必要です")
    end

    it "displays error message" do
      get "/errors/unauthorized"
      expect(response.body).to include("サインインが必要です")
    end

    it "displays signin link" do
      get "/errors/unauthorized"
      expect(response.body).to include(signin_path)
    end

    it "uses error layout" do
      get "/errors/unauthorized"
      expect(response.body).not_to include("<header")
    end
  end

  describe "GET /errors/forbidden" do
    context "when user is not signed in" do
      it "returns 403" do
        get "/errors/forbidden"
        expect(response).to have_http_status(:forbidden)
      end

      it "displays error title" do
        get "/errors/forbidden"
        expect(response.body).to include("アクセスが拒否されました")
      end

      it "redirects to signin when clicking button" do
        get "/errors/forbidden"
        expect(response.body).to include(signin_path)
      end
    end

    context "when user is signed in" do
      let(:user) { create(:user, role: :general) }

      before do
        post "/signin", params: { email: user.email, password: user.password }
      end

      it "returns 403" do
        get "/errors/forbidden"
        expect(response).to have_http_status(:forbidden)
      end

      it "displays error title" do
        get "/errors/forbidden"
        expect(response.body).to include("アクセスが拒否されました")
      end

      it "redirects to root when clicking button" do
        get "/errors/forbidden"
        expect(response.body).to include(root_path)
      end
    end
  end

  describe "GET /errors/not_found" do
    context "when user is not signed in" do
      it "returns 404" do
        get "/errors/not_found"
        expect(response).to have_http_status(:not_found)
      end

      it "displays error title" do
        get "/errors/not_found"
        expect(response.body).to include("ページが見つかりません")
      end

      it "displays error message" do
        get "/errors/not_found"
        expect(response.body).to include("見つかりませんでした")
      end

      it "redirects to signin when clicking button" do
        get "/errors/not_found"
        expect(response.body).to include(signin_path)
      end
    end

    context "when user is signed in" do
      let(:user) { create(:user, role: :general) }

      before do
        post "/signin", params: { email: user.email, password: user.password }
      end

      it "returns 404" do
        get "/errors/not_found"
        expect(response).to have_http_status(:not_found)
      end

      it "displays error title" do
        get "/errors/not_found"
        expect(response.body).to include("ページが見つかりません")
      end

      it "redirects to root when clicking button" do
        get "/errors/not_found"
        expect(response.body).to include(root_path)
      end
    end
  end

  describe "Accessing undefined routes (404 via wildcard)" do
    it "returns 404 for undefined path" do
      get "/undefined/path/that/does/not/exist"
      expect(response).to have_http_status(:not_found)
    end

    it "displays 404 error page" do
      get "/undefined/path"
      expect(response.body).to include("ページが見つかりません")
    end
  end

  describe "Accessing static files through wildcard route" do
    it "returns 404 for favicon.svg (not found)" do
      get "/favicon.svg"
      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include("text/html")
      expect(response.body).to include("ページが見つかりません")
    end

    it "returns 404 for icon.png (routed via catch-all)" do
      get "/icon.png"
      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include("text/html")
    end

    it "returns 404 for robots.txt (routed via catch-all)" do
      get "/robots.txt"
      expect(response).to have_http_status(:not_found)
      expect(response.content_type).to include("text/html")
    end
  end

  describe "public/500.html" do
    it "file exists and contains error message" do
      file_path = Rails.root.join("public", "500.html")
      expect(File.exist?(file_path)).to be true
      content = File.read(file_path)
      expect(content).to include("500")
      expect(content).to include("エラーが発生しました")
    end
  end

  describe "Forbidden error via ForbiddenError exception" do
    context "when admin checks fail" do
      let(:user) { create(:user, role: :general) }

      before do
        post "/signin", params: { email: user.email, password: user.password }
      end

      it "raises ForbiddenError for non-admin users accessing admin pages" do
        # This assumes an admin page exists; using a real admin route
        # Admin pages should return 403 when accessed by non-admins
        get "/admin/users"
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "Forbidden error via registrations#new with invalid token" do
    it "returns 403 when no token is provided" do
      get "/signup"
      expect(response).to have_http_status(:forbidden)
    end

    it "shows forbidden error page" do
      get "/signup"
      expect(response.body).to include("アクセスが拒否されました")
    end
  end
end
