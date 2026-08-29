require "rails_helper"

RSpec.describe "Admin::Events", type: :request do
  let(:admin_user) { create(:admin_user, email: "admin@example.com", password: "password123") }
  let(:general_user) { create(:user, email: "user@example.com", password: "password123") }

  describe "GET /admin/events" do
    context "when user is not logged in" do
      it "redirects to sign in path" do
        get admin_events_path
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        get admin_events_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "returns success status" do
        get admin_events_path
        expect(response).to have_http_status(:ok)
      end

      it "displays all events" do
        create_list(:event, 3, created_by: admin_user)
        get admin_events_path
        expect(response.body).to include(I18n.t("admin.events.title"))
      end

      it "displays events in reverse chronological order by event_date" do
        event1 = create(:event, created_by: admin_user, event_date: Date.today)
        event2 = create(:event, created_by: admin_user, event_date: Date.today + 7.days)

        get admin_events_path
        body = response.body

        pos1 = body.index(event1.title)
        pos2 = body.index(event2.title)

        expect(pos2).to be < pos1
      end

      it "does not display discarded events" do
        event = create(:event, created_by: admin_user)
        event.discard!

        get admin_events_path
        expect(response.body).not_to include(event.title)
      end

      it "includes created_by user email" do
        event = create(:event, created_by: admin_user)
        get admin_events_path
        expect(response.body).to include(admin_user.email)
      end
    end
  end

  describe "GET /admin/events/new" do
    context "when user is not logged in" do
      it "redirects to sign in path" do
        get new_admin_event_path
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        get new_admin_event_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "returns success status" do
        get new_admin_event_path
        expect(response).to have_http_status(:ok)
      end

      it "has a form for creating an event" do
        get new_admin_event_path
        expect(response.body).to include("type=\"text\"")
        expect(response.body).to include("type=\"date\"")
      end
    end
  end

  describe "POST /admin/events" do
    context "when user is not logged in" do
      it "redirects to sign in path" do
        post admin_events_path, params: { event: { title: "Test Event" } }
        expect(response).to redirect_to(signin_path)
      end

      it "does not create an event" do
        expect {
          post admin_events_path, params: { event: { title: "Test Event" } }
        }.not_to change(Event, :count)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        post admin_events_path, params: { event: { title: "Test Event" } }
        expect(response).to have_http_status(:forbidden)
      end

      it "does not create an event" do
        expect {
          post admin_events_path, params: { event: { title: "Test Event" } }
        }.not_to change(Event, :count)
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      context "with valid parameters" do
        let(:valid_params) do
          {
            event: {
              title: "New Event",
              description: "Event Description",
              event_date: Date.today + 7.days
            }
          }
        end

        it "creates an event" do
          expect {
            post admin_events_path, params: valid_params
          }.to change(Event, :count).by(1)
        end

        it "sets created_by to current admin" do
          post admin_events_path, params: valid_params
          event = Event.last
          expect(event.created_by_id).to eq(admin_user.id)
        end

        it "redirects to admin_events_path" do
          post admin_events_path, params: valid_params
          expect(response).to redirect_to(admin_events_path)
        end

        it "displays success notice" do
          post admin_events_path, params: valid_params
          follow_redirect!
          expect(response.body).to include(I18n.t("admin.events.created"))
        end
      end

      context "with invalid parameters" do
        let(:invalid_params) do
          {
            event: {
              title: "",
              description: "Event Description",
              event_date: Date.today + 7.days
            }
          }
        end

        it "does not create an event" do
          expect {
            post admin_events_path, params: invalid_params
          }.not_to change(Event, :count)
        end

        it "returns unprocessable_entity status" do
          post admin_events_path, params: invalid_params
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "displays error messages" do
          post admin_events_path, params: invalid_params
          expect(response.body).to include("error")
        end
      end
    end
  end

  describe "GET /admin/events/:id/edit" do
    let(:event) { create(:event, created_by: admin_user) }

    context "when user is not logged in" do
      it "redirects to sign in path" do
        get edit_admin_event_path(event)
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        get edit_admin_event_path(event)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "returns success status" do
        get edit_admin_event_path(event)
        expect(response).to have_http_status(:ok)
      end

      it "displays the event data" do
        get edit_admin_event_path(event)
        expect(response.body).to include(event.title)
      end
    end
  end

  describe "PATCH /admin/events/:id" do
    let(:event) { create(:event, created_by: admin_user, title: "Original Title") }

    context "when user is not logged in" do
      it "redirects to sign in path" do
        patch admin_event_path(event), params: { event: { title: "Updated Title" } }
        expect(response).to redirect_to(signin_path)
      end

      it "does not update the event" do
        patch admin_event_path(event), params: { event: { title: "Updated Title" } }
        expect(event.reload.title).to eq("Original Title")
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        patch admin_event_path(event), params: { event: { title: "Updated Title" } }
        expect(response).to have_http_status(:forbidden)
      end

      it "does not update the event" do
        patch admin_event_path(event), params: { event: { title: "Updated Title" } }
        expect(event.reload.title).to eq("Original Title")
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      context "with valid parameters" do
        let(:update_params) do
          {
            event: {
              title: "Updated Title",
              description: "Updated Description"
            }
          }
        end

        it "updates the event" do
          patch admin_event_path(event), params: update_params
          expect(event.reload.title).to eq("Updated Title")
          expect(event.reload.description).to eq("Updated Description")
        end

        it "redirects to admin_events_path" do
          patch admin_event_path(event), params: update_params
          expect(response).to redirect_to(admin_events_path)
        end

        it "displays success notice" do
          patch admin_event_path(event), params: update_params
          follow_redirect!
          expect(response.body).to include(I18n.t("admin.events.updated"))
        end
      end

      context "with invalid parameters" do
        let(:invalid_params) do
          {
            event: {
              title: "",
              description: "Updated Description"
            }
          }
        end

        it "does not update the event" do
          patch admin_event_path(event), params: invalid_params
          expect(event.reload.title).to eq("Original Title")
        end

        it "returns unprocessable_entity status" do
          patch admin_event_path(event), params: invalid_params
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end

  describe "DELETE /admin/events/:id" do
    let(:event) { create(:event, created_by: admin_user) }

    context "when user is not logged in" do
      it "redirects to sign in path" do
        delete admin_event_path(event)
        expect(response).to redirect_to(signin_path)
      end

      it "does not discard the event" do
        delete admin_event_path(event)
        expect(event.reload.discarded?).to be false
      end
    end

    context "when user is a general user" do
      before do
        post signin_path, params: { email: general_user.email, password: "password123" }
      end

      it "returns forbidden status" do
        delete admin_event_path(event)
        expect(response).to have_http_status(:forbidden)
      end

      it "does not discard the event" do
        delete admin_event_path(event)
        expect(event.reload.discarded?).to be false
      end
    end

    context "when user is an admin" do
      before do
        post signin_path, params: { email: admin_user.email, password: "password123" }
      end

      it "logically deletes the event (sets discarded_at)" do
        delete admin_event_path(event)
        expect(event.reload.discarded?).to be true
        expect(event.reload.discarded_at).not_to be_nil
      end

      it "does not physically delete the event from database" do
        event_id = event.id
        delete admin_event_path(event)
        expect(Event.with_discarded.find_by(id: event_id)).not_to be_nil
      end

      it "redirects to admin_events_path" do
        delete admin_event_path(event)
        expect(response).to redirect_to(admin_events_path)
      end

      it "displays success notice" do
        delete admin_event_path(event)
        follow_redirect!
        expect(response.body).to include(I18n.t("admin.events.deleted"))
      end

      it "removes event from index list" do
        event_title = event.title
        delete admin_event_path(event)
        get admin_events_path
        expect(response.body).not_to include(event_title)
      end
    end
  end
end
