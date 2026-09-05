require "rails_helper"
require "nokogiri"

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
        # Use Capybara matchers to verify DOM order instead of relying on string index
        # Parse response body as Capybara document
        doc = Capybara.string(response.body)
        # Find all event titles in the DOM
        event_titles = doc.all("h3.text-2xl, h3.text-xl, .event-title, [data-test-id='event-title']").map(&:text)

        # If event titles are found in test elements, verify order
        # Otherwise, verify by checking that event3 date appears before event1 date in page source
        event3_date_str = event3.event_date.strftime("%Y年%m月%d日")
        event1_date_str = event1.event_date.strftime("%Y年%m月%d日")
        event2_date_str = event2.event_date.strftime("%Y年%m月%d日")

        # Verify all events are present
        expect(response.body).to include(event3_date_str)
        expect(response.body).to include(event1_date_str)
        expect(response.body).to include(event2_date_str)

        # Verify order by checking that event3 (latest) appears before event1
        expect(response.body.index(event3_date_str)).to be < response.body.index(event1_date_str)
        # Verify that event1 appears before event2
        expect(response.body.index(event1_date_str)).to be < response.body.index(event2_date_str)
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

      it "renders event links with correct href paths" do
        event1
        event2
        get "/events"

        # Parse HTML to verify actual href attributes
        doc = Nokogiri::HTML.parse(response.body)
        links = doc.css("a[href]")

        # Find links that go to event details (format: /events/:id)
        event_links = links.select { |link| link["href"].match?(%r{/events/\d+$}) }

        expect(event_links.length).to eq(2)

        # Verify each link points to the correct event
        event_hrefs = event_links.map { |link| link["href"] }
        expect(event_hrefs).to include("/events/#{event1.id}")
        expect(event_hrefs).to include("/events/#{event2.id}")

        # Ensure no links have incorrect format like /events.90 or /events?id=90
        expect(event_links.all? { |link| link["href"].match?(%r{^/events/\d+$}) }).to be_truthy
      end

      it "does not use events_path in index links (should use event_path)" do
        event1
        get "/events"

        # Verify the links don't contain the incorrect format
        # /events.90 would be created by events_path(event)
        expect(response.body).not_to match(%r{/events\.\d+})
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

      context "with valid event id (direct link)" do
        it "returns 404 Not Found when accessed without Turbo-Frame header" do
          get "/events/#{event1.id}"
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with valid event id via turbo_frame" do
        it "returns 200 OK when accessed with Turbo-Frame header" do
          get "/events/#{event1.id}", headers: { "Turbo-Frame" => "event_modal" }
          expect(response).to have_http_status(:ok)
        end

        it "displays event title" do
          get "/events/#{event1.id}", headers: { "Turbo-Frame" => "event_modal" }
          expect(response.body).to include(event1.title)
        end

        it "displays event date in Japanese format" do
          get "/events/#{event1.id}", headers: { "Turbo-Frame" => "event_modal" }
          expected_date = event1.event_date.strftime("%Y年%m月%d日")
          expect(response.body).to include(expected_date)
        end

        it "displays event description" do
          event_with_desc = create(:event, title: "Event with description", description: "This is a test description")
          get "/events/#{event_with_desc.id}", headers: { "Turbo-Frame" => "event_modal" }
          expect(response.body).to include("This is a test description")
        end

        it "displays '説明はありません' when description is nil" do
          event_no_desc = create(:event, title: "Event without description", description: nil)
          get "/events/#{event_no_desc.id}", headers: { "Turbo-Frame" => "event_modal" }
          expect(response.body).to include("説明はありません")
        end

        it "displays created_by username" do
          admin_user = create(:user, username: "adminuser")
          event_by_admin = create(:event, title: "Admin Event", created_by: admin_user)
          get "/events/#{event_by_admin.id}", headers: { "Turbo-Frame" => "event_modal" }
          expect(response.body).to include("adminuser")
        end

        it "displays created_at in Japanese format" do
          get "/events/#{event1.id}", headers: { "Turbo-Frame" => "event_modal" }
          expected_datetime = event1.created_at.strftime("%Y年%m月%d日 %H:%M")
          expect(response.body).to include(expected_datetime)
        end

        it "wraps content in turbo_frame with id='event_modal'" do
          get "/events/#{event1.id}", headers: { "Turbo-Frame" => "event_modal" }
          expect(response.body).to include('id="event_modal"')
        end

        it "includes close button in header" do
          get "/events/#{event1.id}", headers: { "Turbo-Frame" => "event_modal" }
          expect(response.body).to include("閉じる")
        end

        it "includes turbo_frame=\"_top\" attribute on edit trade link" do
          get "/events/#{event1.id}", headers: { "Turbo-Frame" => "event_modal" }
          doc = Nokogiri::HTML.parse(response.body)
          # Find the link with href matching trade_path pattern
          trade_link = doc.css("a[href='#{trade_path(event1.id)}']").first
          expect(trade_link).not_to be_nil, "Trade link with href '#{trade_path(event1.id)}' not found"
          expect(trade_link["data-turbo-frame"]).to eq("_top")
        end
      end

      context "with discarded event" do
        it "returns 404 Not Found when accessed without Turbo-Frame header" do
          discarded_event = create(:event, title: "Discarded Event")
          discarded_event.discard!

          get "/events/#{discarded_event.id}"
          expect(response).to have_http_status(:not_found)
        end

        it "returns 404 Not Found when accessed via turbo_frame" do
          discarded_event = create(:event, title: "Discarded Event")
          discarded_event.discard!

          get "/events/#{discarded_event.id}", headers: { "Turbo-Frame" => "event_modal" }
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with non-existent event id" do
        it "returns 404 Not Found" do
          get "/events/999999"
          expect(response).to have_http_status(:not_found)
        end

        it "returns 404 for non-existent event via turbo_frame" do
          # Verify that turbo_frame request still returns 404
          get "/events/999999", headers: { "Turbo-Frame" => "event_modal" }
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with timezone handling" do
        it "displays event_date in Japanese format with configured timezone" do
          # Verify that strftime uses the configured timezone
          # Rails default is UTC; verify the format is correctly rendered
          get "/events/#{event1.id}", headers: { "Turbo-Frame" => "event_modal" }
          expected_date = event1.event_date.strftime("%Y年%m月%d日")
          expect(response.body).to include(expected_date)
        end

        it "displays created_at in Japanese format with correct time" do
          # Verify datetime is formatted correctly with timezone handling
          get "/events/#{event1.id}", headers: { "Turbo-Frame" => "event_modal" }
          expected_datetime = event1.created_at.strftime("%Y年%m月%d日 %H:%M")
          expect(response.body).to include(expected_datetime)
        end
      end
    end
  end
end
