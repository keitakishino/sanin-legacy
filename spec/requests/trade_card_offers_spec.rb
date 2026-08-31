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

    xit "returns turbo_stream response" do
      # TODO: Fix turbo_stream rendering - investigate 500 error
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

      xit "returns unprocessable_entity status" do
        # TODO: Fix turbo_stream rendering - investigate 500 error
        trade
        post "/trades/#{event.id}/card_offers", params: invalid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:unprocessable_entity)
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

    xit "returns turbo_stream response" do
      # TODO: Fix turbo_stream rendering - investigate 500 error
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
        patch "/trades/#{event.id}/card_offers/#{admin_offer.id}", params: params_with_amount
        admin_offer.reload
        expect(admin_offer.amount).to eq(5000)
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
  end

end
