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

    it "returns turbo_stream with correct target frame for general user" do
      trade
      post "/trades/#{event.id}/card_offers", params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      # General user must target 'new_trade_card_offer' frame, NOT 'new_trade_card_offer_admin'
      expect(response.body).to include('target="new_trade_card_offer"')
      expect(response.body).not_to include('target="new_trade_card_offer_admin"')
    end

    context "when an admin creates on their own trade via the general /trades/:event_id page" do
      before do
        delete "/signout"
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      let!(:other_trade) { create(:trade, event: event, user: other_user) }
      let!(:admin_trade) { create(:trade, event: event, user: admin_user) }

      it "resolves the admin's own trade and targets the non-admin frame (no trade_id param, mirroring the form rendered on this page)" do
        expect {
          post "/trades/#{event.id}/card_offers", params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change { admin_trade.trade_card_offers.count }.by(1)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('target="new_trade_card_offer"')
        expect(response.body).not_to include('target="new_trade_card_offer_admin"')
      end
    end

    it "returns HTML redirect on success" do
      trade
      post "/trades/#{event.id}/card_offers", params: valid_params
      expect(response).to redirect_to(trade_path(event))
      expect(flash[:notice]).to include("カード明細を追加しました")
    end

    it "includes toast notification in turbo_stream response" do
      trade
      post "/trades/#{event.id}/card_offers", params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('target="toast-container"')
      expect(response.body).to include('data-controller="toast"')
      # Verify card_name is embedded in the message
      expect(response.body).to include(valid_params[:trade_card_offer][:card_name])
    end

    it "removes empty state element when adding first offer to empty trade" do
      trade
      expect(trade.trade_card_offers.count).to eq(0)
      post "/trades/#{event.id}/card_offers", params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="remove" target="trade_card_offers_empty"')
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

      it "renders combobox UI elements in turbo_stream response" do
        trade
        post "/trades/#{event.id}/card_offers", params: invalid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:unprocessable_entity)
        # Check that the expansion combobox controller is present
        expect(response.body).to include('data-controller="expansion-select"')
        # Check that the text input field is present
        expect(response.body).to include('data-expansion-select-target="input"')
        # Check that the hidden field is present
        expect(response.body).to include('data-expansion-select-target="select"')
        # Check that the turbo-frame for suggestions is present
        expect(response.body).to include('id="expansion_suggestions"')
      end

      it "includes error toast notification in turbo_stream response" do
        trade
        post "/trades/#{event.id}/card_offers", params: invalid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('action="append" target="toast-container"')
        expect(response.body).to include('data-controller="toast"')
        expect(response.body).to include('border-danger')
        # Verify error messages are in the toast (check for X icon for danger variant)
        expect(response.body).to include('text-danger')
        expect(response.body).to include('bg-danger-soft')
      end

      it "uses correct frame_id for non-admin user validation error" do
        trade
        post "/trades/#{event.id}/card_offers", params: invalid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:unprocessable_entity)
        # General user validation error should target 'new_trade_card_offer' frame
        expect(response.body).to include('target="new_trade_card_offer"')
        expect(response.body).to include('id="new_trade_card_offer"')
      end

      context "when admin user creates with invalid params" do
        before do
          delete "/signout"
          post signin_path, params: { email: admin_user.email, password: "password123" }
        end

        let(:admin_trade) { create(:trade, event: event, user: admin_user) }

        it "uses admin frame_id for validation error" do
          admin_trade
          post "/trades/#{event.id}/card_offers", params: invalid_params.merge(trade_id: admin_trade.id), headers: { "Accept" => "text/vnd.turbo-stream.html" }
          expect(response).to have_http_status(:unprocessable_entity)
          # Admin context validation error should target 'new_trade_card_offer_admin' frame
          expect(response.body).to include('target="new_trade_card_offer_admin"')
          expect(response.body).to include('id="new_trade_card_offer_admin"')
        end
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

      it "includes error toast in turbo_stream response for duplicate" do
        trade
        post "/trades/#{event.id}/card_offers", params: duplicate_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('action="append" target="toast-container"')
        expect(response.body).to include('data-controller="toast"')
        expect(response.body).to include('border-danger')
        expect(response.body).to include("このカード明細は既に登録されています")
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

    it "includes toast notification in turbo_stream response" do
      offer
      patch "/trades/#{event.id}/card_offers/#{offer.id}", params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="append" target="toast-container"')
      expect(response.body).to include("Updated Card")
      expect(response.body).to include("の出すカード明細を更新しました")
    end

    context "with invalid params on update" do
      let(:invalid_update_params) do
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

      it "does not update the trade card offer" do
        offer
        patch "/trades/#{event.id}/card_offers/#{offer.id}", params: invalid_update_params
        offer.reload
        expect(offer.card_name).not_to eq("")
      end

      it "returns unprocessable_entity status" do
        offer
        patch "/trades/#{event.id}/card_offers/#{offer.id}", params: invalid_update_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "uses correct frame_id for validation error on update" do
        offer
        patch "/trades/#{event.id}/card_offers/#{offer.id}", params: invalid_update_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:unprocessable_entity)
        # Edit validation error should use persisted dom_id frame
        expected_frame_id = "edit_form_trade_card_offer_#{offer.id}"
        expect(response.body).to include("target=\"#{expected_frame_id}\"")
        expect(response.body).to include("id=\"#{expected_frame_id}\"")
      end

      it "includes error toast notification in turbo_stream response" do
        offer
        patch "/trades/#{event.id}/card_offers/#{offer.id}", params: invalid_update_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('action="append" target="toast-container"')
        expect(response.body).to include('data-controller="toast"')
        expect(response.body).to include('border-danger')
      end
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

      it "turbo_stream response uses inline aggregates design (no heading)" do
        admin_offer
        patch "/trades/#{event.id}/card_offers/#{admin_offer.id}",
          params: params_with_amount.merge(trade_id: admin_trade.id),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        # Verify the heading "集計値（表示のみ）" is NOT included in turbo_stream response
        expect(response.body).not_to include("集計値（表示のみ）")
        # Verify the grid structure is present
        expect(response.body).to include('class="grid grid-cols-3 gap-4"')
        # Verify individual tiles are rendered
        expect(response.body).to include("出すカード合計")
        expect(response.body).to include("欲しいカード合計")
        expect(response.body).to include("差額（出す - 欲しい）")
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

      context "trade_id validation on update/destroy" do
        it "returns 404 when trade_id param does not match the offer's actual trade (update)" do
          main_offer
          original_card_name = main_offer.card_name

          patch "/trades/#{event.id}/card_offers/#{main_offer.id}",
            params: valid_params.merge(trade_id: another_trade.id)

          expect(response).to have_http_status(:not_found)
          expect(main_offer.reload.card_name).to eq(original_card_name)
        end

        it "returns 404 when trade_id param does not match the offer's actual trade (destroy)" do
          main_offer

          expect {
            delete "/trades/#{event.id}/card_offers/#{main_offer.id}",
              params: { trade_id: another_trade.id }
          }.not_to change { TradeCardOffer.count }

          expect(response).to have_http_status(:not_found)
        end

        it "updates successfully when trade_id param matches the offer's actual trade" do
          main_offer

          patch "/trades/#{event.id}/card_offers/#{main_offer.id}",
            params: valid_params.merge(trade_id: trade.id),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response).to have_http_status(:ok)
          expect(main_offer.reload.card_name).to eq("Updated Card")
        end

        it "deletes successfully when trade_id param matches the offer's actual trade" do
          main_offer

          expect {
            delete "/trades/#{event.id}/card_offers/#{main_offer.id}",
              params: { trade_id: trade.id },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
          }.to change { TradeCardOffer.count }.by(-1)

          expect(response).to have_http_status(:ok)
        end

        it "updates successfully when trade_id param is not provided (existing behavior)" do
          main_offer

          patch "/trades/#{event.id}/card_offers/#{main_offer.id}", params: valid_params

          expect(main_offer.reload.card_name).to eq("Updated Card")
        end
      end
    end
  end

  describe "DELETE /trades/:event_id/card_offers/:id (destroy)" do
    let(:offer) { create(:trade_card_offer, trade: trade) }

    context "when other user tries to delete offer" do
      before do
        delete "/signout"
        post signin_path, params: { email: other_user.email, password: "password123" }
      end

      it "returns forbidden status with HTML request" do
        offer
        delete "/trades/#{event.id}/card_offers/#{offer.id}"
        expect(response).to have_http_status(:forbidden)
      end

      it "returns forbidden status with turbo_stream request and HTML format response" do
        offer
        delete "/trades/#{event.id}/card_offers/#{offer.id}",
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:forbidden)
        expect(response.content_type).to include("text/html")
      end

      it "does not delete the trade card offer" do
        offer
        expect {
          delete "/trades/#{event.id}/card_offers/#{offer.id}"
        }.not_to change { TradeCardOffer.count }
      end
    end

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

    it "includes toast notification in turbo_stream response" do
      offer
      delete "/trades/#{event.id}/card_offers/#{offer.id}", headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="append" target="toast-container"')
      expect(response.body).to include(offer.card_name)
      expect(response.body).to include("を出すカードから削除しました")
    end

    it "returns HTML redirect on success" do
      offer
      delete "/trades/#{event.id}/card_offers/#{offer.id}"
      expect(response).to redirect_to(trade_path(event))
      expect(flash[:notice]).to include("カード明細を削除しました")
    end

    it "shows empty state when deleting last offer" do
      offer
      expect(trade.trade_card_offers.count).to eq(1)
      delete "/trades/#{event.id}/card_offers/#{offer.id}", headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="append" target="trade_card_offers"')
      expect(response.body).to include('id="trade_card_offers_empty"')
      expect(response.body).to include('カード明細はまだありません')
    end

    it "does not show empty state when deleting non-last offer" do
      offer1 = create(:trade_card_offer, trade: trade)
      offer2 = create(:trade_card_offer, trade: trade)
      expect(trade.trade_card_offers.count).to eq(2)
      delete "/trades/#{event.id}/card_offers/#{offer1.id}", headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      # Should not have append action for empty state if not empty after deletion
      expect(response.body).not_to include('id="trade_card_offers_empty"')
    end

    context "when admin deletes last offer (admin context)" do
      before do
        delete "/signout"
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      let(:admin_trade) { create(:trade, event: event, user: admin_user) }
      let(:admin_offer) { create(:trade_card_offer, trade: admin_trade) }

      it "shows empty state when deleting last offer" do
        admin_offer
        expect(admin_trade.trade_card_offers.count).to eq(1)
        # Admin context deletion with trade_id param
        delete "/trades/#{event.id}/card_offers/#{admin_offer.id}", params: { trade_id: admin_trade.id }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('action="append" target="trade_card_offers"')
        expect(response.body).to include('id="trade_card_offers_empty"')
        # Verify empty state is rendered as table row (tr > td)
        expect(response.body).to include('<tr id="trade_card_offers_empty">')
        expect(response.body).to include('colspan="12"')
        expect(response.body).to include('カード明細はまだありません')
      end

      it "does not show empty state when admin deletes non-last offer" do
        offer1 = create(:trade_card_offer, trade: admin_trade)
        offer2 = create(:trade_card_offer, trade: admin_trade)
        expect(admin_trade.trade_card_offers.count).to eq(2)
        # Admin context deletion with trade_id param
        delete "/trades/#{event.id}/card_offers/#{offer1.id}", params: { trade_id: admin_trade.id }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        # Should not have append action for empty state if not empty after deletion
        expect(response.body).not_to include('id="trade_card_offers_empty"')
      end
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

    context "when offer with amount is deleted via turbo_stream" do
      let(:admin_user) { create(:admin_user) }

      before do
        delete "/signout"
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      let(:admin_trade) { create(:trade, event: event, user: admin_user) }
      let(:admin_offer) { create(:trade_card_offer, trade: admin_trade, amount: 3000) }

      it "returns turbo_stream response with aggregates section update" do
        admin_offer
        delete "/trades/#{event.id}/card_offers/#{admin_offer.id}",
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
        # Verify aggregates section is included in the response
        expect(response.body).to include('target="trade_aggregates"')
      end

      it "turbo_stream response includes inline aggregates design" do
        admin_offer
        delete "/trades/#{event.id}/card_offers/#{admin_offer.id}",
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        # Verify the heading "集計値（表示のみ）" is NOT included in turbo_stream response
        expect(response.body).not_to include("集計値（表示のみ）")
        # Verify the grid structure is present
        expect(response.body).to include('class="grid grid-cols-3 gap-4"')
        # Verify individual tiles are rendered
        expect(response.body).to include("出すカード合計")
        expect(response.body).to include("欲しいカード合計")
        expect(response.body).to include("差額（出す - 欲しい）")
      end

      it "aggregates show correctly updated values after deletion" do
        admin_offer
        admin_trade.reload
        expect(admin_trade.offers_total_amount).to eq(3000)

        delete "/trades/#{event.id}/card_offers/#{admin_offer.id}",
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        # Verify the aggregates template renders with updated (zero) amount
        expect(response.body).to include("¥0")
        # Verify the offer was deleted
        admin_trade.reload
        expect(admin_trade.offers_total_amount).to eq(0)
      end
    end
  end

  describe "null input handling" do
    describe "POST /trades/:event_id/card_offers (create)" do
      context "with null/empty required parameters" do
        let(:null_params) do
          {
            trade_card_offer: {
              card_name: "Test Card",
              quantity: "",
              language: "",
              condition: "",
              foil: "",
              frame: "",
              pw_mark: false
            }
          }
        end

        it "does not create a trade card offer when required fields are empty" do
          trade
          expect {
            post "/trades/#{event.id}/card_offers", params: null_params
          }.not_to change { TradeCardOffer.count }
        end

        it "returns unprocessable_entity status for turbo_stream" do
          trade
          post "/trades/#{event.id}/card_offers", params: null_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "returns error response for HTML" do
          trade
          post "/trades/#{event.id}/card_offers", params: null_params
          expect(response).to redirect_to(trade_path(event))
          expect(flash[:alert]).to be_present
        end
      end
    end
  end

  describe "form reset and lifecycle" do
    let(:valid_params) do
      {
        trade_card_offer: {
          card_name: "Black Lotus",
          quantity: 1,
          language: :ja,
          condition: :nm,
          foil: :foil,
          frame: :normal,
          pw_mark: true,
          expansion_id: expansion.id,
          note: "Test note"
        }
      }
    end

    describe "POST /trades/:event_id/card_offers (create) with turbo_stream" do
      it "includes form-reset Stimulus controller in turbo_stream response" do
        trade
        post "/trades/#{event.id}/card_offers", params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('data-controller="form-reset"')
      end

      it "does not include script tag for manual form reset" do
        trade
        post "/trades/#{event.id}/card_offers", params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("form.reset()")
      end

      it "uses turbo_stream.replace for form updates" do
        trade
        post "/trades/#{event.id}/card_offers", params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('action="replace" target="new_trade_card_offer"')
      end

      it "renders form with pw_mark radio buttons in replacement" do
        trade
        post "/trades/#{event.id}/card_offers", params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("PWマーク")
      end
    end

    describe "admin context" do
      it "uses correct frame id for admin users" do
        post signin_path, params: { email: admin_user.email, password: "password123" }
        trade
        post "/trades/#{event.id}/card_offers", params: valid_params.merge(trade_id: trade.id),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('id="new_trade_card_offer_admin"')
        expect(response.body).to include('data-controller="form-reset"')
      end
    end
  end
end
