require "rails_helper"

# CSP で画面の JavaScript / CSS が止まっていないことを、ブラウザのコンソールで確かめる。
#
# CSP 違反は「表示は出るがボタンだけ動かない」という形で出るため、ふつうの
# システムスペックでは見落としやすい。Turbo は body を差し替えるだけで新しい
# ドキュメントを作らず、最初に読み込んだドキュメントの CSP が効き続けるので、
# 画面遷移をまたいだ操作をひととおり踏んでから確認する。
RSpec.describe "CSP 違反が出ないこと", type: :system do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  def csp_violations
    page.driver.browser.logs.get(:browser).filter_map do |entry|
      entry.message if entry.message.include?("Content Security Policy")
    end
  end

  describe "未認証の画面" do
    it "サインイン・招待コード入力・サインアップで違反が出ない" do
      visit signin_path
      visit "/invite"

      invitation = create(:invitation)
      visit signup_path(token: invitation.generate_signup_token)
      click_button "メール＆パスワード"
      expect(page).to have_field("email")
      click_button "キャンセル"

      expect(csp_violations).to be_empty
    end
  end

  describe "一般ユーザーの画面" do
    let(:event) { create(:event) }
    let!(:trade) { create(:trade, event:, user:, status: :pending) }
    let!(:offer) { create(:trade_card_offer, trade:, card_name: "Apple") }

    it "ダッシュボードからトレード明細の操作まで違反が出ない" do
      sign_in(user)
      visit events_path
      visit trade_path(event)

      find("#add_offer_btn").click
      expect(find("#new_trade_card_offer")).to be_visible

      find("#trade_card_offer_#{offer.id}").click_button("編集")
      expect(find("#edit_form_trade_card_offer_#{offer.id}")).to be_visible

      visit histories_path

      expect(csp_violations).to be_empty
    end
  end

  describe "管理画面" do
    let(:event) { create(:event) }
    let(:other_user) { create(:user) }
    let!(:trade) { create(:trade, event:, user: other_user, status: :pending) }
    let!(:offer) { create(:trade_card_offer, trade:, card_name: "Apple") }
    let!(:another_offer) { create(:trade_card_offer, trade:, card_name: "Banana") }

    it "トレード詳細のソートと明細追加、招待コード管理で違反が出ない" do
      sign_in(admin)
      visit admin_event_trade_path(event, trade)

      # Turbo の画面遷移をはさんでから、インライン script が動くか確かめる
      find("#offers_sort_card_name").click
      expect(page).to have_css("#offers_sort_card_name", text: "▲")
      find("#add_offer_btn_admin").click
      expect(find("#new_trade_card_offer_admin")).to be_visible

      visit admin_invitations_path

      expect(csp_violations).to be_empty
    end

    it "ユーザーのゲスト紐づけモーダルで違反が出ない" do
      sign_in(admin)
      visit admin_user_path(other_user)

      expect(csp_violations).to be_empty
    end
  end
end
