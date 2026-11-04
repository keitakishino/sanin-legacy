require "rails_helper"

# Turbo の画面遷移（body の差し替え）で入った画面でも、ビュー内のインライン
# <script> が動くことを確かめる。
#
# Turbo は新しいドキュメントを作らず body を差し替えるだけなので、CSP は最初に
# 読み込んだドキュメントのものが効き続ける。インライン <script> の nonce が
# それと食い違うと、直接開いたときは動くのに Turbo 遷移で入ると動かない、という
# 形で壊れる（リロードすれば直るので気づきにくい）。
RSpec.describe "Turbo 遷移後のインライン script", type: :system do
  describe "トレード編集画面の明細追加ボタン" do
    let(:user) { create(:user) }
    let!(:event) { create(:event, title: "トレードイベント", event_type: :trade) }

    before { sign_in(user) }

    it "直接開いた場合は反応する（対照）" do
      visit trade_path(event.id)

      find("#add_offer_btn").click

      expect(find("#new_trade_card_offer")).to be_visible
    end

    it "イベント一覧 → モーダル → Turbo 遷移で入った場合も反応する" do
      visit events_path
      find("a[href='#{event_path(event)}']").click
      expect(page).to have_link("自分のトレードを編集する")

      click_link "自分のトレードを編集する"
      expect(page).to have_current_path(trade_path(event.id))
      expect(page).to have_css("#add_offer_btn")

      find("#add_offer_btn").click

      expect(find("#new_trade_card_offer")).to be_visible
    end
  end
end
