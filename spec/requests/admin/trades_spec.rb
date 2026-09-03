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

        # Disallowed transitions tests
        context "with disallowed transitions" do
          it "rejects completed -> pending" do
            trade.update!(status: :completed)
            patch admin_event_trade_path(event, trade), params: { trade: { status: :pending } }
            expect(response).to have_http_status(:unprocessable_entity)
            expect(trade.reload.status).to eq("completed")
            expect(response.body).to include("ステータス")
          end

          it "rejects completed -> in_progress" do
            trade.update!(status: :completed)
            patch admin_event_trade_path(event, trade), params: { trade: { status: :in_progress } }
            expect(response).to have_http_status(:unprocessable_entity)
            expect(trade.reload.status).to eq("completed")
            expect(response.body).to include("ステータス")
          end

          it "rejects completed -> cancelled" do
            trade.update!(status: :completed)
            patch admin_event_trade_path(event, trade), params: { trade: { status: :cancelled } }
            expect(response).to have_http_status(:unprocessable_entity)
            expect(trade.reload.status).to eq("completed")
            expect(response.body).to include("ステータス")
          end

          it "rejects cancelled -> pending" do
            trade.update!(status: :cancelled)
            patch admin_event_trade_path(event, trade), params: { trade: { status: :pending } }
            expect(response).to have_http_status(:unprocessable_entity)
            expect(trade.reload.status).to eq("cancelled")
            expect(response.body).to include("ステータス")
          end

          it "rejects cancelled -> in_progress" do
            trade.update!(status: :cancelled)
            patch admin_event_trade_path(event, trade), params: { trade: { status: :in_progress } }
            expect(response).to have_http_status(:unprocessable_entity)
            expect(trade.reload.status).to eq("cancelled")
            expect(response.body).to include("ステータス")
          end

          it "rejects cancelled -> completed" do
            trade.update!(status: :cancelled)
            patch admin_event_trade_path(event, trade), params: { trade: { status: :completed } }
            expect(response).to have_http_status(:unprocessable_entity)
            expect(trade.reload.status).to eq("cancelled")
            expect(response.body).to include("ステータス")
          end
        end

        context "with turbo_stream format" do
          it "rejects completed -> pending with turbo_stream and returns 422" do
            trade.update!(status: :completed)
            patch admin_event_trade_path(event, trade),
              params: { trade: { status: :pending } },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
            expect(response).to have_http_status(:unprocessable_entity)
            expect(response.content_type).to include("text/vnd.turbo-stream.html")
            expect(trade.reload.status).to eq("completed")
          end

          it "rejects cancelled -> in_progress with turbo_stream and returns 422" do
            trade.update!(status: :cancelled)
            patch admin_event_trade_path(event, trade),
              params: { trade: { status: :in_progress } },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
            expect(response).to have_http_status(:unprocessable_entity)
            expect(response.content_type).to include("text/vnd.turbo-stream.html")
            expect(trade.reload.status).to eq("cancelled")
          end
        end
      end

      describe "format negotiation" do
        context "when requesting HTML format" do
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

        context "when requesting turbo_stream format" do
          it "returns turbo_stream response with correct content type" do
            patch admin_event_trade_path(event, trade),
              params: { trade: { status: :in_progress } },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
            expect(response.content_type).to include("text/vnd.turbo-stream.html")
          end

          it "replaces trade_status_display in turbo_stream response" do
            trade.update!(status: :in_progress)
            patch admin_event_trade_path(event, trade),
              params: { trade: { status: :completed } },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
            expect(response.body).to include('<turbo-stream action="replace" target="trade_status_display">')
          end

          it "replaces trade_aggregates_section in turbo_stream response" do
            patch admin_event_trade_path(event, trade),
              params: { trade: { status: :in_progress } },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
            expect(response.body).to include('<turbo-stream action="replace" target="trade_aggregates_section">')
          end

          it "updates trade status correctly with turbo_stream request" do
            patch admin_event_trade_path(event, trade),
              params: { trade: { status: :in_progress } },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
            expect(trade.reload.status).to eq("in_progress")
          end
        end
      end
    end
  end

  describe "Interaction with existing TradeCardOffers/Wants controllers" do
    before do
      post signin_path, params: { email: admin_user.email, password: "password123" }
    end

    it "admin can create trade card offer with amount" do
      expansion = create(:expansion)
      offer = create(:trade_card_offer, trade: trade, amount: nil)
      patch trade_card_offer_path(trade.event, offer), params: { trade_card_offer: { amount: 5000 }, trade_id: trade.id }
      expect(offer.reload.amount).to eq(5000)
    end

    it "admin can create trade card want with amount" do
      expansion = create(:expansion)
      want = create(:trade_card_want, trade: trade, amount: nil)
      patch trade_card_want_path(trade.event, want), params: { trade_card_want: { amount: 3000 }, trade_id: trade.id }
      expect(want.reload.amount).to eq(3000)
    end

    describe "POST turbo_stream for card offer creation" do
      it "creates a new trade card offer and returns turbo_stream response" do
        expansion = create(:expansion)
        expect {
          post trade_card_offers_path(trade.event),
            params: {
              trade_card_offer: {
                card_name: "Test Card",
                quantity: 2,
                language: "ja",
                condition: "nm",
                foil: "non_foil",
                frame: "normal",
                pw_mark: false,
                expansion_id: expansion.id,
                note: "Test note"
              },
              trade_id: trade.id
            },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(TradeCardOffer, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end

      it "includes new trade card offer in turbo_stream append" do
        expansion = create(:expansion)
        post trade_card_offers_path(trade.event),
          params: {
            trade_card_offer: {
              card_name: "Test Card",
              quantity: 2,
              language: "ja",
              condition: "nm",
              foil: "non_foil",
              frame: "normal",
              pw_mark: false,
              expansion_id: expansion.id,
              note: "Test note"
            },
            trade_id: trade.id
          },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include('<turbo-stream action="append" target="trade_card_offers">')
        expect(response.body).to include("Test Card")
      end

      it "replaces admin form frame in turbo_stream response" do
        expansion = create(:expansion)
        post trade_card_offers_path(trade.event),
          params: {
            trade_card_offer: {
              card_name: "Test Card",
              quantity: 2,
              language: "ja",
              condition: "nm",
              foil: "non_foil",
              frame: "normal",
              pw_mark: false,
              expansion_id: expansion.id,
              note: "Test note"
            },
            trade_id: trade.id
          },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include('<turbo-stream action="replace" target="new_trade_card_offer_admin">')
        expect(response.body).to include('id="new_trade_card_offer_admin"')
      end

      it "allows admin to set amount field when creating offer" do
        expansion = create(:expansion)
        expect {
          post trade_card_offers_path(trade.event),
            params: {
              trade_card_offer: {
                card_name: "Expensive Card",
                quantity: 1,
                language: "ja",
                condition: "nm",
                foil: "non_foil",
                frame: "normal",
                pw_mark: false,
                expansion_id: expansion.id,
                note: "High value card",
                amount: 10000
              },
              trade_id: trade.id
            },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(TradeCardOffer, :count).by(1)

        new_offer = TradeCardOffer.last
        expect(new_offer.amount).to eq(10000)
      end
    end

    describe "POST turbo_stream for card want creation" do
      it "creates a new trade card want and returns turbo_stream response" do
        expansion = create(:expansion)
        expect {
          post trade_card_wants_path(trade.event),
            params: {
              trade_card_want: {
                card_name: "Desired Card",
                quantity: 3,
                language: "ja",
                conditions: [ "nm", "sp" ],
                foil: nil,
                frame: nil,
                expansion_id: expansion.id,
                note: "Looking for this"
              },
              trade_id: trade.id
            },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(TradeCardWant, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end

      it "includes new trade card want in turbo_stream append" do
        expansion = create(:expansion)
        post trade_card_wants_path(trade.event),
          params: {
            trade_card_want: {
              card_name: "Desired Card",
              quantity: 3,
              language: "ja",
              conditions: [ "nm", "sp" ],
              foil: nil,
              frame: nil,
              expansion_id: expansion.id,
              note: "Looking for this"
            },
            trade_id: trade.id
          },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include('<turbo-stream action="append" target="trade_card_wants">')
        expect(response.body).to include("Desired Card")
      end

      it "replaces admin form frame in turbo_stream response" do
        expansion = create(:expansion)
        post trade_card_wants_path(trade.event),
          params: {
            trade_card_want: {
              card_name: "Desired Card",
              quantity: 3,
              language: "ja",
              conditions: [ "nm", "sp" ],
              foil: nil,
              frame: nil,
              expansion_id: expansion.id,
              note: "Looking for this"
            },
            trade_id: trade.id
          },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include('<turbo-stream action="replace" target="new_trade_card_want_admin">')
        expect(response.body).to include('id="new_trade_card_want_admin"')
      end

      it "allows admin to set amount field when creating want" do
        expansion = create(:expansion)
        expect {
          post trade_card_wants_path(trade.event),
            params: {
              trade_card_want: {
                card_name: "Expensive Desired Card",
                quantity: 1,
                language: "ja",
                conditions: [ "nm" ],
                foil: nil,
                frame: nil,
                expansion_id: expansion.id,
                note: "High value want",
                amount: 5000
              },
              trade_id: trade.id
            },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(TradeCardWant, :count).by(1)

        new_want = TradeCardWant.last
        expect(new_want.amount).to eq(5000)
      end
    end

    it "admin can edit trade card offer amount through existing controller" do
      offer = create(:trade_card_offer, trade: trade)
      patch trade_card_offer_path(trade.event, offer), params: { trade_card_offer: { amount: 5000 }, trade_id: trade.id }
      expect(offer.reload.amount).to eq(5000)
    end

    it "admin can edit trade card want amount through existing controller" do
      want = create(:trade_card_want, trade: trade)
      patch trade_card_want_path(trade.event, want), params: { trade_card_want: { amount: 3000 }, trade_id: trade.id }
      expect(want.reload.amount).to eq(3000)
    end

    describe "IDOR protection: multiple trades in same event" do
      let(:other_user) { create(:user, email: "other@example.com", password: "password123") }
      let(:other_trade) { create(:trade, event: event, user: other_user) }
      let(:other_offer) { create(:trade_card_offer, trade: other_trade, amount: 1000) }
      let(:other_want) { create(:trade_card_want, trade: other_trade, amount: 500) }

      context "when admin edits one user's offer with correct trade_id" do
        it "updates only that user's offer and not other user's offer" do
          main_offer = create(:trade_card_offer, trade: trade, amount: 2000)
          other_offer

          expect(Trade.where(event_id: event.id).count).to eq(2)  # Verify two trades exist for same event

          patch trade_card_offer_path(event, main_offer), params: { trade_card_offer: { amount: 5000 }, trade_id: trade.id }

          expect(main_offer.reload.amount).to eq(5000)
          expect(other_offer.reload.amount).to eq(1000)
        end
      end

      context "when admin edits one user's want with correct trade_id" do
        it "updates only that user's want and not other user's want" do
          main_want = create(:trade_card_want, trade: trade, amount: 1500)
          other_want

          expect(Trade.where(event_id: event.id).count).to eq(2)  # Verify two trades exist for same event

          patch trade_card_want_path(event, main_want), params: { trade_card_want: { amount: 3000 }, trade_id: trade.id }

          expect(main_want.reload.amount).to eq(3000)
          expect(other_want.reload.amount).to eq(500)
        end
      end
    end
  end
end
