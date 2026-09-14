# NOTE: このテストはSelenium/ChromeDriver環境が整備されるまでCI実行対象から除外されています。
# 開発環境で `rspec spec/system/trade_edit_form_close_spec.rb` で手動実行可能。
# Issue #258: トレード編集フォームの『更新』を押した際にフォーム行が閉じない不具合

require "rails_helper"

RSpec.describe "Trade Edit Form Close", type: :system do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:trade) { create(:trade, event: event, user: user) }
  let(:expansion1) { create(:expansion, scryfall_set_code: "VOW", name: "Innistrad: Midnight Hunt", name_ja: "イニストラード：真夜中の狩り") }

  before do
    expansion1
    sign_in user
  end

  it "TradeCardOffer編集フォーム: 『更新』ボタンでフォーム行がdisplay:noneになること" do
    card_offer = create(:trade_card_offer, trade: trade, expansion: expansion1, card_name: "Original Name")
    visit trade_path(event)

    # 編集ボタンをクリック
    within("tr[id='trade_card_offer_#{card_offer.id}']") { click_button "編集" }

    # 編集フォーム行が表示される
    form_row = find("tr[id='trade_card_offer_#{card_offer.id}_edit_form']")
    expect(form_row).to be_visible
    page.save_screenshot("/tmp/claude-1000/-home-pepo2-sanin-legacy/dc51b9ea-1a94-4849-97e7-7ec8972a2b31/scratchpad/01-form-opened.png")

    # フォーム内で値を変更して更新
    within("tr[id='trade_card_offer_#{card_offer.id}_edit_form']") do
      fill_in "カード名", with: "Updated Name"
      click_button "更新"
    end

    sleep 1

    # スクリーンショット: 更新後
    page.save_screenshot("/tmp/claude-1000/-home-pepo2-sanin-legacy/dc51b9ea-1a94-4849-97e7-7ec8972a2b31/scratchpad/02-after-update.png")

    # 編集フォーム行がdisplay:noneになっていることを確認
    computed_style = evaluate_script(
      "window.getComputedStyle(document.getElementById('trade_card_offer_#{card_offer.id}_edit_form')).display"
    )
    expect(computed_style).to eq("none"),
      "編集フォーム行がdisplay:noneになっていません。実際の値: #{computed_style}"

    # 更新されたデータが画面に反映されている
    expect(page).to have_content("Updated Name")
  end

  it "TradeCardOffer編集フォーム: 『キャンセル』ボタンでフォーム行がdisplay:noneになること" do
    card_offer = create(:trade_card_offer, trade: trade, expansion: expansion1)
    visit trade_path(event)

    # 編集ボタンをクリック
    within("tr[id='trade_card_offer_#{card_offer.id}']") { click_button "編集" }

    # フォームが表示されている
    form_row = find("tr[id='trade_card_offer_#{card_offer.id}_edit_form']")
    expect(form_row).to be_visible

    # キャンセルボタンをクリック
    within("tr[id='trade_card_offer_#{card_offer.id}_edit_form']") do
      click_button "キャンセル"
    end

    sleep 0.5

    page.save_screenshot("/tmp/claude-1000/-home-pepo2-sanin-legacy/dc51b9ea-1a94-4849-97e7-7ec8972a2b31/scratchpad/03-after-cancel.png")

    # フォーム行がdisplay:noneになっている
    computed_style = evaluate_script(
      "window.getComputedStyle(document.getElementById('trade_card_offer_#{card_offer.id}_edit_form')).display"
    )
    expect(computed_style).to eq("none"),
      "『キャンセル』後もフォーム行がdisplay:noneになっていません"
  end

  it "TradeCardWant編集フォーム: 『更新』ボタンでフォーム行がdisplay:noneになること" do
    card_want = create(:trade_card_want, trade: trade, expansion: expansion1, card_name: "Want Card")
    visit trade_path(event)

    # ウォントリスト行を見つけて編集
    within("tr[id='trade_card_want_#{card_want.id}']") { click_button "編集" }

    # フォームが表示される
    form_row = find("tr[id='trade_card_want_#{card_want.id}_edit_form']")
    expect(form_row).to be_visible

    page.save_screenshot("/tmp/claude-1000/-home-pepo2-sanin-legacy/dc51b9ea-1a94-4849-97e7-7ec8972a2b31/scratchpad/04-want-form-opened.png")

    # 値を変更して更新
    within("tr[id='trade_card_want_#{card_want.id}_edit_form']") do
      fill_in "カード名", with: "Updated Want"
      click_button "更新"
    end

    sleep 1

    page.save_screenshot("/tmp/claude-1000/-home-pepo2-sanin-legacy/dc51b9ea-1a94-4849-97e7-7ec8972a2b31/scratchpad/05-want-after-update.png")

    # フォーム行がdisplay:noneになっている
    computed_style = evaluate_script(
      "window.getComputedStyle(document.getElementById('trade_card_want_#{card_want.id}_edit_form')).display"
    )
    expect(computed_style).to eq("none"),
      "TradeCardWantフォーム行がdisplay:noneになっていません"

    expect(page).to have_content("Updated Want")
  end

  it "querySelector検証: form_reset_controllerがquerySelector('turbo-frame')で正しいフレームを取得すること" do
    card_offer = create(:trade_card_offer, trade: trade, expansion: expansion1)
    visit trade_path(event)

    # 編集フォームを開く
    within("tr[id='trade_card_offer_#{card_offer.id}']") { click_button "編集" }

    sleep 0.3

    page.save_screenshot("/tmp/claude-1000/-home-pepo2-sanin-legacy/dc51b9ea-1a94-4849-97e7-7ec8972a2b31/scratchpad/06-queryselector-test.png")

    # form_reset_controller内のquerySelector('turbo-frame')の結果を検証
    frame_info = evaluate_script(<<-JS
      (function() {
        const tr = document.querySelector('[data-controller="form-reset"]');
        if (!tr) return { error: 'form-reset not found' };

        const frameElement = tr.querySelector('turbo-frame');
        if (!frameElement) return { error: 'turbo-frame not found' };

        return {
          frame_id: frameElement.id,
          is_edit_form_frame: frameElement.id.includes('edit_form_frame'),
          parent_tr_id: tr.id
        };
      })()
    JS
    )

    puts "\n=== querySelector('turbo-frame') Verification Results ==="
    puts "Frame ID: #{frame_info['frame_id']}"
    puts "Is edit_form_frame: #{frame_info['is_edit_form_frame']}"
    puts "Parent TR ID: #{frame_info['parent_tr_id']}"

    expect(frame_info['frame_id']).to include('edit_form_frame'),
      "querySelector('turbo-frame')が期待するフレームを返していません: #{frame_info['frame_id']}"
    expect(frame_info['is_edit_form_frame']).to eq(true),
      "querySelector結果がedit_form_frameではありません"
  end

  it "セット候補表示時に編集フォーム行が誤って閉じないこと（回帰テスト）" do
    expansion2 = create(:expansion, scryfall_set_code: "VOC", name: "Innistrad: Crimson Vow", name_ja: "イニストラード：真紅の契約")
    card_offer = create(:trade_card_offer, trade: trade, expansion: expansion1)
    visit trade_path(event)

    # 編集フォームを開く
    within("tr[id='trade_card_offer_#{card_offer.id}']") { click_button "編集" }

    # セット入力欄に文字入力
    expansion_input = find('[data-expansion-select-target="input"]')
    expansion_input.fill_in with: "VO"

    sleep 0.3

    page.save_screenshot("/tmp/claude-1000/-home-pepo2-sanin-legacy/dc51b9ea-1a94-4849-97e7-7ec8972a2b31/scratchpad/07-expansion-input.png")

    # フォーム行がdisplay:noneになっていないことを確認
    computed_style = evaluate_script(
      "window.getComputedStyle(document.getElementById('trade_card_offer_#{card_offer.id}_edit_form')).display"
    )
    expect(computed_style).not_to eq("none"),
      "セット入力時に編集フォーム行が誤ってdisplay:noneになっています（回帰）"
  end
end
