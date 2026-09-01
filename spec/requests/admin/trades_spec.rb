require "rails_helper"

RSpec.describe "Admin::Trades", type: :request do
  let(:admin_user) { create(:admin_user, email: "admin@example.com", password: "password123") }
  let(:general_user) { create(:user, email: "user@example.com", password: "password123") }
  let(:event) { create(:event) }
  let(:trade) { create(:trade, event: event, user: general_user) }

  describe "GET /admin/events/:event_id/trades/:id (show)" do
    context "when user is not logged in" do
      it "redirects to signin path" do
        get admin_event_trade_path(event, trade)
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        get admin_event_trade_path(event, trade)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "returns success status" do
        get admin_event_trade_path(event, trade)
        expect(response).to have_http_status(:ok)
      end

      it "displays event title" do
        get admin_event_trade_path(event, trade)
        expect(response.body).to include(event.title)
      end

      it "displays user information" do
        get admin_event_trade_path(event, trade)
        expect(response.body).to include(general_user.username)
        expect(response.body).to include(general_user.email)
      end

      it "displays trade status" do
        get admin_event_trade_path(event, trade)
        expect(response.body).to include(I18n.t("activerecord.enums.trade.status.pending"))
      end

      it "displays aggregated amounts" do
        get admin_event_trade_path(event, trade)
        expect(response.body).to include("出すカード合計")
        expect(response.body).to include("欲しいカード合計")
        expect(response.body).to include("差額")
      end

      it "displays trade card offers" do
        offer = create(:trade_card_offer, trade: trade)
        get admin_event_trade_path(event, trade)
        expect(response.body).to include(offer.card_name)
      end

      it "displays trade card wants" do
        want = create(:trade_card_want, trade: trade)
        get admin_event_trade_path(event, trade)
        expect(response.body).to include(want.card_name)
      end

      context "with card amounts" do
        it "displays offer amount when present" do
          offer = create(:trade_card_offer, trade: trade, amount: 1000)
          get admin_event_trade_path(event, trade)
          expect(response.body).to include("¥1,000")
        end

        it "displays want amount when present" do
          want = create(:trade_card_want, trade: trade, amount: 500)
          get admin_event_trade_path(event, trade)
          expect(response.body).to include("¥500")
        end
      end
    end
  end

  describe "PATCH /admin/events/:event_id/trades/:id (update)" do
    context "when user is not logged in" do
      it "redirects to signin path" do
        patch admin_event_trade_path(event, trade), params: { trade: { status: :in_progress } }
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        patch admin_event_trade_path(event, trade), params: { trade: { status: :in_progress } }
        expect(response).to have_http_status(:forbidden)
      end

      it "does not update the trade status" do
        expect {
          patch admin_event_trade_path(event, trade), params: { trade: { status: :in_progress } }
        }.not_to change { trade.reload.status }
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      context "with valid status" do
        it "updates trade status from pending to in_progress" do
          patch admin_event_trade_path(event, trade), params: { trade: { status: :in_progress } }
          expect(trade.reload.status).to eq("in_progress")
        end

        it "updates trade status from pending to completed" do
          patch admin_event_trade_path(event, trade), params: { trade: { status: :completed } }
          expect(trade.reload.status).to eq("completed")
        end

        it "updates trade status to cancelled with reason" do
          reason = "理由テスト"
          patch admin_event_trade_path(event, trade), params: { trade: { status: :cancelled, cancelled_reason: reason } }
          expect(trade.reload.status).to eq("cancelled")
          expect(trade.reload.cancelled_reason).to eq(reason)
        end

        it "does not update amount field" do
          expect {
            patch admin_event_trade_path(event, trade), params: { trade: { status: :in_progress, offers_total_amount: 9999 } }
          }.not_to change { trade.reload.offers_total_amount }
        end

        context "when status is completed" do
          it "sets completed_by_id to current admin user" do
            patch admin_event_trade_path(event, trade), params: { trade: { status: :completed } }
            expect(trade.reload.completed_by_id).to eq(admin_user.id)
          end

          it "sets completed_at to current time" do
            before_time = Time.current
            patch admin_event_trade_path(event, trade), params: { trade: { status: :completed } }
            after_time = Time.current
            completed_at = trade.reload.completed_at
            expect(completed_at).to be_between(before_time, after_time)
          end
        end
      end

      context "with invalid status" do
        it "rejects invalid status value" do
          patch admin_event_trade_path(event, trade), params: { trade: { status: :invalid_status } }
          expect(response).to have_http_status(:unprocessable_entity)
          expect(trade.reload.status).to eq("pending")
        end
      end

      context "when updating trade transitions" do
        it "allows pending -> in_progress" do
          patch admin_event_trade_path(event, trade), params: { trade: { status: :in_progress } }
          expect(trade.reload.status).to eq("in_progress")
        end

        it "allows pending -> cancelled" do
          patch admin_event_trade_path(event, trade), params: { trade: { status: :cancelled } }
          expect(trade.reload.status).to eq("cancelled")
        end

        it "allows in_progress -> completed" do
          trade.update!(status: :in_progress)
          patch admin_event_trade_path(event, trade), params: { trade: { status: :completed } }
          expect(trade.reload.status).to eq("completed")
        end

        it "allows in_progress -> cancelled" do
          trade.update!(status: :in_progress)
          patch admin_event_trade_path(event, trade), params: { trade: { status: :cancelled } }
          expect(trade.reload.status).to eq("cancelled")
        end
      end

      it "redirects to show page after successful update" do
        patch admin_event_trade_path(event, trade), params: { trade: { status: :in_progress } }
        expect(response).to redirect_to(admin_event_trade_path(event, trade))
      end

      it "displays success notice after update" do
        patch admin_event_trade_path(event, trade), params: { trade: { status: :in_progress } }
        follow_redirect!
        expect(response.body).to include("トレード情報を更新しました")
      end
    end
  end

  describe "Interaction with existing TradeCardOffers/Wants controllers" do
    before do
      post signin_path, params: { email: admin_user.email, password: "password123" }
    end

    it "admin can edit trade card offer amount through existing controller" do
      offer = create(:trade_card_offer, trade: trade)
      patch trade_card_offer_path(trade.event, offer), params: { trade_card_offer: { amount: 5000 } }
      expect(offer.reload.amount).to eq(5000)
    end

    it "admin can edit trade card want amount through existing controller" do
      want = create(:trade_card_want, trade: trade)
      patch trade_card_want_path(trade.event, want), params: { trade_card_want: { amount: 3000 } }
      expect(want.reload.amount).to eq(3000)
    end
  end
end
