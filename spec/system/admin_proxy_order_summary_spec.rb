require "rails_helper"

RSpec.describe "Admin Proxy Order Summary", type: :system do
  let(:admin) { create(:user, role: :admin) }
  let(:event) { create(:event, :proxy_order, created_by: admin) }
  let!(:proxy_order) { create(:proxy_order, event:, status: :ordered) }
  let!(:registered) { create(:user, username: "buyer") }
  let!(:user_participant) { create(:proxy_order_participant, proxy_order:, user: registered) }
  let!(:guest_participant) { create(:proxy_order_participant, :guest, proxy_order:, guest_name: "ヤマダ") }

  before do
    sign_in(admin)
    resize_window_to(1280, 900)
    visit admin_event_proxy_order_path(event)
  end

  describe "C4: Guest participant display without annotation" do
    it "displays guest participant name without the free input annotation" do
      within "#summary_proxy_order_participant_#{guest_participant.id}" do
        expect(page).to have_content("ヤマダ")
        expect(page).not_to have_content("自由入力")
      end
    end
  end

  describe "C5: Registered user participant display" do
    it "displays registered user name only" do
      within "#summary_proxy_order_participant_#{user_participant.id}" do
        expect(find("b", match: :first).text).to eq("buyer")
      end
    end
  end

  describe "C3: Summary note display" do
    it "displays the summary note for ordered status" do
      within "#proxy_order_summary" do
        expect(page).to have_content(I18n.t("admin.proxy_order.summary_note_ordered"))
      end
    end
  end
end
