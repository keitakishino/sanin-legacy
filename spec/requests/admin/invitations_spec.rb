require "rails_helper"

RSpec.describe "Admin::Invitations", type: :request do
  let(:admin_user) { create(:admin_user, email: "admin@example.com", password: "password123") }
  let(:general_user) { create(:user, email: "user@example.com", password: "password123") }

  describe "GET /admin/invitations" do
    context "when user is not logged in" do
      it "redirects to sign in path" do
        get admin_invitations_path
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        get admin_invitations_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "returns success status" do
        get admin_invitations_path
        expect(response).to have_http_status(:ok)
      end

      it "displays all invitations" do
        create_list(:invitation, 3, issued_by: admin_user)
        get admin_invitations_path
        expect(response.body).to include("招待コード発行")
      end

      it "displays invitations in reverse chronological order" do
        invitation1 = create(:invitation, issued_by: admin_user, created_at: 1.day.ago)
        invitation2 = create(:invitation, issued_by: admin_user, created_at: Time.current)

        get admin_invitations_path
        body = response.body

        pos1 = body.index(invitation1.code)
        pos2 = body.index(invitation2.code)

        expect(pos2).to be < pos1
      end
    end
  end

  describe "POST /admin/invitations" do
    context "when user is not logged in" do
      it "redirects to sign in path" do
        post admin_invitations_path, params: {}
        expect(response).to redirect_to(signin_path)
      end

      it "does not create an invitation" do
        expect {
          post admin_invitations_path, params: {}
        }.not_to change(Invitation, :count)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        post admin_invitations_path, params: {}
        expect(response).to have_http_status(:forbidden)
      end

      it "does not create an invitation" do
        expect {
          post admin_invitations_path, params: {}
        }.not_to change(Invitation, :count)
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "creates an invitation" do
        expect {
          post admin_invitations_path, params: {}
        }.to change(Invitation, :count).by(1)
      end

      it "generates a 12-character alphanumeric code" do
        post admin_invitations_path, params: {}
        invitation = Invitation.last
        expect(invitation.code).to match(/\A[a-zA-Z0-9]{12}\z/)
      end

      it "sets expires_at to 30 days from now" do
        travel_to Time.zone.local(2026, 1, 1, 12, 0, 0) do
          post admin_invitations_path, params: {}
          invitation = Invitation.last
          expect(invitation.expires_at).to be_within(1.minute).of(30.days.from_now)
        end
      end

      it "sets status to active" do
        post admin_invitations_path, params: {}
        invitation = Invitation.last
        expect(invitation.status_active?).to be true
      end

      it "sets issued_by to current admin" do
        post admin_invitations_path, params: {}
        invitation = Invitation.last
        expect(invitation.issued_by_id).to eq(admin_user.id)
      end

      it "responds with html format on success" do
        post admin_invitations_path, params: {}, headers: { "Accept" => "text/html" }
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(admin_invitations_path)
      end

      it "responds with turbo_stream on turbo_stream request" do
        post admin_invitations_path, params: {}, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end

      it "includes prepend action in turbo_stream response" do
        post admin_invitations_path, params: {}, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.body).to include('action="prepend"')
        expect(response.body).to include('target="invitations"')
      end

      it "includes invitation code in turbo_stream response" do
        post admin_invitations_path, params: {}, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        invitation = Invitation.last
        expect(response.body).to include(invitation.code)
      end
    end

    context "when invitation code generation has uniqueness conflict" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "retries and eventually creates an invitation" do
        allow(SecureRandom).to receive(:alphanumeric).and_return("AAAAAAAAAA", "BBBBBBBBBB", "CCCCCCCCCC")

        existing_invitation = create(:invitation, issued_by: admin_user, code: "AAAAAAAAAA")

        expect {
          post admin_invitations_path, params: {}
        }.to change(Invitation, :count).by(1)

        created_invitation = Invitation.last
        expect(created_invitation.code).to eq("BBBBBBBBBB")
      end

      it "fails after max retries" do
        call_count = 0
        allow(SecureRandom).to receive(:alphanumeric) do
          call_count += 1
          "AAAAAAAAAA"
        end

        create(:invitation, issued_by: admin_user, code: "AAAAAAAAAA")

        post admin_invitations_path, params: {}, headers: { "Accept" => "text/html" }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "Admin navigation link" do
    context "when admin is logged in" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "shows admin link in navigation" do
        get root_path
        expect(response.body).to include("招待コード管理")
        expect(response.body).to include(admin_invitations_path)
      end
    end

    context "when general user is logged in" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "does not show admin link in navigation" do
        get root_path
        expect(response.body).not_to include("招待コード管理")
      end
    end

    context "when user is not logged in" do
      it "does not show admin link in navigation" do
        get root_path
        expect(response.body).not_to include("招待コード管理")
      end
    end
  end
end
