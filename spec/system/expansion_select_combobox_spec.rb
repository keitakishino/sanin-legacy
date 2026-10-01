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

      # セット選択入力欄を見つける
      expansion_input = find('[data-expansion-select-target="input"]')

      # "VO"を入力して検索
      expansion_input.fill_in with: "VO"

      # 候補が表示されるまで待つ（turbo-frameが更新される）
      frame = find('turbo-frame#expansion_suggestions', visible: :all)

      # 候補リストが表示される（display: noneではない）までポーリング
      expect(frame).to have_css('[data-expansion-code="VOW"]', visible: :all)
      expect(frame).to have_css('[data-expansion-code="VOC"]', visible: :all)
    end

    it "検索結果から候補をクリックすると hidden field expansion_id に値が設定される" do
      visit trade_path(event, anchor: "new-trade-card-offer-form")

      # セット選択入力欄を見つける
      expansion_input = find('[data-expansion-select-target="input"]')

      # "VOW"を入力して検索
      expansion_input.fill_in with: "VOW"

      # 候補をクリック
      find('[data-expansion-code="VOW"]', visible: :all).click

      # hidden field expansion_id が expansion1.id に設定されることを確認
      hidden_field = find('[data-expansion-select-target="select"]', visible: false)
      expect(hidden_field.value).to eq(expansion1.id.to_s)

      # 入力欄が"VOW"のまま表示される
      expect(expansion_input.value).to eq("VOW")
    end

    it "検索結果から候補をクリック後、フォーム送信時に expansion_id がパラメータに含まれる" do
      visit trade_path(event, anchor: "new-trade-card-offer-form")

      # セット選択入力欄を見つける
      expansion_input = find('[data-expansion-select-target="input"]')

      # セット検索
      expansion_input.fill_in with: "VOW"
      find('[data-expansion-code="VOW"]', visible: :all).click

      # フォームの他の必須フィールドを埋める
      fill_in "カード名", with: "Black Lotus"
      fill_in "数量", with: "1"
      select "日本語", from: "言語"
      select "NM", from: "状態"
      select "フォイル", from: "フォイル"
      select "通常", from: "フレーム"
      choose "trade_card_offer_pw_mark_false"

      # フォーム送信
      click_button "追加"

      # リダイレクト後にトレード詳細画面が表示される
      expect(current_path).to eq(trade_path(event))

      # 追加されたカード明細が表示される
      expect(page).to have_content("Black Lotus")
      expect(page).to have_content("VOW")
    end

    it "検索入力欄を空にするとドロップダウンが非表示になる" do
      visit trade_path(event, anchor: "new-trade-card-offer-form")

      # セット選択入力欄を見つける
      expansion_input = find('[data-expansion-select-target="input"]')

      # "VO"を入力して検索
      expansion_input.fill_in with: "VO"

      # 候補が表示される
      find('[data-expansion-code="VOW"]', visible: :all)

      # 入力欄を空にする
      expansion_input.fill_in with: ""

      # ドロップダウン（turbo-frame）が非表示になることを確認
      frame = find('turbo-frame#expansion_suggestions', visible: :all)
      expect(frame).to have_css('[style*="display: none"]')
    end
  end
end
