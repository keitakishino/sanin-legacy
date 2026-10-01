require "rails_helper"

RSpec.describe "Expansion Select Combobox", type: :system do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:trade) { create(:trade, event: event, user: user) }
  let(:expansion1) { create(:expansion, scryfall_set_code: "VOW", name: "Innistrad: Midnight Hunt", name_ja: "イニストラード：真夜中の狩り") }
  let(:expansion2) { create(:expansion, scryfall_set_code: "VOC", name: "Innistrad: Crimson Vow", name_ja: "イニストラード：真紅の契約") }

  before do
    expansion1
    expansion2
    sign_in user
  end

  describe "セット選択コンボボックスの動作" do
    it "トレード掲示画面でセット検索入力欄にテキストを入力すると候補がTurbo Frameで表示される" do
      visit trade_path(event, anchor: "new-trade-card-offer-form")
      click_button "カード明細を追加", match: :first

      within("#new_trade_card_offer") do
        expansion_input = find('[data-expansion-select-target="input"]')
        expansion_input.fill_in with: "VO"

        expect(page).to have_css('[data-expansion-code="VOW"]', visible: :all)
        expect(page).to have_css('[data-expansion-code="VOC"]', visible: :all)
      end
    end

    it "検索結果から候補をクリックすると hidden field expansion_id に値が設定される" do
      visit trade_path(event, anchor: "new-trade-card-offer-form")
      click_button "カード明細を追加", match: :first

      within("#new_trade_card_offer") do
        expansion_input = find('[data-expansion-select-target="input"]')
        expansion_input.fill_in with: "VOW"

        find('[data-expansion-code="VOW"]', visible: :all).click

        hidden_field = find('[data-expansion-select-target="select"]', visible: false)
        expect(hidden_field.value).to eq(expansion1.id.to_s)

        expect(expansion_input.value).to eq("VOW")
      end
    end

    it "検索結果から候補をクリック後、フォーム送信時に expansion_id がパラメータに含まれる" do
      visit trade_path(event, anchor: "new-trade-card-offer-form")
      click_button "カード明細を追加", match: :first

      within("#new_trade_card_offer") do
        expansion_input = find('[data-expansion-select-target="input"]')
        expansion_input.fill_in with: "VOW"
        find('[data-expansion-code="VOW"]', visible: :all).click

        fill_in "カード名", with: "Black Lotus"
        fill_in "数量", with: "1"
        select "日本語", from: "言語"
        select "NM（ニアミント）", from: "状態"
        select "foil", from: "フォイル"
        select "通常", from: "フレーム"
        choose "trade_card_offer_pw_mark_false"

        click_button "追加"
      end

      expect(page).to have_current_path(trade_path(event))
      expect(page).to have_content("Black Lotus")
      expect(page).to have_content("VOW")
    end

    it "検索入力欄を空にするとドロップダウンが非表示になる" do
      visit trade_path(event, anchor: "new-trade-card-offer-form")
      click_button "カード明細を追加", match: :first

      within("#new_trade_card_offer") do
        expansion_input = find('[data-expansion-select-target="input"]')
        expansion_input.fill_in with: "VO"

        find('[data-expansion-code="VOW"]', visible: :all)

        expansion_input.fill_in with: "", fill_options: { clear: :backspace }

        expect(page).to have_css("#new_trade_card_offer turbo-frame#expansion_suggestions", visible: :hidden)
      end
    end
  end
end
