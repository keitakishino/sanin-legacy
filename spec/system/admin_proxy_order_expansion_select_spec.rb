require "rails_helper"

RSpec.describe "Admin Proxy Order Expansion Select", type: :system do
  include ActionView::RecordIdentifier

  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
  let!(:expansion_vow) { create(:expansion, scryfall_set_code: "VOW", name: "Innistrad: Crimson Vow") }
  let!(:expansion_mid) { create(:expansion, scryfall_set_code: "MID", name: "Innistrad: Midnight Hunt") }
  let!(:buyer) { create(:user, username: "buyer") }

  before do
    sign_in(admin)
    resize_window_to(1280, 900)
    visit admin_event_proxy_order_path(event)
end

  describe "追加フォームでセットコード欄にセット名の一部を打つと候補が表示される" do
    it "セットコード欄に VO と打つと候補 VOW が表示される" do
      within "#new_proxy_order_item_form" do
        find("#new_proxy_order_item_expansion_input").set("VO")
      end
      expect(page).to have_css("#new_proxy_order_item_expansion_suggestions [data-expansion-code='VOW']")
    end
  end

  describe "追加フォームで候補を1つ押すと、セットコード欄にセットコードが入り、カード明細が作られる" do
    it "候補 VOW を押して「カード明細を追加」を押すと、作られた明細の expansion が VOW になる" do
      within "#new_proxy_order_item_form" do
        find("#new_proxy_order_item_expansion_input").set("VO")
        expect(page).to have_css("#new_proxy_order_item_expansion_suggestions [data-expansion-code='VOW']")
        find("[data-expansion-code='VOW']").click
        expect(find("#new_proxy_order_item_expansion_input").value).to eq("VOW")
        expect(find("input[type='hidden'][name='proxy_order_item[expansion_id]']", visible: false).value).to eq(expansion_vow.id.to_s)
        fill_in "proxy_order_item[card_name]", with: "Black Lotus"
        click_button "カード明細を追加"
      end
      expect(page).to have_content("カードを追加しました")
      expect(ProxyOrderItem.order(:id).last.expansion).to eq(expansion_vow)
    end
  end
end
