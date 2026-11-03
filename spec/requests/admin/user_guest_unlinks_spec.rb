require "rails_helper"

RSpec.describe "Admin::UserGuestUnlinks", type: :request do
  let(:admin_user) { create(:admin_user, email: "admin@example.com", password: "password123") }
  let(:general_user) { create(:user, email: "user@example.com", password: "password123") }
  let(:target_user) { create(:user, email: "target@example.com", password: "password123", username: "target_user") }

  describe "GET /admin/users/:user_id/guest_unlink/new" do
    context "when user is not logged in" do
      it "redirects to sign in path" do
        get new_admin_user_guest_unlink_path(target_user, name_key: "やまだ")
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        get new_admin_user_guest_unlink_path(target_user, name_key: "やまだ")
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      context "with valid linked participant" do
        let!(:event) { create(:event, event_type: :proxy_order, title: "テスト通販", created_by: admin_user) }
        let!(:proxy_order) { create(:proxy_order, event:) }
        let!(:participant) { create(:proxy_order_participant, proxy_order:, user: target_user, linked_from_guest_name: "やまだ") }

        it "returns success status and displays unlink confirmation modal" do
          get new_admin_user_guest_unlink_path(target_user, name_key: "やまだ")
          expect(response).to have_http_status(:ok)
          expect(response.body).to include('turbo-frame id="guest_link_modal"')
          expect(response.body).to include("「やまだ」の 1 件を自由入力に戻します。")
          expect(response.body).to include(target_user.username)
          expect(response.body).to include("解除する")
        end
      end

      context "with unlinked name key" do
        it "displays error message" do
          get new_admin_user_guest_unlink_path(target_user, name_key: "やまだ")
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("紐づけ済みの自由入力が見つかりません")
          expect(response.body).not_to include("解除する")
        end
      end
    end
  end

  describe "POST /admin/users/:user_id/guest_unlink" do
    context "when user is not logged in" do
      it "redirects to sign in path" do
        post admin_user_guest_unlink_path(target_user), params: { name_key: "やまだ" }
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        post admin_user_guest_unlink_path(target_user), params: { name_key: "やまだ" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      context "with valid linked participant" do
        let!(:event) { create(:event, event_type: :proxy_order, title: "テスト通販", created_by: admin_user) }
        let!(:proxy_order) { create(:proxy_order, event:) }
        let!(:participant) { create(:proxy_order_participant, proxy_order:, user: target_user, linked_from_guest_name: "やまだ") }

        it "unlinks the participant successfully and returns turbo_stream response" do
          post admin_user_guest_unlink_path(target_user),
               params: { name_key: "やまだ" },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response).to have_http_status(:ok)
          expect(response.body).to include('target="guest_link_modal"')
          expect(response.body).to include('target="guest_linked_list"')
          expect(response.body).to include('target="toast-container"')
          expect(response.body).to include("自由入力に戻しました")

          participant.reload
          expect(participant.user_id).to be_nil
          expect(participant.guest_name).to eq("やまだ")
          expect(participant.linked_from_guest_name).to be_nil
        end
      end

      context "preserves allocations and handed_over_at after unlinking" do
        let!(:event) { create(:event, event_type: :proxy_order, title: "テスト通販", created_by: admin_user) }
        let!(:proxy_order) { create(:proxy_order, event:) }
        let!(:item) { create(:proxy_order_item, proxy_order:) }
        let!(:participant) { create(:proxy_order_participant, proxy_order:, user: target_user, linked_from_guest_name: "やまだ", handed_over_at: Time.current) }
        let!(:allocation) { create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 3, lost_quantity: 1) }

        it "preserves allocation and handed_over_at values" do
          allocation_before = allocation.reload
          participant_before = participant.reload
          original_handed_over_at = participant_before.handed_over_at

          post admin_user_guest_unlink_path(target_user),
               params: { name_key: "やまだ" },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          allocation_after = allocation.reload
          participant_after = participant.reload

          expect(allocation_after.quantity).to eq(3)
          expect(allocation_after.lost_quantity).to eq(1)
          expect(participant_after.handed_over_at).to eq(original_handed_over_at)
        end
      end

      context "user cannot access unlinked participant after unlinking" do
        let!(:event) { create(:event, event_type: :proxy_order, title: "テスト通販", created_by: admin_user) }
        let!(:proxy_order) { create(:proxy_order, event:) }
        let!(:participant) { create(:proxy_order_participant, proxy_order:, user: target_user, linked_from_guest_name: "やまだ") }

        it "returns 404 when accessing as the unlinked user" do
          # First, verify user can access before unlinking
          post signin_path, params: { email: target_user.email, password: "password123" }
          get proxy_order_path(event)
          expect(response).to have_http_status(:ok)

          # Admin unlinking the participant
          delete signout_path
          post signin_path, params: { email: admin_user.email, password: "password123" }
          post admin_user_guest_unlink_path(target_user),
               params: { name_key: "やまだ" },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          # User signs in and tries to access
          delete signout_path
          post signin_path, params: { email: target_user.email, password: "password123" }
          get proxy_order_path(event)
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with conflicting guest participant" do
        let!(:event) { create(:event, event_type: :proxy_order, title: "テスト通販", created_by: admin_user) }
        let!(:proxy_order) { create(:proxy_order, event:) }
        let!(:participant) { create(:proxy_order_participant, proxy_order:, user: target_user, linked_from_guest_name: "やまだ") }
        let!(:guest_participant) { create(:proxy_order_participant, :guest, proxy_order:, guest_name: "やまだ") }

        it "returns error and does not unlink" do
          post admin_user_guest_unlink_path(target_user),
               params: { name_key: "やまだ" },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include("guest_unlink_errors")
          expect(response.body).to include("テスト通販")
          expect(response.body).to include("すでに「やまだ」の参加者がいます")

          participant.reload
          expect(participant.user_id).to eq(target_user.id)
          expect(participant.linked_from_guest_name).to eq("やまだ")
        end
      end

      context "with conflicting username" do
        let!(:event) { create(:event, event_type: :proxy_order, title: "テスト通販", created_by: admin_user) }
        let!(:proxy_order) { create(:proxy_order, event:) }
        let!(:participant) { create(:proxy_order_participant, proxy_order:, user: target_user, linked_from_guest_name: "やまだ") }
        let!(:conflict_user) { create(:user, username: "やまだ") }

        it "returns error and does not unlink" do
          post admin_user_guest_unlink_path(target_user),
               params: { name_key: "やまだ" },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include("guest_unlink_errors")
          expect(response.body).to include("と同じユーザー名のユーザーがいるため戻せません")

          participant.reload
          expect(participant.user_id).to eq(target_user.id)
          expect(participant.linked_from_guest_name).to eq("やまだ")
        end
      end
    end
  end
end
