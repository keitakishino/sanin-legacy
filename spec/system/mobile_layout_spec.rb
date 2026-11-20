require "rails_helper"

RSpec.describe "Mobile Layout", type: :system do
  def page_has_no_horizontal_scroll?
    evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")
  end

  def input_font_size(selector)
    element = find(selector)
    computed_style = page.evaluate_script("getComputedStyle(arguments[0]).fontSize", element.native)
    computed_style.to_f
  end

  describe "[C1] No horizontal scroll at 375px viewport" do
    before { resize_window_to(375, 800) }

    context "未ログイン画面" do
      it "[C1] ログイン画面に横スクロールが発生しない" do
        visit signin_path
        expect(page).to have_field("email") # wait for form to load
        expect(page_has_no_horizontal_scroll?).to be(true)
      end

      it "[C1] 登録画面に横スクロールが発生しない" do
        invitation = create(:invitation)
        token = invitation.generate_signup_token
        visit signup_path(token:)
        # Click the email signup button to show the form
        click_button "メール＆パスワード"
        expect(page).to have_field("username") # wait for form to appear
        expect(page_has_no_horizontal_scroll?).to be(true)
      end
    end

    context "一般ユーザー画面" do
      let(:user) { create(:user, email: "test@example.com", password: "password123") }
      let(:event) { create(:event, :trade, title: "Test Trade") }
      let(:trade) { create(:trade, event:, user:) }
      let(:offer) { create(:trade_card_offer, trade:) }
      let(:want) { create(:trade_card_want, trade:) }

      before do
        sign_in(user)
        offer && want
      end

      it "[C1] ダッシュボードに横スクロールが発生しない" do
        visit root_path
        expect(page).to have_current_path(root_path) # wait for navigation
        expect(page_has_no_horizontal_scroll?).to be(true)
      end

      it "[C1] トレード画面に横スクロールが発生しない" do
        visit trade_path(event)
        expect(page).to have_current_path(trade_path(event)) # wait for navigation
        expect(page_has_no_horizontal_scroll?).to be(true)
      end

      it "[C1] マイページに横スクロールが発生しない" do
        visit mypage_path
        expect(page).to have_current_path(mypage_path) # wait for navigation
        expect(page_has_no_horizontal_scroll?).to be(true)
      end

      it "[C1] マイページ編集に横スクロールが発生しない" do
        visit edit_mypage_path
        expect(page).to have_current_path(edit_mypage_path) # wait for navigation
        expect(page_has_no_horizontal_scroll?).to be(true)
      end

      it "[C1] 履歴一覧に横スクロールが発生しない" do
        visit histories_path
        expect(page).to have_current_path(histories_path) # wait for navigation
        expect(page_has_no_horizontal_scroll?).to be(true)
      end

      it "[C1] 代理通販履歴一覧に横スクロールが発生しない" do
        visit proxy_order_histories_path
        expect(page).to have_current_path(proxy_order_histories_path) # wait for navigation
        expect(page_has_no_horizontal_scroll?).to be(true)
      end
    end

    context "利用者の代理通販画面" do
      let(:user) { create(:user, email: "test@example.com", password: "password123") }
      let(:other_buyer_user) { create(:user, username: "other_buyer", email: "other@example.com", password: "password456") }
      let(:event) { create(:event, :proxy_order, title: "My Proxy Order") }
      let(:proxy_order) { create(:proxy_order, event:, status: :ordered, tax_usd: 10, usd_jpy_rate: nil) }
      let(:me) { create(:proxy_order_participant, proxy_order:, user:) }
      let(:other) { create(:proxy_order_participant, proxy_order:, user: other_buyer_user) }
      let(:item_a) { create(:proxy_order_item, proxy_order:, card_name: "Mine Card") }
      let(:item_b) { create(:proxy_order_item, proxy_order:, card_name: "Others Only Card") }

      before do
        sign_in(user)
        create(:proxy_order_price_line, proxy_order_item: item_a, quantity: 2, unit_price_usd: 5.00)
        create(:proxy_order_price_line, proxy_order_item: item_b, quantity: 3, unit_price_usd: 10.00)
        create(:proxy_order_allocation, proxy_order_item: item_a, proxy_order_participant: me, quantity: 2, lost_quantity: 0)
        create(:proxy_order_allocation, proxy_order_item: item_b, proxy_order_participant: other, quantity: 3, lost_quantity: 0)
      end

      it "[C1] 利用者の代理通販画面に横スクロールが発生しない" do
        visit proxy_order_path(event.id)
        expect(page).to have_css("#proxy_order_my_items", wait: 5) # wait for table to load
        expect(page_has_no_horizontal_scroll?).to be(true)
      end
    end

    context "管理者画面" do
      let(:admin_user) { create(:user, :admin, email: "admin@example.com", password: "password123") }

      before do
        sign_in(admin_user)
      end

      it "[C1] 管理画面イベント一覧に横スクロールが発生しない" do
        visit admin_events_path
        expect(page).to have_current_path(admin_events_path) # wait for navigation
        expect(page_has_no_horizontal_scroll?).to be(true)
      end

      it "[C1] 新規イベント作成画面に横スクロールが発生しない" do
        visit new_admin_event_path
        expect(page).to have_current_path(new_admin_event_path) # wait for navigation
        expect(page_has_no_horizontal_scroll?).to be(true)
      end

      it "[C1] 管理画面ユーザー一覧に横スクロールが発生しない" do
        visit admin_users_path
        expect(page).to have_current_path(admin_users_path) # wait for navigation
        expect(page_has_no_horizontal_scroll?).to be(true)
      end

      it "[C1] 管理画面代理通販に横スクロールが発生しない" do
        event = create(:event, :proxy_order, title: "Admin Proxy")
        proxy_order = create(:proxy_order, event:)
        create(:proxy_order_item, proxy_order:, card_name: "Test Card")

        visit admin_event_proxy_order_path(event)
        expect(page).to have_current_path(admin_event_proxy_order_path(event)) # wait for navigation
        expect(page_has_no_horizontal_scroll?).to be(true)
      end

      it "[C1] 管理画面ユーザー詳細に横スクロールが発生しない" do
        target_user = create(:user, email: "target@example.com", password: "password123")

        visit admin_user_path(target_user)
        expect(page).to have_current_path(admin_user_path(target_user)) # wait for navigation
        expect(page_has_no_horizontal_scroll?).to be(true)
      end

      it "[C1] 管理画面招待一覧に横スクロールが発生しない" do
        visit admin_invitations_path
        expect(page).to have_current_path(admin_invitations_path) # wait for navigation
        expect(page_has_no_horizontal_scroll?).to be(true)
      end

      it "[C1] 管理画面監査ログ一覧に横スクロールが発生しない" do
        visit admin_audit_logs_path
        expect(page).to have_current_path(admin_audit_logs_path) # wait for navigation
        expect(page_has_no_horizontal_scroll?).to be(true)
      end

      it "[C1] 管理画面トレード詳細に横スクロールが発生しない" do
        event = create(:event, :trade, title: "Admin Trade")
        user = create(:user, email: "trader@example.com", password: "password123")
        trade = create(:trade, event:, user:)
        create(:trade_card_offer, trade:)
        create(:trade_card_want, trade:)

        visit admin_event_trade_path(event, trade)
        expect(page).to have_current_path(admin_event_trade_path(event, trade)) # wait for navigation
        expect(page_has_no_horizontal_scroll?).to be(true)
      end
    end
  end

  describe "[C4] Input font size is 16px or more at 375px viewport" do
    before { resize_window_to(375, 800) }

    it "[C4] ログイン画面のメールアドレス欄が16px以上" do
      visit signin_path
      expect(page).to have_field("email") # wait for form to load

      # 実際の computed font-size を計測
      expect(input_font_size("input[name='email']")).to be >= 16
    end

    it "[C4] トレード画面のカード名入力欄が16px以上" do
      user = create(:user, email: "test@example.com", password: "password123")
      event = create(:event, :trade, title: "Test Trade")
      trade = create(:trade, event:, user:)
      create(:trade_card_offer, trade:)
      create(:trade_card_want, trade:)

      sign_in(user)
      visit trade_path(event)
      expect(page).to have_current_path(trade_path(event)) # wait for navigation

      click_button "add_offer_btn"
      expect(page).to have_field("trade_card_offer[card_name]") # wait for form to appear

      # 実際の computed font-size を計測
      expect(input_font_size("input[name='trade_card_offer[card_name]']")).to be >= 16
    end
  end

  describe "[C5] Input font size remains unchanged at 1280px viewport" do
    before { resize_window_to(1280, 900) }

    it "[C5] ログイン画面のメールアドレス欄が14px" do
      visit signin_path
      expect(page).to have_field("email") # wait for form to load

      # デスクトップ幅ではスマホ CSS は効かない（max-width: 47.9375rem なので）元の 14px が保たれる
      expect(input_font_size("input[name='email']")).to eq 14
    end

    it "[C5] トレード画面のカード名入力欄が12px" do
      user = create(:user, email: "test@example.com", password: "password123")
      event = create(:event, :trade, title: "Test Trade")
      trade = create(:trade, event:, user:)
      create(:trade_card_offer, trade:)
      create(:trade_card_want, trade:)

      sign_in(user)
      visit trade_path(event)
      expect(page).to have_current_path(trade_path(event)) # wait for navigation

      click_button "add_offer_btn"
      expect(page).to have_field("trade_card_offer[card_name]") # wait for form to appear

      # デスクトップ幅ではスマホ CSS は効かない（max-width: 47.9375rem なので）元の 12px が保たれる
      expect(input_font_size("input[name='trade_card_offer[card_name]']")).to eq 12
    end
  end
end
