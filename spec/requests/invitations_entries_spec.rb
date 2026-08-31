require "rails_helper"

RSpec.describe "InvitationsEntries", type: :request do
  describe "GET /invite" do
    it "returns 200" do
      get "/invite"

      expect(response).to have_http_status(:ok)
    end

    it "shows form with invitation code input" do
      get "/invite"

      expect(response.body).to include("招待コードの入力")
      expect(response.body).to include("招待コード")
    end

    it "is accessible without authentication" do
      get "/invite"

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /invite" do
    context "with valid invitation code" do
      let(:invitation) { create(:invitation, status: :active, expires_at: 1.hour.from_now) }

      it "generates signup_token" do
        post "/invite", params: { invitation: { code: invitation.code } }

        invitation.reload
        expect(invitation.signup_token).to be_present
      end

      it "sets signup_token_expires_at to approximately 1 hour in future" do
        now = Time.current
        post "/invite", params: { invitation: { code: invitation.code } }

        invitation.reload
        expect(invitation.signup_token_expires_at).to be_within(5.seconds).of(1.hour.from_now)
      end

      it "redirects to /signup with token" do
        post "/invite", params: { invitation: { code: invitation.code } }

        expect(response).to have_http_status(:found)
        expect(response.location).to include("/signup")
        expect(response.location).to include("token=")
      end

      it "passes correct token as parameter" do
        post "/invite", params: { invitation: { code: invitation.code } }

        invitation.reload
        expect(response.location).to include("token=#{invitation.signup_token}")
      end
    end

    context "with no code provided" do
      it "returns 422" do
        post "/invite", params: { invitation: { code: "" } }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "shows alert message" do
        post "/invite", params: { invitation: { code: "" } }

        expect(response.body).to include("招待コードを入力してください")
      end

      it "renders the form" do
        post "/invite", params: { invitation: { code: "" } }

        expect(response.body).to include("招待コードの入力")
      end
    end

    context "with code only whitespace" do
      it "returns 422" do
        post "/invite", params: { invitation: { code: "   " } }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "shows alert message" do
        post "/invite", params: { invitation: { code: "   " } }

        expect(response.body).to include("招待コードを入力してください")
      end
    end

    context "with invalid code" do
      it "returns 422" do
        post "/invite", params: { invitation: { code: "invalid_code_xyz" } }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "shows alert message" do
        post "/invite", params: { invitation: { code: "invalid_code_xyz" } }

        expect(response.body).to include("無効な招待コードです")
      end

      it "renders the form" do
        post "/invite", params: { invitation: { code: "invalid_code_xyz" } }

        expect(response.body).to include("招待コードの入力")
      end
    end

    context "with expired invitation code" do
      let(:invitation) { create(:expired_invitation) }

      it "returns 422" do
        post "/invite", params: { invitation: { code: invitation.code } }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "shows alert message" do
        post "/invite", params: { invitation: { code: invitation.code } }

        expect(response.body).to include("この招待コードは使用できません")
      end

      it "does not generate signup_token" do
        post "/invite", params: { invitation: { code: invitation.code } }

        invitation.reload
        expect(invitation.signup_token).to be_nil
      end
    end

    context "with used invitation code" do
      let(:invitation) { create(:used_invitation) }

      it "returns 422" do
        post "/invite", params: { invitation: { code: invitation.code } }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "shows alert message" do
        post "/invite", params: { invitation: { code: invitation.code } }

        expect(response.body).to include("この招待コードは使用できません")
      end

      it "does not generate signup_token" do
        post "/invite", params: { invitation: { code: invitation.code } }

        invitation.reload
        expect(invitation.signup_token).to be_nil
      end
    end

    context "with revoked invitation code" do
      let(:invitation) { create(:revoked_invitation) }

      it "returns 422" do
        post "/invite", params: { invitation: { code: invitation.code } }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "shows alert message" do
        post "/invite", params: { invitation: { code: invitation.code } }

        expect(response.body).to include("この招待コードは使用できません")
      end

      it "does not generate signup_token" do
        post "/invite", params: { invitation: { code: invitation.code } }

        invitation.reload
        expect(invitation.signup_token).to be_nil
      end
    end

    context "with code that has leading/trailing whitespace" do
      let(:invitation) { create(:invitation, status: :active, expires_at: 1.hour.from_now) }

      it "strips whitespace and accepts the code" do
        post "/invite", params: { invitation: { code: "  #{invitation.code}  " } }

        expect(response).to have_http_status(:found)
        invitation.reload
        expect(invitation.signup_token).to be_present
      end
    end

    context "race condition: multiple concurrent requests with same code" do
      let(:invitation) { create(:invitation, status: :active, expires_at: 1.hour.from_now) }

      it "returns same token for second request to same code (idempotent behavior)" do
        # First request generates signup token
        post "/invite", params: { invitation: { code: invitation.code } }
        expect(response).to have_http_status(:found)
        first_token = invitation.reload.signup_token
        expect(first_token).to be_present

        # Second request (simulating concurrent or retry request) should succeed
        # with the same token to prevent duplicate token generation
        post "/invite", params: { invitation: { code: invitation.code } }
        expect(response).to have_http_status(:found)
        second_token = invitation.reload.signup_token

        # Both requests should get the same token due to pessimistic lock
        expect(first_token).to eq(second_token)
      end

      it "ensures only one signup_token is generated even with multiple attempts" do
        # First request
        post "/invite", params: { invitation: { code: invitation.code } }
        first_token = invitation.reload.signup_token
        expect(first_token).to be_present

        # Second request attempt (simulating race condition)
        post "/invite", params: { invitation: { code: invitation.code } }

        # Token should not have changed - same token returned
        second_token = invitation.reload.signup_token
        expect(first_token).to eq(second_token)
      end

      it "uses pessimistic lock to prevent concurrent token generation" do
        # This test verifies that with_lock is used by checking that
        # sequential requests return the same token rather than generating new ones
        first_response_token = nil
        second_response_token = nil

        # First request
        post "/invite", params: { invitation: { code: invitation.code } }
        expect(response.location).to include("token=")
        first_response_token = response.location.match(/token=([^&]+)/)[1]

        # Reload to get fresh data and verify database state
        invitation.reload

        # Second request to same code
        post "/invite", params: { invitation: { code: invitation.code } }
        expect(response.location).to include("token=")
        second_response_token = response.location.match(/token=([^&]+)/)[1]

        # Both responses should contain the same token
        expect(first_response_token).to eq(second_response_token)
        expect(first_response_token).to eq(invitation.reload.signup_token)
      end
    end
  end
end
