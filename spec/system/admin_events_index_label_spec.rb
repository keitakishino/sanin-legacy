require "rails_helper"

RSpec.describe "Admin Events Index - Label Visibility on Mobile", type: :system do
  let(:admin) { create(:user, role: :admin) }

  before do
    sign_in(admin)
    create(:event, :tournament, title: "Mobile Label Event", created_by: admin)
    resize_window_to(390, 844)
    visit admin_events_path
  end

  it "displays the event type label on mobile with visible true" do
    within("tbody#events") do
      label = find("span", text: "大会", visible: :all)
      # Verify the label is visible in the viewport
      expect(label.visible?).to be true
    end
  end

  it "displays the event title on mobile" do
    within("tbody#events") do
      expect(page).to have_text("Mobile Label Event")
    end
  end
end
