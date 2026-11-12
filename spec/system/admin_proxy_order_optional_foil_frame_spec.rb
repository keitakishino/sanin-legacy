require "rails_helper"

RSpec.describe "Admin Proxy Order Optional Foil Frame", type: :system do
  include ActionView::RecordIdentifier

  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
  let(:expansion) { create(:expansion) }

  before do
    sign_in(admin)
    resize_window_to(1280, 900)
    visit admin_event_proxy_order_path(event)
  end

  def proxy_order
    @proxy_order ||= ProxyOrder.find_by(event_id: event.id)
  end

  describe "[C3] New item form foil and frame initial values" do
    it "[C3] foil and frame select have blank option as initial value" do
      foil_select = find("select[name='proxy_order_item[foil]']")
      frame_select = find("select[name='proxy_order_item[frame]']")

      expect(foil_select.value).to eq("")
      expect(frame_select.value).to eq("")
    end
  end

  describe "[C1] Add card with blank foil and frame" do
    it "[C1] can add card with blank foil and frame" do
      within "#new_proxy_order_item_form" do
        fill_in "proxy_order_item[card_name]", with: "Test Card"
        click_button "カード明細を追加"
      end

      expect(page).to have_content("カードを追加しました")

      item = proxy_order.proxy_order_items.where(card_name: "Test Card").first
      expect(item.foil).to be_nil
      expect(item.frame).to be_nil
    end
  end

  describe "[C2] Edit existing card to have blank foil and frame" do
    let!(:item_to_edit) { create(:proxy_order_item, proxy_order:, card_name: "Card to Edit", expansion:, foil: :foil, frame: :normal) }

    before do
      visit admin_event_proxy_order_path(event)
    end

    it "[C2] can change existing foil and frame to blank" do
      find("details", text: "Card to Edit").click

      # Change foil to blank using select method
      within "##{dom_id(item_to_edit, :edit_form)}" do
        select "", from: "proxy_order_item[foil]"
      end
      # Wait for update toast or use retry logic for the database change
      expect(page).to have_content("カードを更新しました")

      item_to_edit.reload
      expect(item_to_edit.foil).to be_nil

      # Change frame to blank using select method
      within "##{dom_id(item_to_edit, :edit_form)}" do
        select "", from: "proxy_order_item[frame]"
      end
      expect(page).to have_content("カードを更新しました")

      item_to_edit.reload
      expect(item_to_edit.frame).to be_nil
    end
  end

  describe "[C4] Card meta display excludes blank foil and frame" do
    it "[C4] shows only expansion code when foil and frame are blank" do
      item = create(:proxy_order_item, proxy_order:, card_name: "Test Card", expansion:, foil: nil, frame: nil)

      visit admin_event_proxy_order_path(event)

      within "##{dom_id(item)}" do
        meta = find("[data-role='card-meta']", visible: :all)
        expect(meta.text).to eq(expansion.scryfall_set_code.upcase)
        expect(meta.text).not_to include("／")
      end
    end

    it "[C4] shows nothing when expansion, foil and frame are all blank" do
      item = create(:proxy_order_item, proxy_order:, card_name: "Test Card", expansion: nil, foil: nil, frame: nil)

      visit admin_event_proxy_order_path(event)

      within "##{dom_id(item)}" do
        meta = find("[data-role='card-meta']", visible: :all)
        expect(meta.text).to be_empty
      end
    end
  end
end
