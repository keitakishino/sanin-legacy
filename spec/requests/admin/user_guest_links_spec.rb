require "rails_helper"

RSpec.describe "Admin::UserGuestLinks", type: :request do
  let(:admin_user) { create(:admin_user, email: "admin@example.com", password: "password123") }
  let(:general_user) { create(:user, email: "user@example.com", password: "password123") }
  let(:target_user) { create(:user, email: "target@example.com", password: "password123") }

  describe "GET /admin/users/:user_id/guest_link/new" do
    context "when user is not logged in" do
      it "redirects to sign in path" do
        get new_admin_user_guest_link_path(target_user)
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        get new_admin_user_guest_link_path(target_user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "returns success status" do
        get new_admin_user_guest_link_path(target_user)
        expect(response).to have_http_status(:ok)
      end

      it "displays the modal frame and search form" do
        get new_admin_user_guest_link_path(target_user)
        expect(response.body).to include('turbo-frame id="guest_link_modal"')
        expect(response.body).to include("自由入力の名前")
        expect(response.body).to include("検索")
      end
    end
  end

  describe "POST /admin/users/:user_id/guest_link" do
    context "when user is not logged in" do
      it "redirects to sign in path" do
        post admin_user_guest_link_path(target_user), params: { guest_name_key: "やまだ" }
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        post admin_user_guest_link_path(target_user), params: { guest_name_key: "やまだ" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      context "with valid guest participant" do
        let!(:event) { create(:event, event_type: :proxy_order, title: "テスト通販", created_by: admin_user) }
        let!(:proxy_order) { create(:proxy_order, event:) }
        let!(:participant) { create(:proxy_order_participant, :guest, proxy_order:, guest_name: "やまだ") }

        it "links the participant successfully" do
          post admin_user_guest_link_path(target_user),
               params: { guest_name_key: "やまだ" },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response).to have_http_status(:ok)
          expect(response.body).to include('target="guest_link_modal"')
          expect(response.body).to include('target="toast-container"')

          participant.reload
          expect(participant.user_id).to eq(target_user.id)
          expect(participant.guest_name).to be_nil
        end

        it "includes the success message in turbo_stream response" do
          post admin_user_guest_link_path(target_user),
               params: { guest_name_key: "やまだ" },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response.body).to include("やまだ")
          expect(response.body).to include("紐づけました")
        end
      end

      context "with conflict" do
        let!(:event) { create(:event, event_type: :proxy_order, title: "テスト通販", created_by: admin_user) }
        let!(:proxy_order) { create(:proxy_order, event:) }
        let!(:guest_participant) { create(:proxy_order_participant, :guest, proxy_order:, guest_name: "たなべ") }
        let!(:user_participant) { create(:proxy_order_participant, proxy_order:, user: target_user) }

        it "returns unprocessable entity status with error message" do
          post admin_user_guest_link_path(target_user),
               params: { guest_name_key: "たなべ" }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include("guest_link_errors")
          expect(response.body).to include("すでに参加しています")
        end

        it "does not update the guest participant" do
          post admin_user_guest_link_path(target_user),
               params: { guest_name_key: "たなべ" }

          guest_participant.reload
          expect(guest_participant.user_id).to be_nil
          expect(guest_participant.guest_name).to eq("たなべ")
        end
      end
    end
  end
end
