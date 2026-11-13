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
    # 明細は初期表示で閉じているので開く
    find("#proxy_order_item_#{item.id} summary").click
    expect(page).to have_selector("#proxy_order_item_#{item.id}[open]")
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

  describe "Guest name conflicts with username" do
    it "disables guest option and shows reason when input matches registered username" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        find("input[role='combobox']").set("buyer")

        # ゲスト行が disabled で、理由が表示される
        guest_option = find("[role='option'][aria-disabled='true']", text: "『buyer』をゲストとして追加")
        expect(guest_option).to be_present
        expect(guest_option).to have_selector("[data-role='disabled-reason']", text: "登録ユーザー buyer と同じ名前のため、ゲストにはできません")

        # 登録ユーザーの buyer 行が出現して、disabled でない
        # li の完全テキストは "buyer登録" になるので、部分マッチで検索
        buyer_option = find("[role='option']", text: /\Abuyer/)
        expect(buyer_option[:"aria-disabled"]).to be_nil

        # 登録ユーザー行をクリックするとタグが表示され、hiddenUserId に値が入り、追加ボタンが enabled
        buyer_option.click
        expect(page).to have_selector("[data-participant-select-target='tag']:not([hidden])", visible: false)
        expect(find("[data-participant-select-target='hiddenUserId']", visible: false).value).to eq(buyer.id.to_s)
        expect(page).to have_button("追加", disabled: false)
      end
    end
  end

  describe "Guest name conflicts with existing guest" do
    it "disables guest option and shows reason when input matches existing guest" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        find("input[role='combobox']").set("Taka Guest")

        # ゲスト行が disabled で、理由が表示される
        guest_option = find("[role='option'][aria-disabled='true']", text: "『Taka Guest』をゲストとして追加")
        expect(guest_option).to be_present
        expect(guest_option).to have_selector("[data-role='disabled-reason']", text: "この注文にすでに同じ名前のゲストがいます")
      end
    end
  end

  describe "Conflict detection is normalized" do
    it "detects conflicts with full-width uppercase username" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        find("input[role='combobox']").set("ＢＵＹＥＲ")

        # ゲスト行が disabled で、理由に「登録ユーザー buyer」が含まれる
        guest_option = find("[role='option'][aria-disabled='true']", text: "『ＢＵＹＥＲ』をゲストとして追加")
        reason = guest_option.find("[data-role='disabled-reason']")
        expect(reason).to have_text("登録ユーザー buyer")
      end
    end

    it "detects conflicts with full-width lowercase username" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        find("input[role='combobox']").set("ｔａｋａｇｉ")

        # ゲスト行が disabled で、理由に「登録ユーザー Takagi」が含まれる
        guest_option = find("[role='option'][aria-disabled='true']", text: "『ｔａｋａｇｉ』をゲストとして追加")
        reason = guest_option.find("[data-role='disabled-reason']")
        expect(reason).to have_text("登録ユーザー Takagi")
      end
    end

    it "detects conflicts with full-width space in guest name" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        find("input[role='combobox']").set("ＴＡＫＡ　ＧＵＥＳＴ")

        # ゲスト行が disabled で、理由に「この注文にすでに同じ名前のゲストがいます」が含まれる
        guest_option = find("[role='option'][aria-disabled='true']", text: "『ＴＡＫＡ　ＧＵＥＳＴ』をゲストとして追加")
        reason = guest_option.find("[data-role='disabled-reason']")
        expect(reason).to have_text("この注文にすでに同じ名前のゲストがいます")
      end
    end

    it "allows guest name when no conflict exists" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        find("input[role='combobox']").set("Brand New")

        # ゲスト行が enabled で、aria-disabled が付かない
        guest_option = find("[role='option']", text: "『Brand New』をゲストとして追加")
        expect(guest_option[:"aria-disabled"]).to be_nil
      end
    end
  end

  describe "Basic flow still works after conflict detection" do
    it "can select registered user, enter quantity, and create allocation (C4 unchanged)" do
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

    it "can click participant button, enter quantity, and create allocation (C4 unchanged)" do
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

    it "can type non-conflicting name, select as guest, and create guest allocation (C5 unchanged)" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        find("input[role='combobox']").set("Brand New")
        find("[role='option']", text: "『Brand New』をゲストとして追加").click
        fill_in "proxy_order_allocation[quantity]", with: "1"
        click_button "追加"
      end

      expect(page).to have_content("注文を追加しました")

      guest_participant = proxy_order.proxy_order_participants.find_by(guest_name: "Brand New")
      expect(guest_participant).not_to be_nil
      allocation = ProxyOrderAllocation.find_by(proxy_order_participant: guest_participant, proxy_order_item: item)
      expect(allocation).not_to be_nil
      expect(allocation.quantity).to eq(1)
    end
  end

  describe "PC layout (Issue #384 C4)" do
    it "displays candidate list within combobox container at PC width" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"
      within scope do
        input = find("input[role='combobox']")
        input.set("buy")

        list = find("ul[role='listbox']")
        expect(list).to be_visible

        list_rect = page.evaluate_script(
          "document.querySelector('ul[role=\"listbox\"]').getBoundingClientRect()"
        )

        # Find the combobox container (parent of input)
        combobox_container_rect = page.evaluate_script(
          "document.querySelector('input[role=\"combobox\"]').closest('.relative').getBoundingClientRect()"
        )

        # List left and right should align with container
        expect((list_rect["left"] - combobox_container_rect["left"]).abs).to be <= 1
        expect((list_rect["right"] - combobox_container_rect["right"]).abs).to be <= 1
      end
    end

    it "displays participant buttons without horizontal scroll at PC width" do
      scope = "#new_allocation_proxy_order_item_#{item.id}"

      buttons = find(scope).all("button[data-action='participant-select#pick']")
      expect(buttons.length).to be >= 2

      # Buttons should fit within scope (no horizontal scroll)
      scope_rect = page.evaluate_script(
        "document.querySelector('#{scope}').getBoundingClientRect()"
      )

      scroll_width = page.evaluate_script("document.querySelector('#{scope}').scrollWidth")
      client_width = page.evaluate_script("document.querySelector('#{scope}').clientWidth")
      expect(scroll_width).to be <= client_width + 1
    end
  end
end
