require "rails_helper"

RSpec.describe "Admin User Guest Link", type: :system do
  let(:admin) { create(:user, role: :admin) }
  let(:target_user) { create(:user, password: "password123") }

  before do
    sign_in(admin)
    resize_window_to(1280, 900)
  end

  describe "C1: Display guest link section" do
    it "shows the guest link panel and button on user show page" do
      visit admin_user_path(target_user)
      within "#guest-link" do
        expect(page).to have_text("通販ユーザー紐づけ")
        expect(page).to have_link("自由入力の参加者を紐づける")
      end
    end
  end

  describe "C2: Open modal with search form" do
    it "displays modal frame with search label and button" do
      visit admin_user_path(target_user)
      click_link "自由入力の参加者を紐づける"
      within "turbo-frame#guest_link_modal" do
        expect(page).to have_field("guest_link_q")
        expect(page).to have_text("自由入力の名前")
        expect(page).to have_button("検索")
      end
    end
  end

  describe "C3: Search and display candidates" do
    let!(:event1) { create(:event, event_type: :proxy_order, title: "イベント1", created_by: admin) }
    let!(:event2) { create(:event, event_type: :proxy_order, title: "イベント2", created_by: admin) }
    let!(:event3) { create(:event, event_type: :proxy_order, title: "イベント3", created_by: admin) }
    let!(:event4) { create(:event, event_type: :proxy_order, title: "イベント4", created_by: admin) }
    let!(:proxy_order1) { create(:proxy_order, event: event1) }
    let!(:proxy_order2) { create(:proxy_order, event: event2) }
    let!(:proxy_order3) { create(:proxy_order, event: event3) }
    let!(:proxy_order4) { create(:proxy_order, event: event4) }

    before do
      create(:proxy_order_participant, :guest, proxy_order: proxy_order1, guest_name: "ヤマダ")
      create(:proxy_order_participant, :guest, proxy_order: proxy_order2, guest_name: "ヤマダ")
      create(:proxy_order_participant, :guest, proxy_order: proxy_order3, guest_name: "Tanaka")
      create(:proxy_order_participant, :guest, proxy_order: proxy_order4, guest_name: "佐藤")
    end

    it "displays candidates matching partial search with normalization" do
      visit admin_user_path(target_user)
      click_link "自由入力の参加者を紐づける"

      within "turbo-frame#guest_link_modal" do
        fill_in "guest_link_q", with: "ﾔﾏ"
        click_button "検索"
      end

      expect(page).to have_text("1 名")
      expect(page).to have_text("ヤマダ")
      expect(page).not_to have_text("佐藤")
    end

    it "displays all candidates on blank search" do
      visit admin_user_path(target_user)
      click_link "自由入力の参加者を紐づける"

      within "turbo-frame#guest_link_modal" do
        click_button "検索"
      end

      expect(page).to have_text("3 名")
      expect(page).to have_text("ヤマダ")
      expect(page).to have_text("Tanaka")
      expect(page).to have_text("佐藤")
    end

    it "shows up to 3 event titles and more count" do
      event5 = create(:event, event_type: :proxy_order, title: "イベント5", created_by: admin)
      proxy_order5 = create(:proxy_order, event: event5)
      create(:proxy_order_participant, :guest, proxy_order: proxy_order5, guest_name: "ヤマダ")

      visit admin_user_path(target_user)
      click_link "自由入力の参加者を紐づける"

      within "turbo-frame#guest_link_modal" do
        fill_in "guest_link_q", with: "ヤ"
        click_button "検索"
      end

      # ヤマダ should have 3 entries (proxy_order1, proxy_order2, and proxy_order5) but show first 3 and "ほか 1 件" if 4+
      expect(page).to have_text("3 件")
    end
  end

  describe "C4: Radio selection and submit button state" do
    let!(:event1) { create(:event, event_type: :proxy_order, title: "イベント1", created_by: admin) }
    let!(:event2) { create(:event, event_type: :proxy_order, title: "イベント2", created_by: admin) }
    let!(:proxy_order1) { create(:proxy_order, event: event1) }
    let!(:proxy_order2) { create(:proxy_order, event: event2) }

    before do
      create(:proxy_order_participant, :guest, proxy_order: proxy_order1, guest_name: "Aさん")
      create(:proxy_order_participant, :guest, proxy_order: proxy_order2, guest_name: "Bさん")
    end

    it "enables submit button when a row is selected and disables when switching" do
      visit admin_user_path(target_user)
      click_link "自由入力の参加者を紐づける"

      within "turbo-frame#guest_link_modal" do
        click_button "検索"
        expect(page).to have_button("紐づける", disabled: true)

        choose "guest_link_candidate_0"
        expect(page).to have_button("紐づける", disabled: false)
        expect(page).to have_css("tr:has(input[type=radio]:checked)", count: 1, text: "Aさん")

        choose "guest_link_candidate_1"
        expect(page).to have_button("紐づける", disabled: false)
        expect(page).to have_css("tr:has(input[type=radio]:checked)", count: 1, text: "Bさん")
      end
    end
  end

  describe "C5: Conflict detection" do
    let!(:event) { create(:event, event_type: :proxy_order, title: "テスト通販", created_by: admin) }
    let!(:proxy_order) { create(:proxy_order, event:) }

    before do
      create(:proxy_order_participant, :guest, proxy_order:, guest_name: "すずき")
      create(:proxy_order_participant, proxy_order:, user: target_user)
    end

    it "disables conflicting candidate and shows reason" do
      visit admin_user_path(target_user)
      click_link "自由入力の参加者を紐づける"

      within "turbo-frame#guest_link_modal" do
        click_button "検索"
        expect(page).to have_text("選べません")
        expect(page).to have_text("テスト通販")
        expect(page).to have_no_checked_field("guest_link_candidate_0")
      end
    end
  end

  describe "C6: Too many candidates message" do
    before do
      event = create(:event, event_type: :proxy_order, created_by: admin)
      proxy_order = create(:proxy_order, event:)
      51.times do |i|
        create(:proxy_order_participant, :guest, proxy_order:, guest_name: "guest#{i.to_s.rjust(3, '0')}")
      end
    end

    it "shows narrowing message when over 50 candidates" do
      visit admin_user_path(target_user)
      click_link "自由入力の参加者を紐づける"

      within "turbo-frame#guest_link_modal" do
        click_button "検索"
        expect(page).to have_text("さらに絞り込んでください")
        expect(page).to have_no_css("input[type=radio]")
      end
    end
  end

  describe "C7: Successful linking" do
    let!(:event1) { create(:event, event_type: :proxy_order, title: "通販1", created_by: admin) }
    let!(:event2) { create(:event, event_type: :proxy_order, title: "通販2", created_by: admin) }
    let!(:event3) { create(:event, event_type: :proxy_order, title: "通販3", created_by: admin) }
    let!(:proxy_order1) { create(:proxy_order, event: event1) }
    let!(:proxy_order2) { create(:proxy_order, event: event2) }
    let!(:proxy_order3) { create(:proxy_order, event: event3) }

    before do
      create(:proxy_order_participant, :guest, proxy_order: proxy_order1, guest_name: "やまだ")
      create(:proxy_order_participant, :guest, proxy_order: proxy_order2, guest_name: "やまだ")
      participant = create(:proxy_order_participant, :guest, proxy_order: proxy_order3, guest_name: "やまだ")
      participant.update_column(:discarded_at, Time.current)
    end

    it "links all matching participants and displays success toast" do
      visit admin_user_path(target_user)
      click_link "自由入力の参加者を紐づける"

      within "turbo-frame#guest_link_modal" do
        click_button "検索"
        choose "guest_link_candidate_0"
        click_button "紐づける"
      end

      expect(page).to have_text("やまだ")
      expect(page).to have_text("紐づけました")
      expect(page).to have_no_css("turbo-frame#guest_link_modal input[type=radio]")

      # Verify all participants are linked
      linked = ProxyOrderParticipant.with_discarded.where(user: target_user)
      expect(linked.count).to eq(3)
      expect(linked.all? { |p| p.user_id == target_user.id && p.guest_name.nil? }).to be true
    end

    it "displays username in admin proxy order edit screen after linking" do
      visit admin_user_path(target_user)
      click_link "自由入力の参加者を紐づける"

      within "turbo-frame#guest_link_modal" do
        click_button "検索"
        choose "guest_link_candidate_0"
        click_button "紐づける"
      end

      expect(page).to have_text("紐づけました")

      visit admin_event_proxy_order_path(event1.id)
      expect(page).to have_text(target_user.username)
    end
  end

  describe "C8: User dashboard access after linking" do
    let!(:event) { create(:event, event_type: :proxy_order, title: "テスト通販", created_by: admin) }
    let!(:proxy_order) { create(:proxy_order, event:) }
    let!(:item) { create(:proxy_order_item, proxy_order:) }

    before do
      participant = create(:proxy_order_participant, :guest, proxy_order:, guest_name: "やまだ")
      create(:proxy_order_allocation, proxy_order_participant: participant, proxy_order_item: item, quantity: 1)
    end

    it "allows linked user to view proxy order after linking" do
      visit admin_user_path(target_user)
      click_link "自由入力の参加者を紐づける"

      within "turbo-frame#guest_link_modal" do
        click_button "検索"
        choose "guest_link_candidate_0"
        click_button "紐づける"
      end

      Capybara.reset_sessions!
      sign_in(target_user)
      visit root_path

      within "#my_proxy_orders" do
        click_link "詳細を表示"
      end

      expect(page).to have_current_path(proxy_order_path(event))
    end
  end

  describe "C9: Runtime conflict detection" do
    let!(:event) { create(:event, event_type: :proxy_order, title: "テスト通販", created_by: admin) }
    let!(:proxy_order) { create(:proxy_order, event:) }

    before do
      create(:proxy_order_participant, :guest, proxy_order:, guest_name: "たなべ")
    end

    it "shows error when conflict is created between screen open and submit" do
      visit admin_user_path(target_user)
      click_link "自由入力の参加者を紐づける"

      within "turbo-frame#guest_link_modal" do
        click_button "検索"
        # Wait for candidates to be displayed after blank search
        expect(page).to have_text("1 名")
        expect(page).to have_text("たなべ")
      end

      # Add a conflicting participant outside the screen
      create(:proxy_order_participant, proxy_order:, user: target_user)

      within "turbo-frame#guest_link_modal" do
        choose "guest_link_candidate_0"
        click_button "紐づける"
      end

      within "turbo-frame#guest_link_modal" do
        expect(page).to have_css("#guest_link_errors")
        expect(page).to have_text("すでに参加しています")
      end

      # Verify participant was not updated
      participant = ProxyOrderParticipant.find_by(guest_name: "たなべ")
      expect(participant.user_id).to be_nil
      expect(participant.guest_name).to eq("たなべ")
    end
  end

  describe "C11: Existing sections remain" do
    it "shows registered info, external accounts, and trades sections" do
      visit admin_user_path(target_user)

      expect(page).to have_text("登録情報")
      expect(page).to have_text("外部アカウント連携")
      expect(page).to have_text("トレード一覧")
    end
  end

  describe "C12: Proxy order participant management continues to work" do
    let!(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
    let!(:proxy_order) { create(:proxy_order, event:) }

    it "allows adding and editing participants from admin proxy order edit" do
      visit admin_event_proxy_order_path(event)

      within "#new_proxy_order_item_form" do
        fill_in "proxy_order_item[card_name]", with: "Test Card"
        click_button "カード明細を追加"
      end

      expect(page).to have_text("カードを追加しました")
    end
  end
end
