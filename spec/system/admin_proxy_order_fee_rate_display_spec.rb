require "rails_helper"

RSpec.describe "Admin proxy order fee rate display", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }

  before do
    sign_in admin
    resize_window_to(1280, 900)
  end

  describe "[C1] fee rate inputs" do
    it "[C1] displays payment fee rate, customs rate, and consumption tax rate input fields with percentage labels, and saves values" do
      proxy_order = create(:proxy_order, event: event, status: :ordered, shipping_usd: 0, usd_jpy_rate: 150)
      visit admin_event_proxy_order_path(event, proxy_order)

      # Verify input fields exist with correct labels
      within "#proxy_order_fees_form" do
        expect(page).to have_field("proxy_order[payment_fee_rate]")
        expect(page).to have_field("proxy_order[customs_rate]")
        expect(page).to have_field("proxy_order[consumption_tax_rate]")
        expect(page).to have_text("決済手数料率（%）")
        expect(page).to have_text("関税率（%）")
        expect(page).to have_text("消費税率（%）")

        # Verify old USD input fields don't exist
        expect(page).not_to have_field("proxy_order[tax_usd]")
        expect(page).not_to have_field("proxy_order[customs_usd]")
        expect(page).not_to have_field("proxy_order[payment_fee_usd]")
      end

      # Fill in and save values
      within "#proxy_order_fees_form" do
        fill_in "proxy_order[payment_fee_rate]", with: "3.5"
        fill_in "proxy_order[customs_rate]", with: "5"
        fill_in "proxy_order[consumption_tax_rate]", with: "8"
        click_button "保存"
      end

      # Wait for success message and verify navigation
      expect(page).to have_text("税・送料・決済手数料・レートを更新しました")
      visit admin_event_proxy_order_path(event, proxy_order)

      # Verify values are saved
      within "#proxy_order_fees_form" do
        expect(find_field("proxy_order[payment_fee_rate]").value.to_f).to eq(3.5)
        expect(find_field("proxy_order[customs_rate]").value.to_f).to eq(5.0)
        expect(find_field("proxy_order[consumption_tax_rate]").value.to_f).to eq(8.0)
      end
    end
  end

  describe "[C2] fee total tile removed" do
    it "[C2] does not display the total fees tile" do
      proxy_order = create(:proxy_order, event: event, status: :ordered)
      create(:proxy_order_participant, proxy_order:)
      visit admin_event_proxy_order_path(event, proxy_order)

      within "#proxy_order_fee_tiles" do
        expect(page).not_to have_text("手数料合計")
      end
    end
  end

  describe "[C3] fee per person renamed to shipping per person" do
    it "[C3] displays shipping per person label instead of fee per person" do
      proxy_order = create(:proxy_order, event: event, status: :ordered)
      create(:proxy_order_participant, proxy_order:)
      visit admin_event_proxy_order_path(event, proxy_order)

      within "#proxy_order_fee_tiles" do
        expect(page).to have_text("一人あたり送料")
        expect(page).not_to have_text("一人あたり手数料")
      end
    end
  end

  describe "[C4] total payment USD tile" do
    it "[C4] displays total payment in USD and JPY tiles, with USD on the left" do
      proxy_order = create(:proxy_order, event: event, status: :ordered,
                          shipping_usd: 2, payment_fee_rate: 4.1, customs_rate: 4,
                          consumption_tax_rate: 10, usd_jpy_rate: 150)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 1)
      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      visit admin_event_proxy_order_path(event, proxy_order)

      # Verify both tiles exist and have correct content
      within "#proxy_order_fee_tiles" do
        expect(page).to have_text("支払合計（$）")
        expect(page).to have_text("支払合計（円）")
        expect(page).to have_selector("#proxy_order_payment_total_usd", text: "$14.22")
        expect(page).to have_selector("#proxy_order_payment_total_jpy", text: "¥2,200")
      end

      # Verify USD tile is to the left of JPY tile
      usd_tile_left = evaluate_script("document.getElementById('proxy_order_payment_total_usd').getBoundingClientRect().left")
      jpy_tile_left = evaluate_script("document.getElementById('proxy_order_payment_total_jpy').getBoundingClientRect().left")
      expect(usd_tile_left).to be < jpy_tile_left
    end
  end

  describe "[C5] user payment breakdown with shipping and charges" do
    it "[C5] displays payment breakdown as goods + shipping + charges = total" do
      proxy_order = create(:proxy_order, event: event, status: :ordered,
                          shipping_usd: 2, payment_fee_rate: 4.1, customs_rate: 4,
                          consumption_tax_rate: 10, usd_jpy_rate: 150)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd: 10, quantity: 1)
      participant = create(:proxy_order_participant, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      visit admin_event_proxy_order_path(event, proxy_order)

      # Verify breakdown content
      within "#summary_proxy_order_participant_#{participant.id}" do
        expect(page).to have_text("商品 $10.00 ＋ 送料 $2.00 ＋ 手数料等 $2.22 ＝ $14.22")
        expect(page).to have_selector("[data-role='shipping']", text: "$2.00")
        expect(page).to have_selector("[data-role='charges']", text: "$2.22")
      end
    end
  end

  describe "[C6] shipping and rate inputs remain editable" do
    it "[C6] allows editing and saving shipping USD and USD JPY rate" do
      proxy_order = create(:proxy_order, event: event, status: :ordered,
                          shipping_usd: 0, usd_jpy_rate: 150)
      visit admin_event_proxy_order_path(event, proxy_order)

      within "#proxy_order_fees_form" do
        fill_in "proxy_order[shipping_usd]", with: "12.5"
        fill_in "proxy_order[usd_jpy_rate]", with: "155"
        click_button "保存"
      end

      expect(page).to have_text("税・送料・決済手数料・レートを更新しました")
      visit admin_event_proxy_order_path(event, proxy_order)

      within "#proxy_order_fees_form" do
        expect(find_field("proxy_order[shipping_usd]").value.to_f).to eq(12.5)
        expect(find_field("proxy_order[usd_jpy_rate]").value.to_f).to eq(155.0)
      end
    end
  end

  describe "[C7] completed order inputs disabled" do
    it "[C7] disables all fee and rate input fields in completed state" do
      proxy_order = create(:proxy_order, event: event, status: :completed,
                          payment_fee_rate: 4.1, customs_rate: 4, consumption_tax_rate: 10,
                          shipping_usd: 2, usd_jpy_rate: 150)
      visit admin_event_proxy_order_path(event, proxy_order)

      within "#proxy_order_fees_form" do
        expect(page).to have_field("proxy_order[payment_fee_rate]", disabled: true)
        expect(page).to have_field("proxy_order[customs_rate]", disabled: true)
        expect(page).to have_field("proxy_order[consumption_tax_rate]", disabled: true)
        expect(page).to have_field("proxy_order[shipping_usd]", disabled: true)
        expect(page).to have_field("proxy_order[usd_jpy_rate]", disabled: true)
        expect(page).not_to have_button("保存")
      end
    end
  end
end
