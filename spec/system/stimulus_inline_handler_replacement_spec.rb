require "rails_helper"

# CSP 対応でインラインの onclick / onchange を Stimulus に置き換えた箇所が、
# 実ブラウザでそれまでどおり動くことを確認する。
#
# 置き換えた箇所のうち、次のものは既存のシステムスペックが踏んでいるので、ここでは扱わない。
#   - edit-form-toggle（カード明細の編集行）: trade_edit_form_close_spec ほか
#   - auto-submit#submitForm（モバイルのソート select）: trade_card_list_search_sort_paging_spec ほか
#   - radio-required（紐づけの送信ボタン活性化）: admin_user_guest_link_spec C4
#   - modal（紐づけ解除モーダルのキャンセル）: admin_user_guest_unlink_spec C2
#
# ここで押さえるのは、既存のスペックが触れていなかった残りの 3 画面。
RSpec.describe "インラインハンドラの Stimulus 置き換え", type: :system do
  describe "イベント詳細モーダル（modal コントローラ）" do
    let(:user) { create(:user) }
    let!(:event) { create(:event, title: "モーダル確認イベント") }

    before { sign_in(user) }

    def open_event_modal
      visit events_path
      find("a[href='#{event_path(event)}']").click
      expect(page).to have_css("turbo-frame#event_modal h2", text: event.title)
    end

    it "ヘッダーの × で閉じる" do
      open_event_modal

      find("turbo-frame#event_modal button[data-modal-frame-value='event_modal']", match: :first).click

      expect(page).to have_no_css("turbo-frame#event_modal h2")
    end

    it "フッターの「閉じる」で閉じる" do
      open_event_modal

      click_button "閉じる"

      expect(page).to have_no_css("turbo-frame#event_modal h2")
    end
  end

  describe "ゲスト紐づけモーダル（modal コントローラ）" do
    let(:admin) { create(:user, role: :admin) }
    let(:target_user) { create(:user) }
    let!(:event) { create(:event, event_type: :proxy_order, title: "イベント1", created_by: admin) }
    let!(:proxy_order) { create(:proxy_order, event:) }

    before do
      create(:proxy_order_participant, :guest, proxy_order:, guest_name: "Aさん")
      sign_in(admin)
      resize_window_to(1280, 900)
    end

    def open_guest_link_modal
      visit admin_user_path(target_user)
      click_link "自由入力の参加者を紐づける"
      expect(page).to have_css("turbo-frame#guest_link_modal")
      expect(page).to have_button("検索")
    end

    it "ヘッダーの × で閉じる" do
      open_guest_link_modal

      find("turbo-frame#guest_link_modal button[data-modal-frame-value='guest_link_modal']", match: :first).click

      expect(page).to have_no_button("検索")
    end

    it "候補を出したあと「キャンセル」で閉じる" do
      open_guest_link_modal

      within("turbo-frame#guest_link_modal") do
        click_button "検索"
        expect(page).to have_text("Aさん")
        click_button "キャンセル"
      end

      expect(page).to have_no_text("Aさん")
      expect(page).to have_no_button("検索")
    end
  end

  describe "サインアップのメールフォーム（email-signup-form コントローラ）" do
    let(:invitation) { create(:invitation) }

    it "「メール＆パスワード」で開き、「キャンセル」で閉じる" do
      visit signup_path(token: invitation.generate_signup_token)

      expect(page).to have_no_field("email")

      click_button "メール＆パスワード"
      expect(page).to have_field("email")
      expect(page).to have_field("username")

      click_button "キャンセル"
      expect(page).to have_no_field("email")
    end
  end
end
