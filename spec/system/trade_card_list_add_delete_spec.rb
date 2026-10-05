require "rails_helper"

RSpec.describe "Trade Card List Add/Delete", type: :system do
  before do
    resize_window_to(1280, 900)
  end

  shared_examples "card list add/delete operations" do |is_admin|
    let(:expansion) { create(:expansion) }

    before do
      # Create fresh users and event for each test to avoid constraint violations
      if is_admin
        @user = create(:admin_user)
        @trade_owner = create(:user)
      else
        @user = create(:user)
        @trade_owner = @user
      end

      @event = create(:event)
      @trade = create(:trade, event: @event, user: @trade_owner, status: :pending)

      sign_in(@user)

      if is_admin
        visit admin_event_trade_path(@event, @trade)
      else
        visit trade_path(@event)
      end
    end

    context "for offers" do
      let(:prefix) { "offers" }

      # C1: 現在の検索・ソートを保った状態で明細を追加すると、追加した明細を含むページが表示される
      it "displays added card on correct page when sorting is applied" do
        21.times { |i| create(:trade_card_offer, trade: @trade, card_name: "Card #{format('%02d', i)}") }
        visit current_url + "?offers_sort=card_name_asc"

        button_id = is_admin ? "add_offer_btn_admin" : "add_offer_btn"
        click_button button_id

        expect(page).to have_field("カード名")
        form_id = is_admin ? "new_trade_card_offer_admin_form" : "new_trade_card_offer_form"
        within "##{form_id}" do
          fill_in "カード名", with: "Card ZZ"
          fill_in "数量", with: "1"
          click_button "追加"
        end

        # Wait for the page to update and verify the new card is visible on page 2
        expect(page).to have_text("Card ZZ")
        expect(page).to have_text("22件中 21–22件")
        # Verify URL contains the sort parameter and page number
        expect(current_url).to include("offers_sort=card_name_asc")
        expect(current_url).to include("offers_page=2")
      end

      it "displays added card on correct page when search is applied" do
        create(:trade_card_offer, trade: @trade, card_name: "Black Lotus")
        visit current_url + "?offers_q=Card"

        button_id = is_admin ? "add_offer_btn_admin" : "add_offer_btn"
        click_button button_id

        expect(page).to have_field("カード名")
        form_id = is_admin ? "new_trade_card_offer_admin_form" : "new_trade_card_offer_form"
        within "##{form_id}" do
          fill_in "カード名", with: "Card ZZ"
          fill_in "数量", with: "1"
          click_button "追加"
        end

        expect(page).to have_text("Card ZZ")
        expect(current_url).to include("offers_q=Card")
      end

      # C2: 追加した明細が現在の検索条件に合わない場合は、特定のトーストが表示される
      it "shows toast message when added card does not match search filter" do
        create(:trade_card_offer, trade: @trade, card_name: "Black Lotus")
        visit current_url + "?offers_q=Lotus"

        button_id = is_admin ? "add_offer_btn_admin" : "add_offer_btn"
        click_button button_id

        expect(page).to have_field("カード名")
        form_id = is_admin ? "new_trade_card_offer_admin_form" : "new_trade_card_offer_form"
        within "##{form_id}" do
          fill_in "カード名", with: "Zebra"
          fill_in "数量", with: "1"
          click_button "追加"
        end

        # Verify the filtered toast appears
        expect(page).to have_text("追加しました（現在の絞り込みでは表示されません）")
        # Verify the new card is NOT visible in the table
        expect(page).not_to have_text("Zebra")
      end

      # C3: 明細を削除して、表示中のページが空になったとき、最終ページが表示される
      it "shows last page when deleting last card on current page" do
        21.times { |i| create(:trade_card_offer, trade: @trade, card_name: "Card #{format('%02d', i)}") }
        visit current_url + "?offers_page=2"

        # Find and delete the only card on page 2
        within "table#trade_card_offers" do
          find("button", text: "削除").click
        end

        # Should now show page 1 (20 cards total)
        expect(page).not_to have_text("21件中 21–21件")
        expect(page).to have_text("20件中 1–20件")
        expect(page).not_to have_css("[aria-current='page'][aria-label*='2']")
      end

      # C4: 検索条件に合う明細を追加したときは、従来どおりのトースト・フォームのクリアが行われる
      it "shows normal toast and clears form when adding card matching current filters" do
        visit current_url

        button_id = is_admin ? "add_offer_btn_admin" : "add_offer_btn"
        click_button button_id

        expect(page).to have_field("カード名")
        form_id = is_admin ? "new_trade_card_offer_admin_form" : "new_trade_card_offer_form"
        within "##{form_id}" do
          fill_in "カード名", with: "New Card"
          fill_in "数量", with: "1"
          click_button "追加"
        end

        expect(page).to have_text("出すカードに追加しました")
        expect(page).to have_text("New Card")

        # Verify form is cleared when clicking "カード明細を追加" again
        click_button button_id
        expect(page).to have_field("カード名")
        within "##{form_id}" do
          expect(find_field("カード名").value).to be_empty
        end
      end

      # C5: 明細の削除は従来どおり行が除去され、特定のトーストが表示される
      it "shows destroy toast and removes row when deleting card" do
        create(:trade_card_offer, trade: @trade, card_name: "Test Card")
        visit current_url

        expect(page).to have_text("Test Card")

        within "table#trade_card_offers" do
          find("button", text: "削除").click
        end

        expect(page).to have_text("削除しました")
        expect(page).not_to have_text("Test Card")
      end

      # C6: 追加して別のページに移ったとき、URLのページ番号も表示中のページに変わる
      it "updates URL with correct page number when adding card to new page" do
        21.times { |i| create(:trade_card_offer, trade: @trade, card_name: "Card #{format('%02d', i)}") }
        visit current_url + "?offers_sort=card_name_asc"

        button_id = is_admin ? "add_offer_btn_admin" : "add_offer_btn"
        click_button button_id

        expect(page).to have_field("カード名")
        form_id = is_admin ? "new_trade_card_offer_admin_form" : "new_trade_card_offer_form"
        within "##{form_id}" do
          fill_in "カード名", with: "Card ZZ"
          fill_in "数量", with: "1"
          click_button "追加"
        end

        # Wait for URL to be updated and verify it contains page=2
        expect(page).to have_text("Card ZZ")
        expect(current_url).to include("offers_page=2")
        expect(current_url).to include("offers_sort=card_name_asc")

        # Reload page and verify it still shows the same page
        page.refresh
        expect(page).to have_text("Card ZZ")
        expect(page).to have_text("22件中 21–22件")
      end

      # C7: 欲しいカード一覧の状態は変わらない
      it "preserves wants list state when adding offer" do
        21.times { |i| create(:trade_card_want, trade: @trade, card_name: "Want #{format('%02d', i)}") }
        visit current_url + "?wants_q=Want&wants_sort=card_name_desc"

        # Verify wants list state is preserved
        expect(page).to have_selector("input[value='Want']")

        button_id = is_admin ? "add_offer_btn_admin" : "add_offer_btn"
        click_button button_id

        expect(page).to have_field("カード名")
        form_id = is_admin ? "new_trade_card_offer_admin_form" : "new_trade_card_offer_form"
        within "##{form_id}" do
          fill_in "カード名", with: "New Offer"
          fill_in "数量", with: "1"
          click_button "追加"
        end

        # Wants list should still have same search and sort
        expect(page).to have_selector("input[value='Want']")
        expect(current_url).to include("wants_q=Want")
        expect(current_url).to include("wants_sort=card_name_desc")
      end
    end

    context "for wants" do
      let(:prefix) { "wants" }

      it "displays added want on correct page when sorting is applied" do
        21.times { |i| create(:trade_card_want, trade: @trade, card_name: "Want #{format('%02d', i)}") }
        visit current_url + "?wants_sort=card_name_asc"

        button_id = is_admin ? "add_want_btn_admin" : "add_want_btn"
        click_button button_id

        expect(page).to have_field("カード名")
        form_id = is_admin ? "new_trade_card_want_admin_form" : "new_trade_card_want_form"
        within "##{form_id}" do
          fill_in "カード名", with: "Want ZZ"
          fill_in "数量", with: "1"
          click_button "追加"
        end

        expect(page).to have_text("Want ZZ")
        expect(page).to have_text("22件中 21–22件")
        expect(current_url).to include("wants_sort=card_name_asc")
        expect(current_url).to include("wants_page=2")
      end

      it "shows toast message when added want does not match search filter" do
        create(:trade_card_want, trade: @trade, card_name: "Black Lotus")
        visit current_url + "?wants_q=Lotus"

        button_id = is_admin ? "add_want_btn_admin" : "add_want_btn"
        click_button button_id

        expect(page).to have_field("カード名")
        form_id = is_admin ? "new_trade_card_want_admin_form" : "new_trade_card_want_form"
        within "##{form_id}" do
          fill_in "カード名", with: "Zebra"
          fill_in "数量", with: "1"
          click_button "追加"
        end

        expect(page).to have_text("追加しました（現在の絞り込みでは表示されません）")
        expect(page).not_to have_text("Zebra")
      end

      it "shows last page when deleting last want on current page" do
        21.times { |i| create(:trade_card_want, trade: @trade, card_name: "Want #{format('%02d', i)}") }
        visit current_url + "?wants_page=2"

        within "table#trade_card_wants" do
          find("button", text: "削除").click
        end

        expect(page).not_to have_text("21件中 21–21件")
        expect(page).to have_text("20件中 1–20件")
      end

      it "preserves offers list state when adding want" do
        21.times { |i| create(:trade_card_offer, trade: @trade, card_name: "Offer #{format('%02d', i)}") }
        visit current_url + "?offers_q=Offer&offers_sort=card_name_desc"

        expect(page).to have_selector("input[value='Offer']")

        button_id = is_admin ? "add_want_btn_admin" : "add_want_btn"
        click_button button_id

        expect(page).to have_field("カード名")
        form_id = is_admin ? "new_trade_card_want_admin_form" : "new_trade_card_want_form"
        within "##{form_id}" do
          fill_in "カード名", with: "New Want"
          fill_in "数量", with: "1"
          click_button "追加"
        end

        expect(page).to have_selector("input[value='Offer']")
        expect(current_url).to include("offers_q=Offer")
        expect(current_url).to include("offers_sort=card_name_desc")
      end
    end
  end

  context "for general user" do
    it_behaves_like "card list add/delete operations", false
  end

  context "for admin user" do
    it_behaves_like "card list add/delete operations", true
  end
end
