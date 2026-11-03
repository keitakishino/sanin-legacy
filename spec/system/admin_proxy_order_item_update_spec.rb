require "rails_helper"

RSpec.describe "Admin Proxy Order Item Update", type: :system do
  include ActionView::RecordIdentifier

  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
  let!(:buyer) { create(:user, username: "buyer") }
  let!(:tanaka) { create(:user, username: "Tanaka") }

  before do
    sign_in(admin)
    resize_window_to(1280, 900)
    visit admin_event_proxy_order_path(event)
  end

  def set_and_commit(selector, value)
    field = find(selector)
    field.set(value)
    field.send_keys(:tab)
  end

  def add_card(name)
    within "#new_proxy_order_item_form" do
      fill_in "proxy_order_item[card_name]", with: name
      click_button "カード明細を追加"
    end
    expect(page).to have_content("カードを追加しました")
    ProxyOrderItem.order(:id).last
  end

  def add_price_line(item, unit_price:, quantity:)
    within "#new_price_line_proxy_order_item_#{item.id}" do
      fill_in "proxy_order_price_line[unit_price_usd]", with: unit_price
      fill_in "proxy_order_price_line[quantity]", with: quantity
      click_button "＋ 価格行を追加"
    end
    expect(page).to have_content("価格行を追加しました")
  end

  def add_user(item, user:, quantity:)
    within "#new_allocation_proxy_order_item_#{item.id}" do
      find("input[role='combobox']").set(user.username)
      find("[role='listbox'] [role='option']", text: user.username, match: :first).click
      fill_in "proxy_order_allocation[quantity]", with: quantity
      click_button "追加"
    end
end

  describe "C6: 価格行の数量を変えて Tab で次の要素（価格行の削除ボタン）へ移ると、保存のトーストが出たあとも、フォーカスがその削除ボタンに残っている" do
    it "focuses remain on delete button after quantity update via Tab" do
      item = add_card("Test Card")
      add_price_line(item, unit_price: "3.00", quantity: "1")
      add_user(item, user: buyer, quantity: "1")
      expect(page).to have_content("注文を追加しました")

      # 数量を変更して Tab で抜ける
      line = ProxyOrderPriceLine.order(:id).last
      set_and_commit "#proxy_order_price_line_#{line.id} input[name='proxy_order_price_line[quantity]']", "2"
      expect(page).to have_content("価格行を更新しました")

      # フォーカスが削除ボタンに残っていることを確認
      is_focused_on_delete = page.evaluate_script("document.activeElement.closest('#delete_proxy_order_price_line_#{line.id}') !== null")
      expect(is_focused_on_delete).to be true
    end
  end

  describe "C7: 手数料合計 $10 で参加者 1 人のとき、別のユーザーの注文を追加すると、リロードせずに #proxy_order_fee_tiles の表示が「参加者2人」に、#proxy_order_fee_per_person が $5.00 に変わる" do
    it "fee tiles update with new participant count and amount" do
      # 事前に税を設定する
      within "#proxy_order_fees_form" do
        fill_in "proxy_order[tax_usd]", with: "10.00"
        click_button "保存"
      end
      expect(page).to have_content("税・送料・レートを更新しました")

      item = add_card("Test Card")
      add_price_line(item, unit_price: "3.00", quantity: "1")
      add_user(item, user: buyer, quantity: "1")
      expect(page).to have_content("注文を追加しました")

      # マーカーをセット
      page.evaluate_script("window.__marker = 1")

      # 初期状態を確認
      within "#proxy_order_fee_tiles" do
        expect(page).to have_content("参加者1人")
        expect(find("#proxy_order_fee_per_person")).to have_text("$10.00")
      end

      # ユーザーを追加
      add_user(item, user: tanaka, quantity: "1")
      expect(page).to have_content("注文を追加しました")

      # タイルが更新されたことを確認
      within "#proxy_order_fee_tiles" do
        expect(page).to have_content("参加者2人")
        expect(find("#proxy_order_fee_per_person")).to have_text("$5.00")
      end

      # ページがリロードされていないことを確認
      marker = page.evaluate_script("window.__marker")
      expect(marker).to eq(1)
    end
  end

  describe "C8: 税の入力欄に保存していない値（99.99）を入れたまま注文を追加しても、その入力欄の値は 99.99 のまま残る" do
    it "unsaved tax input value persists after adding user" do
      item = add_card("Test Card")
      add_price_line(item, unit_price: "3.00", quantity: "1")
      add_user(item, user: buyer, quantity: "1")
      expect(page).to have_content("注文を追加しました")

      # 税の入力欄に値を入れるが保存しない
      within "#proxy_order_fees_form" do
        fill_in "proxy_order[tax_usd]", with: "99.99"
      end

      # ユーザーを追加
      add_user(item, user: tanaka, quantity: "1")
      expect(page).to have_content("注文を追加しました")

      # 税の入力欄の値が残っていることを確認
      tax_input_value = find("#proxy_order_fees_form input[name='proxy_order[tax_usd]']").value
      expect(tax_input_value).to eq("99.99")
    end
  end
end
