require "rails_helper"

RSpec.describe "User Proxy Order Fee Rate Display", type: :system do
  let(:user) { create(:user, email: "test@example.com", password: "password123") }
  let(:other_buyer_user) { create(:user, username: "other_buyer", email: "other@example.com", password: "password456") }
  let(:event) { create(:event, :proxy_order, title: "Fee Rate Display Test") }
  let(:proxy_order) do
    create(:proxy_order, event:, status: :ordered, shipping_usd: 2, payment_fee_rate: 4.1,
                         customs_rate: 4, consumption_tax_rate: 10, usd_jpy_rate: nil)
  end
  let(:me) { create(:proxy_order_participant, proxy_order:, user:) }
  let(:other) { create(:proxy_order_participant, proxy_order:, user: other_buyer_user) }
  let(:item) { create(:proxy_order_item, proxy_order:, card_name: "Test Card") }

  before do
    sign_in(user)
    resize_window_to(1280, 900)

    # Setup: 2 participants, each with $10 card, quantity 2 (total $20)
    # fee_payer_count = 2, shipping_usd = 2, so each pays $1 for shipping
    create(:proxy_order_price_line, proxy_order_item: item, quantity: 2, unit_price_usd: 10.00)
    create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: me, quantity: 1, lost_quantity: 0)
    create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: other, quantity: 1, lost_quantity: 0)

    visit proxy_order_path(event.id)
  end

  describe "[C1] タイルが「一人あたり送料」という名称で表示される" do
    it "[C1] displays tile with 一人あたり送料 label instead of 手数料" do
      within "#proxy_order_my_payment" do
        expect(page).to have_text("一人あたり送料（$2.00 ÷ 2人）")
        expect(page).not_to have_text("手数料（")
      end
    end

    it "[C1] displays shipping per person value correctly" do
      shipping_element = find("[data-role='shipping-per-person']")
      expect(shipping_element.text).to eq("$1.00")
    end
  end

  describe "[C2] 支払いの内訳が「商品＋送料＋手数料等＝合計」という表示になる" do
    it "[C2] displays breakdown with goods, shipping, charges, and total" do
      within "#proxy_order_my_breakdown" do
        expect(page).to have_text("商品 $10.00 ＋ 送料 $1.00 ＋ 手数料等")
      end
    end

    it "[C2] displays breakdown components with correct data roles" do
      within "#proxy_order_my_breakdown" do
        goods_element = find("[data-role='breakdown-goods']")
        shipping_element = find("[data-role='breakdown-shipping']")
        charges_element = find("[data-role='breakdown-charges']")
        payment_element = find("[data-role='payment-usd']")

        expect(goods_element.text).to eq("$10.00")
        expect(shipping_element.text).to eq("$1.00")
        # charges_element and payment_element values depend on calculator
        expect(charges_element.text).to match(/^\$\d+\.\d{2}$/)
        expect(payment_element.text).to match(/^\$\d+\.\d{2}$/)
      end
    end
  end

  describe "[C3] 円ドルレート未入力のとき、支払金額は未確定と表示される" do
    it "[C3] displays pending payment when usd_jpy_rate is nil" do
      payment_jpy_element = find("[data-role='payment-jpy']")
      expect(payment_jpy_element.text).to include(I18n.t("common.pending"))
    end
  end

  describe "[C4] 注文が到着前（ordered）のとき、支払金額に暫定のバッジが表示される" do
    it "[C4] displays provisional badge when order is ordered status" do
      within "#proxy_order_my_payment" do
        expect(page).to have_text(I18n.t("proxy_orders.show.provisional"))
      end
    end

    it "[C4] displays yen amount and removes provisional badge when status changes to arrived" do
      proxy_order.update_columns(status: :arrived, usd_jpy_rate: 150)
      visit proxy_order_path(event.id)

      within "#proxy_order_my_payment" do
        expect(page).not_to have_text(I18n.t("proxy_orders.show.provisional"))
      end

      payment_jpy_element = find("[data-role='payment-jpy']")
      expect(payment_jpy_element.text).to match(/¥/)
      expect(payment_jpy_element.text).not_to include(I18n.t("common.pending"))
    end
  end
end
