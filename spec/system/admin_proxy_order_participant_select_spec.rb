# System spec for Issue #382: Integrate user add UI into single combobox
# Tests the new participant-select Stimulus controller and combobox UI
require "rails_helper"

RSpec.describe "Admin Proxy Order Participant Select", type: :system do
  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, event_type: :proxy_order, created_by: admin) }
  let!(:buyer) { create(:user, username: "buyer") }
  let!(:tanaka) { create(:user, username: "Tanaka") }
  let!(:takahashi) { create(:user, username: "takahashi") }
  let!(:takagi) { create(:user, username: "Takagi") }

  let!(:proxy_order) { create(:proxy_order, event:, status: :ordered) }
  let!(:item) { create(:proxy_order_item, proxy_order:, card_name: "Target Card") }
  let!(:p_taka) { create(:proxy_order_participant, proxy_order:, user: takahashi) }
  let!(:p_guest) { create(:proxy_order_participant, :guest, proxy_order:, guest_name: "Taka Guest") }
  let!(:p_done) do
    participant = create(:proxy_order_participant, proxy_order:, user: tanaka)
    create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant)
    participant
  end

  def set_and_commit(selector, value)
    field = find(selector)
    field.set(value)
    field.send_keys(:tab)
  end

  before do
    sign_in(admin)
    resize_window_to(1280, 900)
    visit admin_event_proxy_order_path(event)
    # カード明細が割り当てで open になる想定だが、念のため開く
    unless find("#proxy_order_item_#{item.id}")[:open]
      find("#proxy_order_item_#{item.id} summary").click
    end
  end

  describe "C1: Single input field only" do
    it "has only one combobox input, no select or text_field for guest_name" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        expect(page).to have_selector("input[role='combobox']", count: 1)
        expect(page).not_to have_selector("select")
        expect(page).not_to have_selector("input[type='text'][name='proxy_order_allocation[guest_name]']")
        expect(page).not_to have_selector("input[type='text'][name='proxy_order_allocation[user_id]']")
      end
    end
  end

  describe "C2: Candidate list ordering and filtering" do
    it "candidate list is generated with participant and user data" do
      # This test verifies that @participant_candidates are passed correctly to the view
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        # Check participant buttons are rendered
        expect(page).to have_button("takahashi")
        expect(page).to have_button("Taka Guest")
        # Tanaka should not be present because it's already allocated to this item
        expect(page).not_to have_button("Tanaka")
      end
    end
  end

  describe "C3: Register a user from candidate list" do
    it "can select a registered user, enter quantity, and create allocation" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        find("input[role='combobox']").set("buy")
        find("[role='option']", text: "buyer", match: :first).click
        fill_in "proxy_order_allocation[quantity]", with: "2"
        click_button "追加"
      end

      expect(page).to have_content("注文を追加しました")

      buyer_participant = proxy_order.proxy_order_participants.find_by(user: buyer)
      expect(buyer_participant).not_to be_nil
      allocation = ProxyOrderAllocation.find_by(proxy_order_participant: buyer_participant, proxy_order_item: item)
      expect(allocation).not_to be_nil
      expect(allocation.quantity).to eq(2)
    end
  end

  describe "C4: Register a guest" do
    it "can type a new name, select add as guest option, and create guest allocation" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        find("input[role='combobox']").set("New Guest")
        find("[role='option']", text: "『New Guest』をゲストとして追加").click
        fill_in "proxy_order_allocation[quantity]", with: "1"
        click_button "追加"
      end

      expect(page).to have_content("注文を追加しました")

      guest_participant = proxy_order.proxy_order_participants.find_by(guest_name: "New Guest")
      expect(guest_participant).not_to be_nil
      allocation = ProxyOrderAllocation.find_by(proxy_order_participant: guest_participant, proxy_order_item: item)
      expect(allocation).not_to be_nil
      expect(allocation.quantity).to eq(1)
    end

    it "can handle full-width space and characters in guest name" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        # 前後の全角空白は JS の trim() で落ちるので、ゲスト行の名前は「ヤマダ」になる
        find("input[role='combobox']").set("　ヤマダ　")
        find("[role='option']", text: "『ヤマダ』をゲストとして追加").click
        fill_in "proxy_order_allocation[quantity]", with: "1"
        click_button "追加"
      end

      expect(page).to have_content("注文を追加しました")
      expect(proxy_order.proxy_order_participants.find_by(guest_name: "ヤマダ")).not_to be_nil
    end
  end

  describe "C5: Participant buttons and selection" do
    it "shows participant buttons for unassigned participants" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        # p_taka と p_guest のボタンは出現
        expect(page).to have_button("takahashi")
        expect(page).to have_button("Taka Guest")

        # p_done (Tanaka は割り当て済み）は出ない
        expect(page).not_to have_button("Tanaka")
      end
    end

    it "can click participant button to select them" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        find("button", text: "takahashi").click

        # タグが表示される
        expect(page).to have_selector("[data-participant-select-target='tag']:not([hidden])")

        # 追加ボタンが enabled
        expect(page).to have_button("追加", disabled: false)

        # 数量を入力して追加
        fill_in "proxy_order_allocation[quantity]", with: "1"
        click_button "追加"
      end

      expect(page).to have_content("注文を追加しました")

      # 既存の p_taka に新しい割り当てが作られた
      expect(ProxyOrderParticipant.count).to eq(3)
      allocation = ProxyOrderAllocation.find_by(proxy_order_participant: p_taka, proxy_order_item: item)
      expect(allocation).not_to be_nil
      expect(allocation.quantity).to eq(1)
    end
  end

  describe "C6: Already assigned participants are disabled" do
    it "shows disabled option with reason for already-assigned participant" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        find("input[role='combobox']").set("tana")

        # Tanaka のオプションが disabled
        expect(page).to have_selector("[role='option'][aria-disabled='true']", text: "Tanaka")
        expect(page).to have_content("この明細に追加済み")
      end
    end
  end

  describe "C7: Submit disabled until selection made" do
    it "has submit disabled initially and enabled after selection" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        # 初期状態で disabled
        expect(page).to have_button("追加", disabled: true)

        # ユーザーを選ぶ
        find("input[role='combobox']").set("buy")
        find("[role='option']", text: "buyer", match: :first).click

        # タグが表示、submit が enabled
        expect(page).to have_selector("[data-participant-select-target='tag']:not([hidden])")
        expect(page).to have_button("追加", disabled: false)

        # 選択を外す（×ボタン）
        find("button", text: "×").click

        # 入力欄に戻り、submit は disabled
        expect(page).to have_selector("[data-participant-select-target='combobox']:not([hidden])")
        expect(page).to have_selector("[data-participant-select-target='tag'][hidden]", visible: false)
        expect(page).to have_button("追加", disabled: true)

        # hidden フィールドが空
        expect(find("[data-participant-select-target='hiddenParticipantId']", visible: false).value).to eq("")
        expect(find("[data-participant-select-target='hiddenUserId']", visible: false).value).to eq("")
        expect(find("[data-participant-select-target='hiddenGuestName']", visible: false).value).to eq("")
      end
    end
  end

  describe "C8: Keyboard navigation" do
    it "can navigate with arrow keys and select with Enter" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        input = find("input[role='combobox']")
        input.set("taka")

        # Down arrow to first valid option
        input.send_keys(:down)

        # Check if something is selected (active style)
        active_option = find("[role='option'][aria-selected='true']", visible: :all)
        expect(active_option).to have_content("takahashi")

        # Another down to next option
        input.send_keys(:down)
        active_option = find("[role='option'][aria-selected='true']", visible: :all)
        expect(active_option).to have_content("Taka Guest")

        # Up to go back
        input.send_keys(:up)
        active_option = find("[role='option'][aria-selected='true']", visible: :all)
        expect(active_option).to have_content("takahashi")

        # Enter to select
        input.send_keys(:return)

        # Tag should be shown
        expect(page).to have_selector("[data-participant-select-target='tag']:not([hidden])")

        # Verify that form wasn't submitted (allocation count is still 1)
        expect(ProxyOrderAllocation.count).to eq(1)
      end
    end
  end

  describe "C9: Form reset after successful submission" do
    it "resets combobox to initial state after adding allocation" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        find("input[role='combobox']").set("buy")
        find("[role='option']", text: "buyer", match: :first).click
        fill_in "proxy_order_allocation[quantity]", with: "1"
        click_button "追加"
      end

      expect(page).to have_content("注文を追加しました")

      # Reload page section to check state
      within scope do
        # 入力欄が表示、値が空
        input = find("input[role='combobox']", visible: :all)
        expect(input.value).to eq("")

        # タグは非表示
        expect(page).to have_selector("[data-participant-select-target='tag'][hidden]", visible: false)

        # submit は disabled
        expect(page).to have_button("追加", disabled: true)

        # hidden フィールドが空
        expect(find("[data-participant-select-target='hiddenParticipantId']", visible: false).value).to eq("")
        expect(find("[data-participant-select-target='hiddenUserId']", visible: false).value).to eq("")
        expect(find("[data-participant-select-target='hiddenGuestName']", visible: false).value).to eq("")

        # 参加者ボタンから buyer が消えた（割り当て済みになった）
        expect(page).not_to have_button("buyer")

        # takahashi と Taka Guest は残っている
        expect(page).to have_button("takahashi")
        expect(page).to have_button("Taka Guest")
      end
    end
  end
end
