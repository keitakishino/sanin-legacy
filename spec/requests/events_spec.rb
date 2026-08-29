require "rails_helper"

RSpec.describe "Events", type: :request do
  let(:user) { create(:user, username: "testuser", email: "test@example.com", password: "password123") }
  let(:event1) { create(:event, title: "Event 1", event_date: Date.today + 5.days) }
  let(:event2) { create(:event, title: "Event 2", event_date: Date.today + 3.days) }
  let(:event3) { create(:event, title: "Event 3", event_date: Date.today + 10.days) }

  describe "GET /events (index)" do
    context "when user is not logged in" do
      it "redirects to signin path" do
        get "/events"
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is logged in" do
      before do
        post signin_path, params: { email: user.email, password: "password123" }
      end

      it "returns 200 OK" do
        event1
        get "/events"
        expect(response).to have_http_status(:ok)
      end

      it "displays all events" do
        event1
        event2
        event3
        get "/events"
        expect(response.body).to include(event1.title)
        expect(response.body).to include(event2.title)
        expect(response.body).to include(event3.title)
      end

      it "orders events by event_date in descending order" do
        event1
        event2
        event3
        get "/events"
        # Check that event3 (latest date) appears before event1
        expect(response.body.index(event3.title)).to be < response.body.index(event1.title)
        # Check that event1 appears before event2
        expect(response.body.index(event1.title)).to be < response.body.index(event2.title)
      end

      it "displays event dates in Japanese format" do
        event1
        get "/events"
        expected_date = event1.event_date.strftime("%Y年%m月%d日")
        expect(response.body).to include(expected_date)
      end

      it "displays empty message when no events exist" do
        get "/events"
        expect(response.body).to include("イベントはまだありません")
      end

      it "does not display discarded events" do
        event1
        discarded_event = create(:event, title: "Discarded Event", event_date: Date.today + 1.day)
        discarded_event.discard!

        get "/events"
        expect(response.body).to include(event1.title)
        expect(response.body).not_to include("Discarded Event")
      end

      it "has turbo_frame for modal" do
        event1
        get "/events"
        expect(response.body).to include('id="event_modal"')
      end
    end
  end

  describe "GET /events/:id (show)" do
    context "when user is not logged in" do
      it "redirects to signin path" do
        get "/events/999"
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is logged in" do
      before do
        post signin_path, params: { email: user.email, password: "password123" }
      end

      context "with valid event id" do
        it "returns 200 OK" do
          get "/events/#{event1.id}"
          expect(response).to have_http_status(:ok)
        end

        it "displays event title" do
          get "/events/#{event1.id}"
          expect(response.body).to include(event1.title)
        end

        it "displays event date in Japanese format" do
          get "/events/#{event1.id}"
          expected_date = event1.event_date.strftime("%Y年%m月%d日")
          expect(response.body).to include(expected_date)
        end

        it "displays event description" do
          event_with_desc = create(:event, title: "Event with description", description: "This is a test description")
          get "/events/#{event_with_desc.id}"
          expect(response.body).to include("This is a test description")
        end

        it "displays '説明はありません' when description is nil" do
          event_no_desc = create(:event, title: "Event without description", description: nil)
          get "/events/#{event_no_desc.id}"
          expect(response.body).to include("説明はありません")
        end

        it "displays created_by username" do
          admin_user = create(:user, username: "adminuser")
          event_by_admin = create(:event, title: "Admin Event", created_by: admin_user)
          get "/events/#{event_by_admin.id}"
          expect(response.body).to include("adminuser")
        end

        it "displays created_at in Japanese format" do
          get "/events/#{event1.id}"
          expected_datetime = event1.created_at.strftime("%Y年%m月%d日 %H:%M")
          expect(response.body).to include(expected_datetime)
        end

        it "wraps content in turbo_frame with id='event_modal'" do
          get "/events/#{event1.id}"
          expect(response.body).to include('id="event_modal"')
        end

        it "includes close button in header" do
          get "/events/#{event1.id}"
          expect(response.body).to include("閉じる")
        end
      end

      context "with discarded event" do
        it "returns 404 Not Found" do
          discarded_event = create(:event, title: "Discarded Event")
          discarded_event.discard!

          get "/events/#{discarded_event.id}"
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with non-existent event id" do
        it "returns 404 Not Found" do
          get "/events/999999"
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
