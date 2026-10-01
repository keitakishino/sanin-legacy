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

    click_button "編集", match: :first

    form_id = "trade_card_offer_#{card_offer.id}_edit_form"
    expect(page).to have_css("tr[id='#{form_id}']", visible: :visible)

    fill_in "カード名", with: "Updated"
    click_button "更新"

    expect(page).to have_css("tr[id='#{form_id}']", visible: :hidden)
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

    form_id = "trade_card_offer_#{card_offer.id}_edit_form"
    expect(page).to have_css("tr[id='#{form_id}']", visible: :visible)

    click_button "キャンセル"

    expect(page).to have_css("tr[id='#{form_id}']", visible: :hidden)
    form_row_display = evaluate_script(
      "window.getComputedStyle(document.getElementById('#{form_id}')).display"
    )
    expect(form_row_display).to eq("none")
  end

  it "TradeCardWantの『更新』でフォーム行がdisplay:noneになること" do
    card_want = create(:trade_card_want, trade: trade, expansion: expansion)
    visit trade_path(event)

    all_buttons = all("button", text: "編集")
    all_buttons[1].click if all_buttons.length > 1

    form_id = "trade_card_want_#{card_want.id}_edit_form"
    expect(page).to have_css("tr[id='#{form_id}']", visible: :visible)

    fill_in "カード名", with: "Updated Want"
    click_button "更新"

    expect(page).to have_css("tr[id='#{form_id}']", visible: :hidden)
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

    form_id = "trade_card_offer_#{card_offer.id}_edit_form"
    expect(page).to have_css("tr[id='#{form_id}']", visible: :visible)

    find('[data-expansion-select-target="input"]').fill_in with: "VO"
    expect(page).to have_css("[data-expansion-code='VOW']", visible: :all)

    form_row_display = evaluate_script(
      "window.getComputedStyle(document.getElementById('#{form_id}')).display"
    )
    expect(form_row_display).not_to eq("none")
  end

  it "問題2: 編集→更新→編集→更新（2回連続）で、2回目の更新後もフォーム行が閉じること" do
    card_offer = create(:trade_card_offer, trade: trade, expansion: expansion, card_name: "Original")
    visit trade_path(event)

    form_id = "trade_card_offer_#{card_offer.id}_edit_form"

    click_button "編集", match: :first
    expect(page).to have_css("tr[id='#{form_id}']", visible: :visible)

    fill_in "カード名", with: "Updated1"
    click_button "更新"

    expect(page).to have_css("tr[id='#{form_id}']", visible: :hidden)
    form_row_display = evaluate_script(
      "window.getComputedStyle(document.getElementById('#{form_id}')).display"
    )
    expect(form_row_display).to eq("none")

    click_button "編集", match: :first
    expect(page).to have_css("tr[id='#{form_id}']", visible: :visible)

    fill_in "カード名", with: "Updated2"
    click_button "更新"

    expect(page).to have_css("tr[id='#{form_id}']", visible: :hidden)
    form_row_display = evaluate_script(
      "window.getComputedStyle(document.getElementById('#{form_id}')).display"
    )
    expect(form_row_display).to eq("none")
    expect(page).to have_content("Updated2")
  end

  it "問題1: キャンセル→再度編集で、DBの値が正しく表示されること（空にならないこと）" do
    card_offer = create(:trade_card_offer,
                       trade: trade,
                       expansion: expansion,
                       card_name: "OriginalCard",
                       quantity: 3,
                       language: :ja,
                       condition: :nm)
    visit trade_path(event)

    click_button "編集", match: :first

    form_id = "trade_card_offer_#{card_offer.id}_edit_form"
    expect(page).to have_css("tr[id='#{form_id}']", visible: :visible)

    card_name_before = evaluate_script(
      "document.querySelector('input[name=\"trade_card_offer[card_name]\"]').value"
    )
    expect(card_name_before).to eq("OriginalCard")

    click_button "キャンセル"

    expect(page).to have_css("tr[id='#{form_id}']", visible: :hidden)
    form_row_display = evaluate_script(
      "window.getComputedStyle(document.getElementById('#{form_id}')).display"
    )
    expect(form_row_display).to eq("none")

    click_button "編集", match: :first
    expect(page).to have_css("tr[id='#{form_id}']", visible: :visible)

    card_name_after = evaluate_script(
      "document.querySelector('input[name=\"trade_card_offer[card_name]\"]').value"
    )
    expect(card_name_after).to eq("OriginalCard")

    quantity = evaluate_script(
      "document.querySelector('input[name=\"trade_card_offer[quantity]\"]').value"
    )
    expect(quantity).to eq("3")

    language = evaluate_script(
      "document.querySelector('select[name=\"trade_card_offer[language]\"]').value"
    )
    expect(language).to eq("ja")
  end

  it "シナリオC（回帰確認）: 1回目の編集→更新でフォーム行が閉じること" do
    card_offer = create(:trade_card_offer, trade: trade, expansion: expansion)
    visit trade_path(event)

    click_button "編集", match: :first

    form_id = "trade_card_offer_#{card_offer.id}_edit_form"
    expect(page).to have_css("tr[id='#{form_id}']", visible: :visible)

    fill_in "カード名", with: "RegressionTest"
    click_button "更新"

    expect(page).to have_css("tr[id='#{form_id}']", visible: :hidden)
    form_row_display = evaluate_script(
      "window.getComputedStyle(document.getElementById('#{form_id}')).display"
    )
    expect(form_row_display).to eq("none")
  end

  it "シナリオC（回帰確認）: バリデーションエラー時はフォームが開いたままであること" do
    card_offer = create(:trade_card_offer, trade: trade, expansion: expansion)
    visit trade_path(event)

    click_button "編集", match: :first

    form_id = "trade_card_offer_#{card_offer.id}_edit_form"
    expect(page).to have_css("tr[id='#{form_id}']", visible: :visible)

    fill_in "カード名", with: ""
    click_button "更新"

    expect(page).to have_content("を入力してください")
    form_row_display = evaluate_script(
      "window.getComputedStyle(document.getElementById('#{form_id}')).display"
    )
    expect(form_row_display).to eq("table-row")
  end

  it "受け入れ条件テスト: 新規追加直後に編集→キャンセルでフォームが閉じること（acceptance criterion #2）" do
    visit trade_path(event)

    click_button "カード明細を追加", match: :first

    within("#new_trade_card_offer") do
      fill_in "trade_card_offer[card_name]", with: "Newly Added Card"
      fill_in "trade_card_offer[quantity]", with: "2"
      click_button "追加", match: :first
    end

    expect(page).to have_content("Newly Added Card")

    click_button "編集", match: :first

    form_input = evaluate_script(
      "document.querySelector('input[name=\"trade_card_offer[card_name]\"]').value"
    )
    expect(form_input).to eq("Newly Added Card")

    click_button "キャンセル"

    form_row_display = evaluate_script(
      "window.getComputedStyle(document.querySelector('#trade_card_offers tbody tr:last-child')).display"
    )
    expect(form_row_display).to eq("none")
  end

  it "受け入れ条件テスト: 新規追加直後に編集→キャンセルでWantもフォームが閉じること（acceptance criterion #2）" do
    visit trade_path(event)

    all_add_buttons = all("button", text: "カード明細を追加")
    all_add_buttons.last.click if all_add_buttons.present?

    within("#new_trade_card_want") do
      fill_in "trade_card_want[card_name]", with: "Newly Wanted Card"
      fill_in "trade_card_want[quantity]", with: "1"
      click_button "追加", match: :first
    end

    expect(page).to have_content("Newly Wanted Card")

    within("#trade_card_wants tbody") do
      all_edit_buttons = all("button", text: "編集")
      all_edit_buttons.last.click if all_edit_buttons.present?
    end

    form_input = evaluate_script(
      "document.querySelector('input[name=\"trade_card_want[card_name]\"]').value"
    )
    expect(form_input).to eq("Newly Wanted Card")

    click_button "キャンセル"

    form_row_display = evaluate_script(
      "window.getComputedStyle(document.querySelector('#trade_card_wants tbody tr:last-child')).display"
    )
    expect(form_row_display).to eq("none")
  end
end
