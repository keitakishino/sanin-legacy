# NOTE: このテストはSelenium/ChromeDriver環境が整備されるまでCI実行対象から除外されています。
# 開発環境で `rspec spec/system/trade_edit_form_close_spec.rb` で手動実行可能。
# Issue #258: トレード編集フォームの『更新』を押した際にフォーム行が閉じない不具合

require "rails_helper"

RSpec.describe "Trade Edit Form Close (Issue #258)", type: :system do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:trade) { create(:trade, event: event, user: user) }
  let(:expansion) { create(:expansion, scryfall_set_code: "VOW") }

  before do
    sign_in user
  end

  it "TradeCardOfferの『更新』でフォーム行がdisplay:noneになること" do
    card_offer = create(:trade_card_offer, trade: trade, expansion: expansion, card_name: "Original")
    visit trade_path(event)

    # 編集ボタンをクリック
    click_button "編集", match: :first

    # フォーム行が表示される
    sleep 0.3
    form_id = "trade_card_offer_#{card_offer.id}_edit_form"
    expect(page).to have_css("tr[id='#{form_id}']")

    # フォーム内で値を変更
    fill_in "カード名", with: "Updated"

    # 更新ボタンをクリック
    click_button "更新"
    sleep 1

    # 編集フォーム行がdisplay:noneになっていることを検証
    form_row_display = evaluate_script(
      "window.getComputedStyle(document.getElementById('#{form_id}')).display"
    )
    expect(form_row_display).to eq("none")
    expect(page).to have_content("Updated")
  end

  it "TradeCardOfferの『キャンセル』でフォーム行がdisplay:noneになること" do
    card_offer = create(:trade_card_offer, trade: trade, expansion: expansion)
    visit trade_path(event)

    click_button "編集", match: :first
    sleep 0.3

    form_id = "trade_card_offer_#{card_offer.id}_edit_form"
    click_button "キャンセル"
    sleep 0.5

    form_row_display = evaluate_script(
      "window.getComputedStyle(document.getElementById('#{form_id}')).display"
    )
    expect(form_row_display).to eq("none")
  end

  it "TradeCardWantの『更新』でフォーム行がdisplay:noneになること" do
    card_want = create(:trade_card_want, trade: trade, expansion: expansion)
    visit trade_path(event)

    # ウォントリストの編集ボタン（2番目）
    all_buttons = all("button", text: "編集")
    all_buttons[1].click if all_buttons.length > 1
    sleep 0.3

    form_id = "trade_card_want_#{card_want.id}_edit_form"
    fill_in "カード名", with: "Updated Want"
    click_button "更新"
    sleep 1

    form_row_display = evaluate_script(
      "window.getComputedStyle(document.getElementById('#{form_id}')).display"
    )
    expect(form_row_display).to eq("none")
  end

  it "querySelector検証: form_reset_controllerがquerySelector('turbo-frame')で正しいフレームを取得" do
    card_offer = create(:trade_card_offer, trade: trade, expansion: expansion)
    visit trade_path(event)

    click_button "編集", match: :first
    sleep 0.3

    # form_reset_controller内のquerySelector('turbo-frame')が期待値を返すことを検証
    frame_check = evaluate_script(<<-JS
      (function() {
        const controller_el = document.querySelector('[data-controller="form-reset"]');
        if (!controller_el) return { status: 'ERROR', message: 'form-reset not found' };

        const frame = controller_el.querySelector('turbo-frame');
        if (!frame) return { status: 'ERROR', message: 'turbo-frame not found' };

        return {
          status: 'OK',
          frame_id: frame.id,
          is_edit_form_frame: frame.id.includes('edit_form_frame')
        };
      })()
    JS
    )

    puts "\n--- querySelector('turbo-frame') Verification ---"
    puts "Frame ID: #{frame_check['frame_id']}"
    puts "Is edit_form_frame: #{frame_check['is_edit_form_frame']}"

    expect(frame_check['status']).to eq('OK')
    expect(frame_check['is_edit_form_frame']).to eq(true)
  end

  it "セット入力時に編集フォーム行が誤って閉じないこと（回帰テスト）" do
    create(:expansion, scryfall_set_code: "VOC")
    card_offer = create(:trade_card_offer, trade: trade, expansion: expansion)
    visit trade_path(event)

    click_button "編集", match: :first
    sleep 0.3

    # セット入力欄に入力
    find('[data-expansion-select-target="input"]').fill_in with: "VO"
    sleep 0.3

    # フォーム行がまだ表示されている
    form_id = "trade_card_offer_#{card_offer.id}_edit_form"
    form_row_display = evaluate_script(
      "window.getComputedStyle(document.getElementById('#{form_id}')).display"
    )
    expect(form_row_display).not_to eq("none")
  end
end
