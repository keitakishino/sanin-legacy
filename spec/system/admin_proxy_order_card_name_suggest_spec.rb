require "rails_helper"

RSpec.describe "Admin Proxy Order Card Name Suggest", type: :system do
  include ActionView::RecordIdentifier

  before do
    admin = create(:user, role: :admin)
    create(:card_name, name: "Lightning Bolt")
    create(:card_name, name: "Lightning Helix")
    create(:card_name, name: "Black Lotus")
    expansion_vow = create(:expansion, scryfall_set_code: "VOW", name: "Innistrad: Crimson Vow")
    expansion_mid = create(:expansion, scryfall_set_code: "MID", name: "Innistrad: Midnight Hunt")

    event = create(:event, :proxy_order, created_by: admin)
    proxy_order = event.proxy_order || create(:proxy_order, event: event)
    @item = create(:proxy_order_item, proxy_order: proxy_order, expansion: expansion_mid, card_name: "Old Name")

    sign_in(admin)
    resize_window_to(1280, 900)
    visit admin_event_proxy_order_path(event)

    # 明細の details を開く
    find("##{dom_id(@item)} summary").click
  end

  describe "カード名欄に文字を入れると card_names から候補が出る" do
    it "[C1] 明細のカード名欄に英語で Light と打つと、card_names の候補 Lightning Bolt が出る" do
      find("##{dom_id(@item, :card_name_input)}").set("Light")
      expect(page).to have_css("##{dom_id(@item, :card_name_suggestions)} [data-expansion-code='Lightning Bolt']")
      expect(page).not_to have_css("##{dom_id(@item, :card_name_suggestions)} [data-expansion-code='Black Lotus']")
    end
  end

  describe "候補を選ぶと入力欄に反映されて保存される" do
    it "[C2] 候補 Lightning Bolt を押すと入力欄に入り、自動で保存される" do
      find("##{dom_id(@item, :card_name_input)}").set("Light")
      expect(page).to have_css("##{dom_id(@item, :card_name_suggestions)} [data-expansion-code='Lightning Bolt']")
      find("[data-expansion-code='Lightning Bolt']").click
      expect(page).to have_text("カードを更新しました")
      expect(find("##{dom_id(@item, :card_name_input)}").value).to eq("Lightning Bolt")
      expect(@item.reload.card_name).to eq("Lightning Bolt")
    end
  end

  describe "辞書に無い名前も、そのまま入力して保存できる" do
    it "[C3] 辞書に無い名前を入力して欄を離れると、その名前で保存される" do
      field = find("##{dom_id(@item, :edit_form)} input[name='proxy_order_item[card_name]']")
      field.set("My Custom Proxy")
      field.send_keys(:tab)
      expect(page).to have_text("カードを更新しました")
      expect(@item.reload.card_name).to eq("My Custom Proxy")
    end
  end

  describe "追加フォームでカード名欄で候補を選ぶと入力欄に入り、そのまま明細を追加できる" do
    it "[C6] 追加フォームのカード名欄で候補を選ぶと入力欄に入り、そのまま明細を追加できる" do
      within "#new_proxy_order_item_form" do
        find("#new_proxy_order_item_card_name_input").set("Black")
        expect(page).to have_css("#new_proxy_order_item_card_name_suggestions [data-expansion-code='Black Lotus']")
        find("[data-expansion-code='Black Lotus']").click
        expect(find("#new_proxy_order_item_card_name_input").value).to eq("Black Lotus")
        click_button "カード明細を追加"
      end
      expect(page).to have_content("カードを追加しました")
      expect(ProxyOrderItem.order(:id).last.card_name).to eq("Black Lotus")
    end
  end

  describe "セット欄の動作を壊さない" do
    it "[C7] 明細のセット欄で VO と打つと候補 VOW が出て、選ぶとセットが保存される" do
      find("##{dom_id(@item, :expansion_input)}").set("VO")
      expect(page).to have_css("##{dom_id(@item, :expansion_suggestions)} [data-expansion-code='VOW']")
      find("[data-expansion-code='VOW']", visible: :all).click
      expect(page).to have_text("カードを更新しました")
      expect(@item.reload.expansion.scryfall_set_code).to eq("VOW")
    end
  end
end
