require "rails_helper"

RSpec.describe "トレード履歴の詳細リンク", type: :system do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let!(:trade) { create(:trade, user:, event:, status: :completed, completed_at: 1.day.ago) }

  before { sign_in(user) }

  it "「詳細を表示」からトレード詳細に移動する" do
    visit histories_path
    expect(page).to have_css("#trades")

    click_link "詳細を表示"

    expect(page).to have_current_path(trade_path(event.id))
    expect(page).to have_text(event.title)
  end

  it "一覧に出す枚数・ほしい枚数・差額の列を出さない" do
    create(:trade_card_offer, trade:, quantity: 3)
    create(:trade_card_want, trade:, quantity: 2)

    visit histories_path

    within("table") do
      expect(page).to have_text("イベント名")
      expect(page).not_to have_text("出す枚数")
      expect(page).not_to have_text("ほしい枚数")
      expect(page).not_to have_text("差額")
    end
  end

  context "イベントが論理削除されているとき" do
    let!(:discarded_event) { create(:event, discarded_at: 1.day.ago) }
    let!(:discarded_trade) do
      create(:trade, user:, event: discarded_event, status: :completed, completed_at: 2.days.ago)
    end

    it "その行には詳細リンクを出さない" do
      visit histories_path

      expect(page).to have_text("（イベント情報不可）")
      # 生きているイベントの行の分だけリンクが出る
      expect(page).to have_link("詳細を表示", count: 1)
    end
  end
end
