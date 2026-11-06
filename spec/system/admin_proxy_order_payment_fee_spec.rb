require "rails_helper"

RSpec.describe "Admin Proxy Order Payment Fee", type: :system do
  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }

  before do
    sign_in(admin)
    resize_window_to(1280, 900)
  end

  describe "ordered status" do
    it "[C1] can input and save payment fee" do
      proxy_order = create(:proxy_order, event:, status: :ordered, tax_usd: 0, customs_usd: 0, shipping_usd: 0, usd_jpy_rate: 150)
      visit admin_event_proxy_order_path(event)

      within "#proxy_order_fees_form" do
        fill_in "proxy_order[payment_fee_usd]", with: "3.50"
        click_button "保存"
      end

      expect(page).to have_content("税・送料・決済手数料・レートを更新しました")
      expect(page).to have_content("$3.50")
      proxy_order.reload
      expect(proxy_order.payment_fee_usd).to eq(3.5)
    end
  end

  describe "arrived status" do
    it "[C2] can input and save payment fee" do
      proxy_order = create(:proxy_order, event:, status: :arrived, tax_usd: 0, customs_usd: 0, shipping_usd: 0, usd_jpy_rate: 150)
      visit admin_event_proxy_order_path(event)

      within "#proxy_order_fees_form" do
        fill_in "proxy_order[payment_fee_usd]", with: "2.00"
        click_button "保存"
      end

      expect(page).to have_content("税・送料・決済手数料・レートを更新しました")
      proxy_order.reload
      expect(proxy_order.payment_fee_usd).to eq(2.0)
    end
  end

  describe "completed status" do
    it "[C3] payment fee field is disabled and save button is not shown" do
      proxy_order = create(:proxy_order, event:, status: :completed, tax_usd: 0, customs_usd: 0, shipping_usd: 0, usd_jpy_rate: 150)
      visit admin_event_proxy_order_path(event)

      within "#proxy_order_fees_form" do
        expect(find("input[name='proxy_order[payment_fee_usd]']")).to be_disabled
        expect(page).not_to have_button("保存")
      end
    end
  end
end
