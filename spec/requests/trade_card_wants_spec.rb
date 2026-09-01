require "rails_helper"

RSpec.describe "TradeCardWants", type: :request do
  let(:user) { create(:user) }
  let(:admin_user) { create(:admin_user) }
  let(:other_user) { create(:user) }
  let(:event) { create(:event) }
  let(:trade) { create(:trade, event: event, user: user) }
  let(:expansion) { create(:expansion) }

  before do
    post signin_path, params: { email: user.email, password: "password123" }
  end

  describe "POST /trades/:event_id/card_wants (create)" do
    let(:valid_params) do
      {
        trade_card_want: {
          card_name: "Black Lotus",
          quantity: 1,
          language: :ja,
          conditions: [ 0, 1 ],
          foil: :foil,
          frame: :normal,
          expansion_id: expansion.id,
          note: "Test note"
        }
      }
    end

    it "creates a new trade card want" do
      trade
      expect {
        post "/trades/#{event.id}/card_wants", params: valid_params
      }.to change { TradeCardWant.count }.by(1)
    end

    it "creates want with nullable fields as nil" do
      trade
      params_with_nil = {
        trade_card_want: {
          card_name: "Card",
          quantity: 1,
          language: nil,
          conditions: [ 0 ],
          foil: nil,
          frame: nil
        }
      }
      post "/trades/#{event.id}/card_wants", params: params_with_nil
      expect(response).to redirect_to(trade_path(event))
      want = TradeCardWant.last
      expect(want).not_to be_nil
      expect(want.language).to be_nil
      expect(want.foil).to be_nil
      expect(want.frame).to be_nil
    end

    it "returns turbo_stream response" do
      trade
      post "/trades/#{event.id}/card_wants", params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
    end

    it "returns HTML redirect on success" do
      trade
      post "/trades/#{event.id}/card_wants", params: valid_params
      expect(response).to redirect_to(trade_path(event))
      expect(flash[:notice]).to include("カード明細を追加しました")
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          trade_card_want: {
            card_name: "",
            quantity: -1
          }
        }
      end

      it "does not create a trade card want" do
        trade
        expect {
          post "/trades/#{event.id}/card_wants", params: invalid_params
        }.not_to change { TradeCardWant.count }
      end

      it "returns unprocessable_entity status" do
        trade
        post "/trades/#{event.id}/card_wants", params: invalid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns HTML redirect on error" do
        trade
        post "/trades/#{event.id}/card_wants", params: invalid_params
        expect(response).to redirect_to(trade_path(event))
        expect(flash[:alert]).to be_present
      end
    end

    context "with invalid conditions values" do
      let(:invalid_conditions_params) do
        {
          trade_card_want: {
            card_name: "Card",
            quantity: 1,
            conditions: [ 0, 5, 6 ]  # 5 and 6 are invalid (only 0-4 allowed)
          }
        }
      end

      it "does not create the want" do
        trade
        expect {
          post "/trades/#{event.id}/card_wants", params: invalid_conditions_params
        }.not_to change { TradeCardWant.count }
      end

      it "returns unprocessable_entity status" do
        trade
        post "/trades/#{event.id}/card_wants", params: invalid_conditions_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns HTML redirect on error" do
        trade
        post "/trades/#{event.id}/card_wants", params: invalid_conditions_params
        expect(response).to redirect_to(trade_path(event))
        expect(flash[:alert]).to be_present
      end
    end

    context "with duplicate card entry" do
      let(:duplicate_params) do
        {
          trade_card_want: {
            card_name: "Ancestral Recall",
            quantity: 1,
            language: :ja,
            foil: :foil,
            frame: :normal,
            conditions: [ 0, 1, 2 ],
            expansion_id: nil
          }
        }
      end

      before do
        create(:trade_card_want,
          trade: trade,
          card_name: "Ancestral Recall",
          quantity: 1,
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [ 0, 1, 2 ],
          expansion_id: nil)
      end

      it "does not create the duplicate trade card want" do
        trade
        expect {
          post "/trades/#{event.id}/card_wants", params: duplicate_params
        }.not_to change { TradeCardWant.count }
      end

      it "returns unprocessable_entity status for turbo_stream" do
        trade
        post "/trades/#{event.id}/card_wants", params: duplicate_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns HTML redirect on duplicate error" do
        trade
        post "/trades/#{event.id}/card_wants", params: duplicate_params
        expect(response).to redirect_to(trade_path(event))
        expect(flash[:alert]).to include("このカード明細は既に登録されています")
      end
    end

    context "with duplicate card entry but different condition order" do
      let(:duplicate_params_different_order) do
        {
          trade_card_want: {
            card_name: "Card",
            quantity: 1,
            language: :ja,
            foil: :foil,
            frame: :normal,
            conditions: [ 2, 0, 1 ],  # Different order, but same elements
            expansion_id: nil
          }
        }
      end

      before do
        create(:trade_card_want,
          trade: trade,
          card_name: "Card",
          quantity: 1,
          language: :ja,
          foil: :foil,
          frame: :normal,
          conditions: [ 0, 1, 2 ],
          expansion_id: nil)
      end

      it "does not create the want (order-insensitive duplicate)" do
        trade
        expect {
          post "/trades/#{event.id}/card_wants", params: duplicate_params_different_order
        }.not_to change { TradeCardWant.count }
      end

      it "returns unprocessable_entity status for turbo_stream" do
        trade
        post "/trades/#{event.id}/card_wants", params: duplicate_params_different_order, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns HTML redirect on duplicate error" do
        trade
        post "/trades/#{event.id}/card_wants", params: duplicate_params_different_order
        expect(response).to redirect_to(trade_path(event))
        expect(flash[:alert]).to include("このカード明細は既に登録されています")
      end
    end

    context "when user is not logged in" do
      before do
        delete "/signout"
      end

      it "redirects to signin" do
        post "/trades/#{event.id}/card_wants", params: valid_params
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when trade does not exist for user" do
      it "returns 404" do
        post "/trades/#{event.id}/card_wants", params: valid_params
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /trades/:event_id/card_wants/:id (update)" do
    let(:want) { create(:trade_card_want, trade: trade) }
    let(:valid_params) do
      {
        trade_card_want: {
          card_name: "Updated Card",
          quantity: 2,
          language: :en,
          conditions: [ 1, 2 ],
          foil: :non_foil,
          frame: :extended
        }
      }
    end

    it "updates the trade card want" do
      want
      patch "/trades/#{event.id}/card_wants/#{want.id}", params: valid_params
      want.reload
      expect(want.card_name).to eq("Updated Card")
      expect(want.quantity).to eq(2)
      expect(want.conditions).to eq([ 1, 2 ])
    end

    it "returns turbo_stream response" do
      want
      patch "/trades/#{event.id}/card_wants/#{want.id}", params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
    end

    context "when general user tries to set amount" do
      let(:params_with_amount) do
        {
          trade_card_want: {
            card_name: "Card with amount",
            quantity: 1,
            amount: 5000
          }
        }
      end

      it "ignores the amount parameter" do
        want
        patch "/trades/#{event.id}/card_wants/#{want.id}", params: params_with_amount
        want.reload
        expect(want.amount).to be_nil
      end
    end

    context "when admin user updates amount" do
      before do
        delete "/signout"
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      let(:admin_trade) { create(:trade, event: event, user: admin_user) }
      let(:admin_want) { create(:trade_card_want, trade: admin_trade) }

      let(:params_with_amount) do
        {
          trade_card_want: {
            card_name: "Card with amount",
            quantity: 1,
            amount: 5000
          }
        }
      end

      it "allows admin to set amount" do
        admin_want
        patch "/trades/#{event.id}/card_wants/#{admin_want.id}", params: params_with_amount.merge(trade_id: admin_trade.id)
        admin_want.reload
        expect(admin_want.amount).to eq(5000)
      end
    end

    context "IDOR protection: multiple trades in same event" do
      before do
        delete "/signout"
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      let(:another_user) { create(:user, email: "another@example.com", password: "password123") }
      let(:another_trade) { create(:trade, event: event, user: another_user) }
      let(:main_want) { create(:trade_card_want, trade: trade, amount: 1500) }
      let(:another_want) { create(:trade_card_want, trade: another_trade, amount: 500) }

      context "when admin edits one user's want with correct trade_id" do
        it "updates only that user's want and not other user's want" do
          main_want
          another_want

          expect(Trade.where(event_id: event.id).count).to eq(2)  # Verify two trades exist for same event

          patch "/trades/#{event.id}/card_wants/#{main_want.id}", params: valid_params.merge(trade_id: trade.id)

          expect(main_want.reload.card_name).to eq("Updated Card")
          expect(another_want.reload.amount).to eq(500)
        end
      end
    end
  end

  describe "DELETE /trades/:event_id/card_wants/:id (destroy)" do
    let(:want) { create(:trade_card_want, trade: trade) }

    it "deletes the trade card want" do
      want
      expect {
        delete "/trades/#{event.id}/card_wants/#{want.id}"
      }.to change { TradeCardWant.count }.by(-1)
    end

    it "returns turbo_stream response" do
      want
      delete "/trades/#{event.id}/card_wants/#{want.id}", headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
    end

    it "returns HTML redirect on success" do
      want
      delete "/trades/#{event.id}/card_wants/#{want.id}"
      expect(response).to redirect_to(trade_path(event))
      expect(flash[:notice]).to include("カード明細を削除しました")
    end
  end
end
