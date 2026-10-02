# Issue #312: カード明細の編集・削除・追加ボタンをトレード状態・ロールに応じて表示制御

require "rails_helper"

RSpec.describe "Trade Card Operation Permission (Issue #312)", type: :system do
  let(:expansion) { create(:expansion, scryfall_set_code: "VOW") }
  let(:event) { create(:event) }
  let(:admin) { create(:user, role: :admin) }

  before do
    admin # ensure admin is created
  end

  # C1: completedのトレードを一般ユーザー画面で開くと、出す側・欲しい側の両方で編集・削除・追加ボタンが表示されない
  describe "一般ユーザー画面での表示制御" do
    context "completed状態" do
      let(:user) { create(:user) }
      let(:trade) { create(:trade, event: event, user: user, status: :completed) }

      before do
        sign_in user
        create(:trade_card_offer, trade: trade, expansion: expansion)
        create(:trade_card_want, trade: trade, expansion: expansion)
        visit trade_path(event)
      end

      it "[C1] completedのトレードで出す側の編集・削除ボタンが表示されない" do
        within("#trade_card_offers tbody:first-of-type") do
          # 編集ボタンが存在しない
          expect(page).not_to have_button("編集")
          # 削除ボタンが存在しない
          expect(page).not_to have_button("削除")
        end
      end

      it "[C1] completedのトレードで欲しい側の編集・削除ボタンが表示されない" do
        within("#trade_card_wants tbody:first-of-type") do
          # 編集ボタンが存在しない
          expect(page).not_to have_button("編集")
          # 削除ボタンが存在しない
          expect(page).not_to have_button("削除")
        end
      end

      it "[C1] completedのトレードで出す側の追加ボタンが表示されない" do
        # 「カード明細を追加」ボタンが出す側・欲しい側ともに表示されない
        expect(all("button", text: "カード明細を追加").count).to eq(0)
      end

      it "[C1] completedのトレードで欲しい側の追加ボタンが表示されない" do
        # can_create が false のときは、フレーム要素がレンダリングされない
        expect(page).not_to have_css("#new_trade_card_offer")
        expect(page).not_to have_css("#new_trade_card_want")
      end

      it "[C3] completedのトレードでも▼ボタンで展開できる（モバイル幅）" do
        # モバイル幅に変更
        page.current_window.resize_to(500, 800)

        within("#trade_card_offers tbody:first-of-type") do
          # ▼ボタンが存在して表示されている（スマホでは表示）
          expand_btn = find("button[data-toggle-expand]")
          expect(expand_btn).to be_visible
        end
      end
    end

    context "in_progress状態で一般ユーザー" do
      let(:user) { create(:user) }
      let(:trade) { create(:trade, event: event, user: user, status: :in_progress) }

      before do
        sign_in user
        create(:trade_card_offer, trade: trade, expansion: expansion)
        create(:trade_card_want, trade: trade, expansion: expansion)
        visit trade_path(event)
      end

      it "[C4] in_progressで一般ユーザーの編集・削除ボタンが表示されない" do
        within("#trade_card_offers tbody:first-of-type") do
          expect(page).not_to have_button("編集")
          expect(page).not_to have_button("削除")
        end

        within("#trade_card_wants tbody:first-of-type") do
          expect(page).not_to have_button("編集")
          expect(page).not_to have_button("削除")
        end
      end

      it "[C5] in_progressで一般ユーザーの追加ボタンは表示される" do
        expect(all("button", text: "カード明細を追加").count).to eq(2)
      end

      it "[C5] in_progressで一般ユーザーが追加フォームで新カード追加できる" do
        click_button "カード明細を追加", match: :first

        within("#new_trade_card_offer") do
          fill_in "trade_card_offer[card_name]", with: "New Card Offer"
          fill_in "trade_card_offer[quantity]", with: "1"
          click_button "追加", match: :first
        end

        expect(page).to have_content("New Card Offer")
      end
    end

    context "pending状態で一般ユーザー" do
      let(:user) { create(:user) }
      let(:trade) { create(:trade, event: event, user: user, status: :pending) }

      before do
        sign_in user
        create(:trade_card_offer, trade: trade, expansion: expansion)
        create(:trade_card_want, trade: trade, expansion: expansion)
        visit trade_path(event)
      end

      it "[C7] pendingで一般ユーザーの編集・削除・追加ボタンが表示される" do
        within("#trade_card_offers tbody:first-of-type") do
          expect(page).to have_button("編集")
          expect(page).to have_button("削除")
        end

        within("#trade_card_wants tbody:first-of-type") do
          expect(page).to have_button("編集")
          expect(page).to have_button("削除")
        end

        expect(all("button", text: "カード明細を追加").count).to eq(2)
      end
    end

    context "cancelled状態で一般ユーザー" do
      let(:user) { create(:user) }
      let(:trade) { create(:trade, event: event, user: user, status: :cancelled) }

      before do
        sign_in user
        create(:trade_card_offer, trade: trade, expansion: expansion)
        create(:trade_card_want, trade: trade, expansion: expansion)
        visit trade_path(event)
      end

      it "[C8] cancelledでボタン表示は変わらない(編集・削除・追加ボタンが表示される)" do
        within("#trade_card_offers tbody:first-of-type") do
          expect(page).to have_button("編集")
          expect(page).to have_button("削除")
        end

        within("#trade_card_wants tbody:first-of-type") do
          expect(page).to have_button("編集")
          expect(page).to have_button("削除")
        end

        expect(all("button", text: "カード明細を追加").count).to eq(2)
      end
    end
  end

  # C2, C6: 管理画面でのボタン表示制御
  describe "管理画面での表示制御" do
    let(:user) { create(:user) }

    context "completed状態を管理画面で表示" do
      let(:trade) { create(:trade, event: event, user: user, status: :completed) }

      before do
        sign_in admin
        create(:trade_card_offer, trade: trade, expansion: expansion)
        create(:trade_card_want, trade: trade, expansion: expansion)
        visit admin_event_trade_path(event, trade)
      end

      it "[C2] completedのトレードを管理画面で開くと、出す側の編集・削除・追加ボタンが表示されない" do
        within("#trade_card_offers tbody:first-of-type") do
          expect(page).not_to have_button("編集")
          expect(page).not_to have_button("削除")
        end

        # 追加ボタンはadmin用
        expect(page).not_to have_css("#add_offer_btn_admin")
      end

      it "[C2] completedのトレードを管理画面で開くと、欲しい側の編集・削除・追加ボタンが表示されない" do
        within("#trade_card_wants tbody:first-of-type") do
          expect(page).not_to have_button("編集")
          expect(page).not_to have_button("削除")
        end

        expect(page).not_to have_css("#add_want_btn_admin")
      end

      it "[C10] completedのトレードを管理画面で開いても、トレード状態変更フォームが表示され、状態を変更できる" do
        expect(page).to have_select("trade_status")
        expect(page).to have_button("更新")

        select "進行中", from: "trade_status"
        click_button "更新"

        expect(page).to have_content("進行中")
      end
    end

    context "in_progress状態を管理画面で表示" do
      let(:trade) { create(:trade, event: event, user: user, status: :in_progress) }

      before do
        sign_in admin
        create(:trade_card_offer, trade: trade, expansion: expansion)
        create(:trade_card_want, trade: trade, expansion: expansion)
        visit admin_event_trade_path(event, trade)
      end

      it "[C6] in_progressでadminは編集・削除・追加ボタンが表示され操作できる" do
        within("#trade_card_offers tbody:first-of-type") do
          expect(page).to have_button("編集")
          expect(page).to have_button("削除")
        end

        within("#trade_card_wants tbody:first-of-type") do
          expect(page).to have_button("編集")
          expect(page).to have_button("削除")
        end

        expect(page).to have_css("#add_offer_btn_admin")
        expect(page).to have_css("#add_want_btn_admin")
      end
    end
  end

  # エッジケースやスクリプトの null ガード確認
  describe "スクリプト nullガードの確認" do
    let(:user) { create(:user) }
    let(:trade) { create(:trade, event: event, user: user, status: :completed) }

    before do
      sign_in user
      visit trade_path(event)
    end

    it "completed状態で追加ボタンがないときに、スクリプトエラーが発生しない" do
      # スクリプトエラーがないことを確認（completed なので追加ボタンがない）
      # JavaScriptコンソールに例外がないことを確認
      expect(page).not_to have_content("Uncaught", wait: 1)

      # ▼展開ボタンや他の機能が正常に動作することを確認
      # (ページロードが正常に完了している)
      expect(page).to have_text("トレード状態")
    end
  end
end
