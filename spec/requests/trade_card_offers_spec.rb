require "rails_helper"

RSpec.describe "TradeCardOffers", type: :request do
  let(:user) { create(:user) }
  let(:admin_user) { create(:admin_user) }
  let(:other_user) { create(:user) }
  let(:event) { create(:event) }
  let(:trade) { create(:trade, event: event, user: user) }
  let(:expansion) { create(:expansion) }

  before do
    post signin_path, params: { email: user.email, password: "password123" }
  end

  describe "POST /trades/:event_id/card_offers (create)" do
    let(:valid_params) do
      {
        trade_card_offer: {
          card_name: "Black Lotus",
          quantity: 1,
          language: :ja,
          condition: :nm,
          foil: :foil,
          frame: :normal,
          pw_mark: false,
          expansion_id: expansion.id,
          note: "Test note"
        }
      }
    end

    it "creates a new trade card offer" do
      trade
      expect {
        post "/trades/#{event.id}/card_offers", params: valid_params
      }.to change { TradeCardOffer.count }.by(1)
    end

    it "returns turbo_stream response" do
      trade
      post "/trades/#{event.id}/card_offers", params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
    end

    it "returns HTML redirect on success" do
      trade
      post "/trades/#{event.id}/card_offers", params: valid_params
      expect(response).to redirect_to(trade_path(event))
      expect(flash[:notice]).to include("カード明細を追加しました")
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          trade_card_offer: {
            card_name: "",
            quantity: -1,
            language: :ja,
            condition: :nm,
            foil: :foil,
            frame: :normal,
            pw_mark: false
          }
        }
      end

      it "does not create a trade card offer" do
        trade
        expect {
          post "/trades/#{event.id}/card_offers", params: invalid_params
        }.not_to change { TradeCardOffer.count }
      end

      it "returns unprocessable_entity status" do
        trade
        post "/trades/#{event.id}/card_offers", params: invalid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns HTML redirect on error" do
        trade
        post "/trades/#{event.id}/card_offers", params: invalid_params
        expect(response).to redirect_to(trade_path(event))
        expect(flash[:alert]).to be_present
      end
    end

    context "with duplicate card entry" do
      let(:duplicate_params) do
        {
          trade_card_offer: {
            card_name: "Black Lotus",
            quantity: 1,
            language: :ja,
            condition: :nm,
            foil: :foil,
            frame: :normal,
            pw_mark: false,
            expansion_id: nil
          }
        }
      end

      before do
        create(:trade_card_offer,
          trade: trade,
          card_name: "Black Lotus",
          quantity: 1,
          language: :ja,
          condition: :nm,
          foil: :foil,
          frame: :normal,
          pw_mark: false,
          expansion_id: nil)
      end

      it "does not create the duplicate trade card offer" do
        trade
        expect {
          post "/trades/#{event.id}/card_offers", params: duplicate_params
        }.not_to change { TradeCardOffer.count }
      end

      it "returns unprocessable_entity status for turbo_stream" do
        trade
        post "/trades/#{event.id}/card_offers", params: duplicate_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns HTML redirect on duplicate error" do
        trade
        post "/trades/#{event.id}/card_offers", params: duplicate_params
        expect(response).to redirect_to(trade_path(event))
        expect(flash[:alert]).to include("このカード明細は既に登録されています")
      end
    end

    context "when user is not logged in" do
      before do
        delete "/signout"
      end

      it "redirects to signin" do
        post "/trades/#{event.id}/card_offers", params: valid_params
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when trade does not exist for user" do
      it "returns 404" do
        post "/trades/#{event.id}/card_offers", params: valid_params
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /trades/:event_id/card_offers/:id (update)" do
    let(:offer) { create(:trade_card_offer, trade: trade) }
    let(:valid_params) do
      {
        trade_card_offer: {
          card_name: "Updated Card",
          quantity: 2,
          language: :en,
          condition: :sp,
          foil: :non_foil,
          frame: :extended,
          pw_mark: true
        }
      }
    end

    it "updates the trade card offer" do
      offer
      patch "/trades/#{event.id}/card_offers/#{offer.id}", params: valid_params
      offer.reload
      expect(offer.card_name).to eq("Updated Card")
      expect(offer.quantity).to eq(2)
    end

    it "returns turbo_stream response" do
      offer
      patch "/trades/#{event.id}/card_offers/#{offer.id}", params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
    end

    context "when general user tries to set amount" do
      let(:params_with_amount) do
        {
          trade_card_offer: {
            card_name: "Card with amount",
            quantity: 1,
            language: :ja,
            condition: :nm,
            foil: :foil,
            frame: :normal,
            pw_mark: false,
            amount: 5000
          }
        }
      end

      it "ignores the amount parameter" do
        offer
        original_amount = offer.amount
        patch "/trades/#{event.id}/card_offers/#{offer.id}", params: params_with_amount
        offer.reload
        # The amount parameter should be filtered out, so the amount shouldn't change
        expect(offer.amount).to eq(original_amount)
      end
    end

    context "when admin user updates amount" do
      before do
        delete "/signout"
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      let(:admin_trade) { create(:trade, event: event, user: admin_user) }
      let(:admin_offer) { create(:trade_card_offer, trade: admin_trade) }

      let(:params_with_amount) do
        {
          trade_card_offer: {
            card_name: "Card with amount",
            quantity: 1,
            language: :ja,
            condition: :nm,
            foil: :foil,
            frame: :normal,
            pw_mark: false,
            amount: 5000
          }
        }
      end

      it "allows admin to set amount" do
        admin_offer
        patch "/trades/#{event.id}/card_offers/#{admin_offer.id}", params: params_with_amount.merge(trade_id: admin_trade.id)
        admin_offer.reload
        expect(admin_offer.amount).to eq(5000)
      end

      it "returns turbo_stream response with aggregates section update" do
        admin_offer
        patch "/trades/#{event.id}/card_offers/#{admin_offer.id}",
          params: params_with_amount.merge(trade_id: admin_trade.id),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
        expect(response.body).to include('target="trade_aggregates"')

        # Verify the updated amount is rendered in the aggregates section
        admin_trade.reload
        expect(admin_trade.offers_total_amount).to eq(5000)
        # The aggregates template renders amounts with ¥ symbol and number_with_delimiter formatting
        expect(response.body).to include("¥5,000")
      end

      it "recalculates trade totals when amount is updated" do
        # Create an offer with an initial amount
        admin_offer_with_amount = create(:trade_card_offer, trade: admin_trade, amount: 1000)
        initial_offers_total = admin_trade.reload.offers_total_amount
        expect(initial_offers_total).to eq(1000)

        # Update the amount
        patch "/trades/#{event.id}/card_offers/#{admin_offer_with_amount.id}",
          params: params_with_amount.merge(trade_id: admin_trade.id)

        admin_trade.reload
        admin_offer_with_amount.reload
        # Verify the amount was updated
        expect(admin_offer_with_amount.amount).to eq(5000)
        # Verify the trade totals were recalculated
        expect(admin_trade.offers_total_amount).to eq(5000)
      end
    end

    context "IDOR protection: multiple trades in same event" do
      before do
        delete "/signout"
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      let(:another_user) { create(:user, email: "another@example.com", password: "password123") }
      let(:another_trade) { create(:trade, event: event, user: another_user) }
      let(:main_offer) { create(:trade_card_offer, trade: trade, amount: 2000) }
      let(:another_offer) { create(:trade_card_offer, trade: another_trade, amount: 1000) }

      context "when admin edits one user's offer with correct trade_id" do
        it "updates only that user's offer and not other user's offer" do
          main_offer
          another_offer

          expect(Trade.where(event_id: event.id).count).to eq(2)  # Verify two trades exist for same event

          patch "/trades/#{event.id}/card_offers/#{main_offer.id}", params: valid_params.merge(trade_id: trade.id)

          expect(main_offer.reload.card_name).to eq("Updated Card")
          expect(another_offer.reload.amount).to eq(1000)
        end
      end

      context "when admin tries to update with mismatched trade_id" do
        let(:other_event) { create(:event) }
        let(:other_trade) { create(:trade, event: other_event, user: other_user) }
        let(:main_offer) { create(:trade_card_offer, trade: trade, amount: 2000) }

        it "returns 404 when trade_id belongs to different event" do
          main_offer
          expect(Trade.where(event_id: event.id).count).to be >= 1

          patch "/trades/#{event.id}/card_offers/#{main_offer.id}",
            params: valid_params.merge(trade_id: other_trade.id)

          expect(response).to have_http_status(:not_found)
          expect(main_offer.reload.card_name).not_to eq("Updated Card")
          expect(main_offer.reload.amount).to eq(2000)
        end
      end
    end
  end

  describe "DELETE /trades/:event_id/card_offers/:id (destroy)" do
    let(:offer) { create(:trade_card_offer, trade: trade) }

    it "deletes the trade card offer" do
      offer
      expect {
        delete "/trades/#{event.id}/card_offers/#{offer.id}"
      }.to change { TradeCardOffer.count }.by(-1)
    end

    it "returns turbo_stream response" do
      offer
      delete "/trades/#{event.id}/card_offers/#{offer.id}", headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
    end

    it "returns HTML redirect on success" do
      offer
      delete "/trades/#{event.id}/card_offers/#{offer.id}"
      expect(response).to redirect_to(trade_path(event))
      expect(flash[:notice]).to include("カード明細を削除しました")
    end

    context "when offer with amount is deleted" do
      let(:admin_user) { create(:admin_user) }

      before do
        delete "/signout"
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      let(:admin_trade) { create(:trade, event: event, user: admin_user) }
      let(:admin_offer) { create(:trade_card_offer, trade: admin_trade, amount: 3000) }

      it "recalculates offers_total_amount after deletion" do
        admin_offer
        # Ensure the trade has the correct initial amount
        admin_trade.reload
        expect(admin_trade.offers_total_amount).to eq(3000)

        # Delete the offer
        delete "/trades/#{event.id}/card_offers/#{admin_offer.id}"

        # Verify the offer was deleted and totals were recalculated
        admin_trade.reload
        expect(admin_trade.offers_total_amount).to eq(0)
      end
    end

    context "when offer is deleted with both offers and wants having amounts" do
      let(:admin_user) { create(:admin_user) }

      before do
        delete "/signout"
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      let(:admin_trade) { create(:trade, event: event, user: admin_user) }
      let(:admin_offer) { create(:trade_card_offer, trade: admin_trade, amount: 5000) }
      let(:admin_want) { create(:trade_card_want, trade: admin_trade, amount: 2000) }

      it "recalculates net_amount correctly after deleting offer" do
        admin_offer
        admin_want
        # Ensure the trade has the correct initial amounts
        admin_trade.reload
        expect(admin_trade.offers_total_amount).to eq(5000)
        expect(admin_trade.wants_total_amount).to eq(2000)
        expect(admin_trade.net_amount).to eq(3000)

        # Delete the offer
        delete "/trades/#{event.id}/card_offers/#{admin_offer.id}"

        # Verify net_amount is recalculated correctly (0 - 2000 = -2000)
        admin_trade.reload
        expect(admin_trade.offers_total_amount).to eq(0)
        expect(admin_trade.wants_total_amount).to eq(2000)
        expect(admin_trade.net_amount).to eq(-2000)
      end
    end
  end
end
