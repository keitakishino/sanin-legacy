require "rails_helper"

RSpec.describe "Proxy Order Rounding", type: :system do
  let(:user) { create(:user, email: "test@example.com", password: "password123") }
  let(:admin) { create(:user, role: :admin, email: "admin@example.com", password: "admin123") }
  let(:event) { create(:event, :proxy_order) }
  let(:proxy_order) { create(:proxy_order, event:, status: :arrived, tax_usd: 0, customs_usd: 0, shipping_usd: 0, usd_jpy_rate: 150) }
  let(:item) { create(:proxy_order_item, proxy_order:) }
  let(:participant) { create(:proxy_order_participant, proxy_order:, user:) }

  before do
    create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 3, quantity: 1, lost_quantity: 0)
    create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1, lost_quantity: 0)
    resize_window_to(1280, 900)
  end

  after do
    Capybara.reset_sessions!
  end

  describe "User proxy order detail" do
    it "[C5] 利用者の詳細画面で $3 × 150 の支払いが ¥500、説明が 100 円単位の切り上げになる" do
      sign_in(user)
      visit proxy_order_path(event.id)

      expect(find("[data-role='payment-jpy']")).to have_text("¥500")
      expect(page).to have_content("支払い金額（100円単位に切り上げ）")
      expect(page).not_to have_content("支払い金額（1,000円単位に四捨五入）")
    end
  end

  describe "Admin proxy order detail" do
    it "[C6] 管理者の明細画面で参加者の支払いが ¥500、注記が 100 円単位の切り上げになる" do
      sign_in(admin)
      visit admin_event_proxy_order_path(event)

      expect(find("[data-role='payment-jpy']")).to have_text("¥500")
      expect(page).to have_content("円換算後に 100 円単位で切り上げます。")
    end
  end
end
