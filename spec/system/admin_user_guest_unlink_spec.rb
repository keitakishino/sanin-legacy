require "rails_helper"

RSpec.describe "Admin User Guest Unlink", type: :system do
  let(:admin) { create(:user, role: :admin) }
  let(:target_user) { create(:user, password: "password123", username: "target_user") }

  before do
    sign_in(admin)
    resize_window_to(1280, 900)
  end

  describe "C1: Display linked list when linked participants exist" do
    it "shows empty message when no linked participants" do
      visit admin_user_path(target_user)
      within "#guest_linked_list" do
        expect(page).to have_text("紐づけ済みの自由入力はありません")
      end
    end

    it "displays linked participants grouped by name" do
      event1 = create(:event, event_type: :proxy_order, title: "イベント1", created_by: admin)
      event2 = create(:event, event_type: :proxy_order, title: "イベント2", created_by: admin)
      event3 = create(:event, event_type: :proxy_order, title: "イベント3", created_by: admin)
      event4 = create(:event, event_type: :proxy_order, title: "イベント4", created_by: admin)
      proxy_order1 = create(:proxy_order, event: event1)
      proxy_order2 = create(:proxy_order, event: event2)
      proxy_order3 = create(:proxy_order, event: event3)
      proxy_order4 = create(:proxy_order, event: event4)

      # Create linked participants with variation in name representation
      create(:proxy_order_participant, proxy_order: proxy_order1, user: target_user, linked_from_guest_name: "やまだ")
      create(:proxy_order_participant, proxy_order: proxy_order2, user: target_user, linked_from_guest_name: "やまだ")
      # Discarded participant should still be included in the count
      discarded = create(:proxy_order_participant, proxy_order: proxy_order3, user: target_user, linked_from_guest_name: "やまだ")
      discarded.update_column(:discarded_at, Time.current)
      create(:proxy_order_participant, proxy_order: proxy_order4, user: target_user, linked_from_guest_name: "やまだ")

      visit admin_user_path(target_user)
      within "#guest_linked_list" do
        expect(page).to have_text("紐づけ済みの自由入力")
        expect(page).to have_text("やまだ")
        expect(page).to have_text("4 件")
        expect(page).to have_link("解除")
      end

      # Should have exactly one row
      rows = page.all("#guest_linked_row_0")
      expect(rows.size).to eq(1)
    end

    it "includes more orders indicator" do
      events = 4.times.map { |i| create(:event, event_type: :proxy_order, title: "イベント#{i + 1}", created_by: admin) }
      proxy_orders = events.map { |e| create(:proxy_order, event: e) }

      proxy_orders.each do |po|
        create(:proxy_order_participant, proxy_order: po, user: target_user, linked_from_guest_name: "やまだ")
      end

      visit admin_user_path(target_user)
      within "#guest_linked_list" do
        expect(page).to have_text("イベント1、イベント2、イベント3")
        expect(page).to have_text("ほか 1 件")
      end
    end
  end

  describe "C6: Non-linked participants should not appear" do
    it "excludes participants without linked_from_guest_name" do
      event1 = create(:event, event_type: :proxy_order, title: "イベント1", created_by: admin)
      proxy_order1 = create(:proxy_order, event: event1)

      # Create non-linked participant (registered user)
      create(:proxy_order_participant, proxy_order: proxy_order1, user: target_user, linked_from_guest_name: nil)

      visit admin_user_path(target_user)
      within "#guest_linked_list" do
        expect(page).to have_text("紐づけ済みの自由入力はありません")
      end
      expect(page).not_to have_content("4 件")
    end
  end

  describe "C2: Display unlink confirmation modal when unlink button is clicked" do
    it "shows confirmation modal with participant details" do
      event1 = create(:event, event_type: :proxy_order, title: "イベント1", created_by: admin)
      event2 = create(:event, event_type: :proxy_order, title: "イベント2", created_by: admin)
      proxy_order1 = create(:proxy_order, event: event1)
      proxy_order2 = create(:proxy_order, event: event2)

      create(:proxy_order_participant, proxy_order: proxy_order1, user: target_user, linked_from_guest_name: "やまだ")
      create(:proxy_order_participant, proxy_order: proxy_order2, user: target_user, linked_from_guest_name: "やまだ")

      visit admin_user_path(target_user)
      click_link "解除"

      within "turbo-frame#guest_link_modal" do
        expect(page).to have_text("「やまだ」の 2 件を自由入力に戻します。")
        expect(page).to have_text(target_user.username)
        expect(page).to have_button("キャンセル")
        expect(page).to have_button("解除する")
      end
    end
  end

  describe "C2: Cancel button closes modal without unlinking" do
    it "closes modal when cancel button is clicked" do
      event = create(:event, event_type: :proxy_order, title: "イベント", created_by: admin)
      proxy_order = create(:proxy_order, event:)
      create(:proxy_order_participant, proxy_order:, user: target_user, linked_from_guest_name: "やまだ")

      visit admin_user_path(target_user)
      click_link "解除"

      within "turbo-frame#guest_link_modal" do
        click_button "キャンセル"
        expect(page).not_to have_text("解除する")
      end

      within "#guest_linked_list" do
        expect(page).to have_text("やまだ")
        expect(page).to have_link("解除")
      end
    end
  end

  describe "C3: Unlink participants and update list" do
    it "unlinks participants and displays toast on success" do
      event1 = create(:event, event_type: :proxy_order, title: "イベント1", created_by: admin)
      event2 = create(:event, event_type: :proxy_order, title: "イベント2", created_by: admin)
      proxy_order1 = create(:proxy_order, event: event1)
      proxy_order2 = create(:proxy_order, event: event2)

      participant1 = create(:proxy_order_participant, proxy_order: proxy_order1, user: target_user, linked_from_guest_name: "やまだ")
      participant2 = create(:proxy_order_participant, proxy_order: proxy_order2, user: target_user, linked_from_guest_name: "やまだ")

      visit admin_user_path(target_user)
      click_link "解除"

      within "turbo-frame#guest_link_modal" do
        click_button "解除する"
      end

      expect(page).to have_text("自由入力に戻しました")

      within "#guest_linked_list" do
        expect(page).to have_text("紐づけ済みの自由入力はありません")
      end

      participant1.reload
      expect(participant1.user_id).to be_nil
      expect(participant1.guest_name).to eq("やまだ")
      expect(participant1.linked_from_guest_name).to be_nil

      participant2.reload
      expect(participant2.user_id).to be_nil
      expect(participant2.guest_name).to eq("やまだ")
      expect(participant2.linked_from_guest_name).to be_nil
    end

    it "participant is visible in admin order edit page after unlinking" do
      event = create(:event, event_type: :proxy_order, title: "テスト通販", created_by: admin)
      proxy_order = create(:proxy_order, event:)
      participant = create(:proxy_order_participant, proxy_order:, user: target_user, linked_from_guest_name: "やまだ")
      # Create allocation so participant shows in the admin order view
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      visit admin_user_path(target_user)
      click_link "解除"

      within "turbo-frame#guest_link_modal" do
        click_button "解除する"
      end

      expect(page).to have_text("自由入力に戻しました")

      visit admin_event_proxy_order_path(event)
      expect(page).to have_text("やまだ")
    end
  end

  describe "C5: Error handling for conflicting guest participant" do
    it "displays error and does not unlink when guest participant exists" do
      event = create(:event, event_type: :proxy_order, title: "テスト通販", created_by: admin)
      proxy_order = create(:proxy_order, event:)

      linked = create(:proxy_order_participant, proxy_order:, user: target_user, linked_from_guest_name: "やまだ")
      create(:proxy_order_participant, :guest, proxy_order:, guest_name: "やまだ")

      visit admin_user_path(target_user)
      click_link "解除"

      within "turbo-frame#guest_link_modal" do
        click_button "解除する"
        # Wait for error response
        expect(page).to have_text("テスト通販")
        expect(page).to have_text("すでに「やまだ」の参加者がいます")
      end

      within "#guest_linked_list" do
        expect(page).to have_text("やまだ")
        expect(page).to have_link("解除")
      end

      linked.reload
      expect(linked.user_id).to eq(target_user.id)
      expect(linked.linked_from_guest_name).to eq("やまだ")
    end
  end

  describe "C10: Linked list updates after linking from modal" do
    it "shows linked participant in the list immediately after linking" do
      event = create(:event, event_type: :proxy_order, title: "イベント", created_by: admin)
      proxy_order = create(:proxy_order, event:)
      participant = create(:proxy_order_participant, :guest, proxy_order:, guest_name: "さとう")
      # Create allocation so participant is included in view
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 1)

      visit admin_user_path(target_user)
      within "#guest_linked_list" do
        expect(page).to have_text("紐づけ済みの自由入力はありません")
      end

      click_link "自由入力の参加者を紐づける"
      fill_in "guest_link_q", with: "さとう"
      click_button "検索"

      choose "guest_link_candidate_0"
      click_button "紐づける"
      expect(page).to have_text("紐づけました")

      within "#guest_linked_list" do
        expect(page).to have_text("さとう")
        expect(page).to have_text("1 件")
        expect(page).to have_link("解除")
      end
    end
  end
end
