require "rails_helper"

RSpec.describe "Histories Tabs Navigation", type: :system do
  let(:user) { create(:user, password: "password123") }
  let(:event) { create(:event) }

  before do
    sign_in user
  end

  describe "タブナビゲーション" do
    context "トレード履歴ページ" do
      before do
        visit histories_path
      end

      it "タブが表示されている" do
        nav = find('nav[aria-label="履歴の種類"]')
        expect(nav).to be_visible
      end

      it "「トレード」タブが強調されている" do
        nav = find('nav[aria-label="履歴の種類"]')
        trades_link = nav.find('a[href="/histories"]')

        expect(trades_link["aria-current"]).to eq("page")
        expect(trades_link["class"]).to include("border-accent")
        expect(trades_link["class"]).to include("text-accent")
      end

      it "「代理通販」タブは強調されていない" do
        nav = find('nav[aria-label="履歴の種類"]')
        proxy_orders_link = nav.find('a[href="/histories/proxy_orders"]')

        expect(proxy_orders_link["aria-current"]).to be_nil
        expect(proxy_orders_link["class"]).to include("border-transparent")
        expect(proxy_orders_link["class"]).to include("text-stone-500")
      end

      it "「代理通販」タブをクリックすると通販履歴ページに移動する" do
        nav = find('nav[aria-label="履歴の種類"]')
        proxy_orders_link = nav.find('a[href="/histories/proxy_orders"]')

        proxy_orders_link.click

        expect(page).to have_current_path("/histories/proxy_orders")
        expect(page).to have_content("通販履歴")
      end
    end

    context "代理通販履歴ページ" do
      before do
        visit proxy_order_histories_path
      end

      it "タブが表示されている" do
        nav = find('nav[aria-label="履歴の種類"]')
        expect(nav).to be_visible
      end

      it "「代理通販」タブが強調されている" do
        nav = find('nav[aria-label="履歴の種類"]')
        proxy_orders_link = nav.find('a[href="/histories/proxy_orders"]')

        expect(proxy_orders_link["aria-current"]).to eq("page")
        expect(proxy_orders_link["class"]).to include("border-accent")
        expect(proxy_orders_link["class"]).to include("text-accent")
      end

      it "「トレード」タブは強調されていない" do
        nav = find('nav[aria-label="履歴の種類"]')
        trades_link = nav.find('a[href="/histories"]')

        expect(trades_link["aria-current"]).to be_nil
        expect(trades_link["class"]).to include("border-transparent")
        expect(trades_link["class"]).to include("text-stone-500")
      end

      it "「トレード」タブをクリックするとトレード履歴ページに移動する" do
        nav = find('nav[aria-label="履歴の種類"]')
        trades_link = nav.find('a[href="/histories"]')

        trades_link.click

        expect(page).to have_current_path("/histories")
        expect(page).to have_content("トレード履歴")
      end
    end

    context "モバイル表示（390px）" do
      before do
        resize_window_to(390, 667)
      end

      it "トレード履歴ページでタブが横に並んでいる" do
        visit histories_path

        nav = find('nav[aria-label="履歴の種類"]')
        links = nav.all('a')

        # 両方のリンクが見えていることを確認
        expect(links.count).to eq(2)
        links.each { |link| expect(link).to be_visible }
      end

      it "代理通販履歴ページでタブが横に並んでいる" do
        visit proxy_order_histories_path

        nav = find('nav[aria-label="履歴の種類"]')
        links = nav.all('a')

        # 両方のリンクが見えていることを確認
        expect(links.count).to eq(2)
        links.each { |link| expect(link).to be_visible }
      end

      it "モバイルでタブをクリックして切り替える" do
        visit histories_path

        nav = find('nav[aria-label="履歴の種類"]')
        proxy_orders_link = nav.find('a[href="/histories/proxy_orders"]')

        proxy_orders_link.click

        expect(page).to have_current_path("/histories/proxy_orders")

        # 代理通販ページで「トレード」をクリック
        nav = find('nav[aria-label="履歴の種類"]')
        trades_link = nav.find('a[href="/histories"]')

        trades_link.click

        expect(page).to have_current_path("/histories")
      end
    end
  end
end
