require "rails_helper"

# 代理通販の登録画面で、一覧の下のほうのカードを更新しても画面が先頭に戻らないこと。
#
# 明細の更新は turbo_stream で該当箇所だけ差し替わる。ここがフルページ遷移に
# 落ちると Turbo がスクロールを先頭に戻すため、「下のほうを編集すると画面が
# 上に飛ぶ」という形で現れる。
RSpec.describe "代理通販 登録画面のスクロール位置", type: :system do
  include ActionView::RecordIdentifier

  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
  let!(:proxy_order) { create(:proxy_order, event:) }

  before do
    sign_in(admin)
    resize_window_to(1280, 700)
  end

  it "下のほうのカード名を更新してもスクロール位置が先頭に戻らない" do
    items = 12.times.map { |i| create(:proxy_order_item, proxy_order:, card_name: "Card #{format('%02d', i)}") }
    last_item = items.last

    visit admin_event_proxy_order_path(event)
    expect(page).to have_css("##{dom_id(last_item)}")

    # 最後のカードを開く（一覧は details/summary で畳まれている）
    find("##{dom_id(last_item)} summary").click
    expect(page).to have_css("##{dom_id(last_item, :edit_form)}", visible: :visible)

    # 最後のカードまでスクロール
    page.execute_script("document.getElementById('#{dom_id(last_item)}').scrollIntoView({block: 'center'})")
    before_y = page.evaluate_script("window.scrollY")
    expect(before_y).to be > 0

    field = find("##{dom_id(last_item, :edit_form)} input[name='proxy_order_item[card_name]']")
    field.set("Card 11 updated")
    field.send_keys(:tab)

    expect(page).to have_content("カードを更新しました")

    after_y = page.evaluate_script("window.scrollY")
    expect(after_y).to be_within(150).of(before_y),
      "更新前 scrollY=#{before_y} / 更新後 scrollY=#{after_y}（先頭に戻ってしまっている）"
  end
end
