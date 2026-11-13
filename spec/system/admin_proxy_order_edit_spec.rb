require "rails_helper"

RSpec.describe "Admin Proxy Order Edit", type: :system do
  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
  # 参加者に選ぶユーザーは画面を開く前に作る（登録ユーザーの選択肢は描画時に決まる）
  let!(:buyer) { create(:user, username: "buyer") }
  let!(:tanaka) { create(:user, username: "Tanaka") }

  before do
    sign_in(admin)
    resize_window_to(1280, 900)
    visit admin_event_proxy_order_path(event)
  end

  # 明細の入力はその場で保存される（auto-submit）。change は blur で発火するので、
  # 値を入れたあと必ずフォーカスを外す
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

  # JS の String.prototype.trim と同じ規則で前後の空白を落とす。
  # Ruby の String#strip は全角空白（U+3000）を落とさないので使わない
  def js_trim(value)
    value.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
  end

  # 「ユーザーを追加」はコンボボックス 1 つに統合されている。
  # 画面の操作だけで行う（hidden field を直接触らない）
  def add_user(item, quantity:, user: nil, guest_name: nil)
    within "#new_allocation_proxy_order_item_#{item.id}" do
      find("input[role='combobox']").set(user ? user.username : guest_name)

      # ゲスト行のラベルは入力値を JS の trim() にかけた文字列で作られる
      option_text = user ? user.username : "『#{js_trim(guest_name)}』をゲストとして追加"
      find("[role='listbox'] [role='option']", text: option_text, match: :first).click

      fill_in "proxy_order_allocation[quantity]", with: quantity
      click_button "追加"
    end
  end

  describe "C1: Add, edit, delete card, price lines, and users" do
    it "can add a card, price lines, and users from inside the card block" do
      item = add_card("Black Lotus")

      expect(page).to have_selector("#proxy_order_items details", text: "Black Lotus")

      add_price_line(item, unit_price: "2.00", quantity: "3")

      add_user(item, user: admin, quantity: "3")
      expect(page).to have_content("注文を追加しました")
      expect(page).to have_content(admin.username)

      add_user(item, guest_name: "Guest Taro", quantity: "1")
      expect(page).to have_content("注文を追加しました")
      expect(page).to have_content("Guest Taro")
      expect(ProxyOrderParticipant.count).to eq(2)

      # カード情報の更新
      set_and_commit "#edit_form_proxy_order_item_#{item.id} input[name='proxy_order_item[card_name]']", "Black Lotus (Updated)"
      expect(page).to have_content("カードを更新しました")
      expect(page).to have_content("Black Lotus (Updated)")

      # 価格行の更新（その場で保存される）
      line = ProxyOrderPriceLine.order(:id).last
      set_and_commit "#proxy_order_price_line_#{line.id} input[name='proxy_order_price_line[quantity]']", "5"
      expect(page).to have_content("価格行を更新しました")
      expect(line.reload.quantity).to eq(5)

      # 削除
      within "#delete_proxy_order_price_line_#{line.id}" do
        accept_confirm { click_button "削除" }
      end
      expect(page).to have_content("価格行を削除しました")

      allocation = ProxyOrderAllocation.order(:id).last
      within "#delete_proxy_order_allocation_#{allocation.id}" do
        accept_confirm { click_button "削除" }
      end
      expect(page).to have_content("注文を削除しました")

      within "#delete_proxy_order_item_#{item.id}" do
        accept_confirm { click_button "削除" }
      end
      expect(page).to have_content("カードを削除しました")
    end
  end

  describe "C2: Update calculations without page reload" do
    it "updates unit price and payment amount when quantity changes" do
      item = add_card("Test Card")
      add_price_line(item, unit_price: "3.00", quantity: "4")
      add_price_line(item, unit_price: "4.00", quantity: "6")

      add_user(item, user: buyer, quantity: "10")
      expect(page).to have_content("注文を追加しました")

      page.execute_script("window.__marker = 1")

      line = ProxyOrderPriceLine.order(:id).first
      set_and_commit "#proxy_order_price_line_#{line.id} input[name='proxy_order_price_line[quantity]']", "2"
      expect(page).to have_content("価格行を更新しました")

      expect(page.evaluate_script("window.__marker")).to eq(1)
      expect(page.first("[data-role='unit-price']")).to have_content("$3")
    end
  end

  describe "C3: Duplicate user validation" do
    it "prevents the same user twice in one card but allows duplicate prices" do
      user = buyer
      item = add_card("Test Card")

      add_user(item, user: user, quantity: "5")
      expect(page).to have_content("注文を追加しました")

      # 2回目は同じユーザーが選べない（disabled）
      within "#new_allocation_proxy_order_item_#{item.id}" do
        find("input[role='combobox']").set(user.username)
        expect(page).to have_selector("[role='option'][aria-disabled='true']", text: user.username)
        expect(page).to have_content("この明細に追加済み")
        expect(page).to have_button("追加", disabled: true)
      end
      expect(ProxyOrderAllocation.count).to eq(1)
      expect(ProxyOrderParticipant.count).to eq(1)

      add_price_line(item, unit_price: "2.00", quantity: "3")
      add_price_line(item, unit_price: "2.00", quantity: "2")
      expect(ProxyOrderPriceLine.count).to eq(2)
    end
  end

  describe "C4: Guest name conflict validation" do
    it "prevents a guest name that matches a registered username" do
      item = add_card("Test Card")

      within "#new_allocation_proxy_order_item_#{item.id}" do
        find("input[role='combobox']").set("　ＴＡＮＡＫＡ　")

        # ゲスト行が disabled で、理由が表示される
        guest_option = find("[role='option'][aria-disabled='true']", text: "『ＴＡＮＡＫＡ』をゲストとして追加")
        expect(guest_option).to have_selector("[data-role='disabled-reason']", text: "登録ユーザー Tanaka と同じ名前のため、ゲストにはできません")

        # ゲスト行をクリックしても追加ボタンは enabled にならない
        guest_option.click
        expect(page).to have_button("追加", disabled: true)
      end

      expect(ProxyOrderParticipant.count).to eq(0)
      expect(ProxyOrderAllocation.count).to eq(0)
    end
  end

  describe "C7: Navigation link in event index" do
    it "shows details link only for proxy order events" do
      visit admin_events_path

      within "table" do
        expect(page).to have_link("明細", href: admin_event_proxy_order_path(event))
      end
    end
  end

  describe "[C6] C8: Update tax, shipping, rate" do
    it "updates fee calculations without reload" do
      item = add_card("Test")
      add_price_line(item, unit_price: "10.00", quantity: "1")
      add_user(item, user: buyer, quantity: "1")
      expect(page).to have_content("注文を追加しました")

      page.execute_script("window.__marker = 1")

      within "#proxy_order_fees_form" do
        fill_in "proxy_order[usd_jpy_rate]", with: "150.00"
        click_button "保存"
      end

      expect(page).to have_content("税・送料・決済手数料・レートを更新しました")
      expect(page.evaluate_script("window.__marker")).to eq(1)
      expect(page).to have_content("未確定").or have_text("¥")
    end
  end

  describe "C9: Card collapse and expand" do
    it "[C7] shows the card name, set/foil/frame and totals in the summary" do
      within "#new_proxy_order_item_form" do
        fill_in "proxy_order_item[card_name]", with: "Collapsed Card"
        select "non-foil", from: "proxy_order_item[foil]"
        select "通常", from: "proxy_order_item[frame]"
        click_button "カード明細を追加"
      end
      expect(page).to have_content("カードを追加しました")

      within first("details") do
        within "summary" do
          expect(page).to have_selector("[data-role='card-name']", text: "Collapsed Card")
          expect(page).to have_selector("[data-role='card-meta']", text: "non-foil ／ 通常")
          expect(page).to have_selector("[data-role='ordered-quantity']", text: "0")
          expect(page).to have_selector("[data-role='unit-price']", text: "$0.00")
        end
      end
    end

    it "opens card automatically when quantity mismatch" do
      item = add_card("Mismatch Card")
      add_price_line(item, unit_price: "5.00", quantity: "10")

      within first("details") do
        expect(page).to have_selector("[id*='mismatch']")
      end
    end

    it "opens card automatically when newly added" do
      add_card("New Card")

      expect(find("details[open]")).to have_content("New Card")
    end

    it "shows a match chip when quantity and order quantity agree" do
      item = add_card("Matched Card")
      add_price_line(item, unit_price: "5.00", quantity: "2")
      add_user(item, user: buyer, quantity: "2")

      expect(page).to have_content("数量 2 ＝ 注文数 2 一致")
    end
  end
end
