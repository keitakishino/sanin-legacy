require "rails_helper"

RSpec.describe "User Proxy Order History", type: :system do
  let(:user) { create(:user, password: "password123") }
  let(:other_user) { create(:user, password: "password456") }
  let(:event) { create(:event, :proxy_order, title: "History Proxy Order") }
  let(:proxy_order) do
    create(:proxy_order, event:, status: :completed, usd_jpy_rate: 150, tax_usd: 0)
  end
  let(:me) { create(:proxy_order_participant, proxy_order:, user:) }
  let(:other) { create(:proxy_order_participant, proxy_order:, user: other_user) }
  let(:item) { create(:proxy_order_item, proxy_order:, card_name: "History Card") }

  before do
    sign_in(user)
    resize_window_to(1280, 900)

    create(:proxy_order_price_line, proxy_order_item: item, quantity: 2, unit_price_usd: 5.00)
    create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: me, quantity: 2, lost_quantity: 0)
  end

  describe "C1: 履歴→代理通販タブ→完了済みの行が見える" do
    it "ヘッダーの「履歴」を押すと履歴ページに移動する" do
      visit root_path
      within("header nav.hidden") { click_link "履歴" }
      expect(page).to have_current_path(histories_path)
    end

    it "通販履歴ページで「代理通販」タブを押すと通販履歴ページに移動する" do
      visit histories_path
      within('nav[aria-label="履歴の種類"]') { click_link "代理通販" }
      expect(page).to have_current_path(proxy_order_histories_path)
    end

    it "通販履歴ページに完了済みの通販の行が見える" do
      visit proxy_order_histories_path
      row = find("#history_proxy_order_#{proxy_order.id}")
      within(row) do
        expect(page).to have_content("History Proxy Order")
        expect(page).to have_content(I18n.t("activerecord.enums.proxy_order.status.completed"))
      end
    end

    it "完了済みの通販の支払い金額が表示される" do
      visit proxy_order_histories_path
      expected_jpy = "¥" + ActiveSupport::NumberHelper.number_to_delimited(
        ProxyOrderCalculator.new(proxy_order.reload).payment_jpy(me)
      )
      row = find("#history_proxy_order_#{proxy_order.id}")
      within(row) do
        expect(page).to have_content(expected_jpy)
      end
    end

    it "金額セルが tabular-nums クラスを持っている" do
      visit proxy_order_histories_path
      row = find("#history_proxy_order_#{proxy_order.id}")
      payment_cell = row.find("td.tabular-nums")
      expect(payment_cell).to be_visible
    end
  end

  describe "C2: 詳細を表示で閲覧画面に着き、金額が履歴と同じ" do
    it "通販履歴から詳細を表示を押すと閲覧画面に移動する" do
      visit proxy_order_histories_path
      row = find("#history_proxy_order_#{proxy_order.id}")
      history_amount = within(row) { find("td.tabular-nums").text.strip }

      within(row) { click_link I18n.t("histories.proxy_orders.view_details") }
      expect(page).to have_current_path(proxy_order_path(event.id))
      expect(page).to have_content("History Proxy Order")

      payment_jpy_text = find("[data-role='payment-jpy']").text.strip
      expect(payment_jpy_text).to eq(history_amount)
    end

    it "支払い金額が両ページで同じフォーマットで表示される" do
      visit proxy_order_histories_path
      row = find("#history_proxy_order_#{proxy_order.id}")
      history_amount = within(row) { find("td.tabular-nums").text.strip }

      within(row) { click_link I18n.t("histories.proxy_orders.view_details") }
      expect(page).to have_current_path(proxy_order_path(event.id))

      # 金額は ¥数字 のフォーマット（カンマ区切り）
      expect(history_amount).to match(/^¥[\d,]+$/)
      payment_jpy_text = find("[data-role='payment-jpy']").text.strip
      expect(payment_jpy_text).to match(/^¥[\d,]+$/)
    end
  end

  describe "C3: 他人だけの完了済み代理通販は行が出ない" do
    it "他ユーザーだけが参加した完了済み通販は表示されない" do
      other_event = create(:event, :proxy_order, title: "Other User Only Proxy")
      other_proxy_order = create(:proxy_order, event: other_event, status: :completed, usd_jpy_rate: 150)
      create(:proxy_order_participant, proxy_order: other_proxy_order, user: other_user)

      visit proxy_order_histories_path
      expect(page).to have_current_path(proxy_order_histories_path)
      expect(page).not_to have_css("#history_proxy_order_#{other_proxy_order.id}")
    end
  end

  describe "C4: 自分の通販は履歴に表示される" do
    it "自分が参加した完了済み通販が表示される" do
      visit proxy_order_histories_path
      expect(page).to have_css("#history_proxy_order_#{proxy_order.id}")
      within("#history_proxy_order_#{proxy_order.id}") do
        expect(page).to have_content("History Proxy Order")
      end
    end
  end

  describe "[C5] Items with blank foil and frame in history" do
    before do
      blank_item = create(:proxy_order_item, proxy_order:, card_name: "Blank Foil Frame History", expansion: nil, foil: nil, frame: nil)
      create(:proxy_order_price_line, proxy_order_item: blank_item, quantity: 1, unit_price_usd: 3.00)
      create(:proxy_order_allocation, proxy_order_item: blank_item, proxy_order_participant: me, quantity: 1, lost_quantity: 0)
    end

    it "[C5] displays history row with blank foil and frame without error" do
      visit proxy_order_histories_path
      row = find("#history_proxy_order_#{proxy_order.id}")
      expect(row).to be_visible
      expect(page).not_to have_selector("div.error-message")
    end
  end
end
