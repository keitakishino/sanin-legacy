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
        event1 = create(:event, created_by: admin_user, event_date: Event.current_date)
        event2 = create(:event, created_by: admin_user, event_date: Event.current_date + 7.days)

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

      it "does not have a 種類 column header" do
        create(:event, created_by: admin_user)
        get admin_events_path
        headers = Nokogiri::HTML(response.body).css("thead th").map { _1.text.strip }
        expect(headers).not_to include(I18n.t("activerecord.attributes.event.event_type"))
      end

      it "shows the event type label before the title in the title cell" do
        trade_event = create(:event, :trade, created_by: admin_user, title: "Trade Event")
        tournament_event = create(:event, :tournament, created_by: admin_user, title: "Tournament Event")
        proxy_event = create(:event, :proxy_order, created_by: admin_user, title: "Proxy Event")

        get admin_events_path
        doc = Nokogiri::HTML(response.body)

        # Check trade event
        trade_row = doc.css("tbody#events tr").find { |row| row.text.include?(trade_event.title) }
        expect(trade_row).not_to be_nil
        trade_label = trade_row.css("td:first span.rounded-full").first
        expect(trade_label).not_to be_nil
        expect(trade_label.text.strip).to eq("トレード")
        expect(trade_label[:class]).to include("bg-want-soft")
        expect(trade_row.text.index("トレード")).to be < trade_row.text.index(trade_event.title)

        # Check tournament event
        tournament_row = doc.css("tbody#events tr").find { |row| row.text.include?(tournament_event.title) }
        expect(tournament_row).not_to be_nil
        tournament_label = tournament_row.css("td:first span.rounded-full").first
        expect(tournament_label).not_to be_nil
        expect(tournament_label.text.strip).to eq("大会")
        expect(tournament_label[:class]).to include("bg-warning-soft")
        expect(tournament_row.text.index("大会")).to be < tournament_row.text.index(tournament_event.title)

        # Check proxy event
        proxy_row = doc.css("tbody#events tr").find { |row| row.text.include?(proxy_event.title) }
        expect(proxy_row).not_to be_nil
        proxy_label = proxy_row.css("td:first span.rounded-full").first
        expect(proxy_label).not_to be_nil
        expect(proxy_label.text.strip).to eq("代理通販")
        expect(proxy_label[:class]).to include("bg-accent-soft")
        expect(proxy_row.text.index("代理通販")).to be < proxy_row.text.index(proxy_event.title)

        # Check that title cell doesn't have hidden class
        expect(trade_row.css("td:first").first["class"]).not_to include("hidden")
      end

      it "keeps proxy order details, edit and delete with confirm" do
        proxy_event = create(:event, :proxy_order, created_by: admin_user, title: "Proxy Event")
        trade_event = create(:event, :trade, created_by: admin_user, title: "Trade Event")

        get admin_events_path
        doc = Nokogiri::HTML(response.body)

        proxy_row = doc.css("tbody#events tr").find { |row| row.text.include?(proxy_event.title) }
        trade_row = doc.css("tbody#events tr").find { |row| row.text.include?(trade_event.title) }

        # Check proxy event has the details link
        expect(proxy_row.css("a").map { |a| a["href"] }).to include(admin_event_proxy_order_path(proxy_event))
        # Check proxy event has edit and delete
        expect(proxy_row.css("a").map { |a| a["href"] }).to include(edit_admin_event_path(proxy_event))
        delete_button = proxy_row.css("button[data-turbo-confirm]").first
        expect(delete_button).not_to be_nil
        expect(delete_button["data-turbo-confirm"]).to eq(I18n.t("admin.events.confirm_delete"))

        # Check trade event doesn't have proxy order details link
        expect(trade_row.css("a").map { |a| a["href"] }).not_to include(admin_event_proxy_order_path(trade_event))
        # But has edit
        expect(trade_row.css("a").map { |a| a["href"] }).to include(edit_admin_event_path(trade_event))
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
              event_date: Event.current_date + 7.days
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
              event_date: Event.current_date + 7.days
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

        context "with past event_date" do
          let(:past_params) do
            {
              event: {
                title: "Past Event",
                description: "Event Description",
                event_date: Event.current_date - 1.day
              }
            }
          end

          it "does not create an event" do
            expect {
              post admin_events_path, params: past_params
            }.not_to change(Event, :count)
          end

          it "returns unprocessable_entity status" do
            post admin_events_path, params: past_params
            expect(response).to have_http_status(:unprocessable_entity)
          end

          it "displays error message for event_date" do
            post admin_events_path, params: past_params
            expect(response.body).to include("error")
          end
        end
      end

      context "with event_type" do
        it "creates an event with tournament type" do
          expect {
            post admin_events_path, params: {
              event: {
                title: "Tournament Event",
                description: "Tournament Description",
                event_date: Event.current_date + 7.days,
                event_type: "tournament"
              }
            }
          }.to change(Event, :count).by(1)
          expect(Event.last.tournament?).to be true
        end

        it "creates an event with default trade type when not specified" do
          expect {
            post admin_events_path, params: {
              event: {
                title: "Trade Event",
                description: "Trade Description",
                event_date: Event.current_date + 7.days
              }
            }
          }.to change(Event, :count).by(1)
          expect(Event.last.trade?).to be true
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

      it "does not have event_type input field" do
        get edit_admin_event_path(event)
        expect(response.body).not_to include('name="event[event_type]"')
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

        context "with past event_date" do
          let(:past_params) do
            {
              event: {
                title: "Updated Title",
                event_date: Event.current_date - 1.day
              }
            }
          end

          it "does not update the event" do
            patch admin_event_path(event), params: past_params
            expect(event.reload.event_date).not_to eq(Event.current_date - 1.day)
          end

          it "returns unprocessable_entity status" do
            patch admin_event_path(event), params: past_params
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end

      context "with event_type change attempt" do
        let(:trade_event) { create(:event, created_by: admin_user, event_type: :trade) }

        it "does not change event_type" do
          patch admin_event_path(trade_event), params: {
            event: {
              title: "Updated Title",
              event_type: "tournament"
            }
          }
          expect(trade_event.reload.trade?).to be true
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

      it "cascades logical deletion to related trades when event is deleted" do
        trade = create(:trade, event: event, user: general_user)
        trade_id = trade.id

        delete admin_event_path(event)

        expect(event.reload.discarded?).to be true
        expect(Trade.find_by(id: trade_id)).to be_nil
        expect(Trade.with_discarded.find_by(id: trade_id)).not_to be_nil
        expect(Trade.with_discarded.find_by(id: trade_id).discarded?).to be true
      end

      it "cascades logical deletion to proxy order and its children when proxy_order event is deleted" do
        proxy_event = create(:event, :proxy_order, created_by: admin_user)
        proxy_order = create(:proxy_order, event: proxy_event)
        item = create(:proxy_order_item, proxy_order:)
        price_line = create(:proxy_order_price_line, proxy_order_item: item)
        participant = create(:proxy_order_participant, proxy_order:)
        allocation = create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant)

        proxy_order_id = proxy_order.id
        item_id = item.id
        price_line_id = price_line.id
        participant_id = participant.id
        allocation_id = allocation.id

        delete admin_event_path(proxy_event)

        expect(response).to redirect_to(admin_events_path)
        follow_redirect!

        expect(proxy_event.reload.discarded?).to be true
        expect(ProxyOrder.with_discarded.find(proxy_order_id).discarded?).to be true
        expect(ProxyOrderItem.with_discarded.find(item_id).discarded?).to be true
        expect(ProxyOrderPriceLine.with_discarded.find(price_line_id).discarded?).to be true
        expect(ProxyOrderParticipant.with_discarded.find(participant_id).discarded?).to be true
        expect(ProxyOrderAllocation.with_discarded.find(allocation_id).discarded?).to be true

        # Verify records are hidden via default_scope
        expect(ProxyOrder.find_by(id: proxy_order_id)).to be_nil
        expect(ProxyOrderItem.find_by(id: item_id)).to be_nil
        expect(ProxyOrderPriceLine.find_by(id: price_line_id)).to be_nil
        expect(ProxyOrderParticipant.find_by(id: participant_id)).to be_nil
        expect(ProxyOrderAllocation.find_by(id: allocation_id)).to be_nil
      end

      context "with past event_date" do
        let(:past_event) do
          create(:event, created_by: admin_user).tap do |e|
            e.update_column(:event_date, Event.current_date - 1)
          end
        end

        it "deletes a past event successfully" do
          delete admin_event_path(past_event)
          follow_redirect!
          expect(response.body).to include(I18n.t("admin.events.deleted"))
        end

        it "sets discarded_at for past event" do
          delete admin_event_path(past_event)
          expect(Event.with_discarded.find(past_event.id).discarded?).to be true
        end

        it "removes past event from index list" do
          event_title = past_event.title
          delete admin_event_path(past_event)
          get admin_events_path
          expect(response.body).not_to include(event_title)
        end

        it "displays past events in admin index" do
          active_event = create(:event, created_by: admin_user)
          past_event_2 = create(:event, created_by: admin_user).tap do |e|
            e.update_column(:event_date, Event.current_date - 2)
          end

          get admin_events_path
          expect(response.body).to include(active_event.title)
          expect(response.body).to include(past_event_2.title)
        end

        it "cascades logical deletion to related trades of past event" do
          trade = create(:trade, event: past_event, user: general_user)
          trade_id = trade.id

          delete admin_event_path(past_event)

          expect(Event.with_discarded.find(past_event.id).discarded?).to be true
          expect(Trade.find_by(id: trade_id)).to be_nil
          expect(Trade.with_discarded.find_by(id: trade_id).discarded?).to be true
        end
      end

      context "when discard fails" do
        context "when trade discard fails" do
          it "does not discard the event and trade" do
            trade = create(:trade, event: event, user: general_user)
            allow_any_instance_of(Trade).to receive(:update).and_wrap_original do |m, *args, **kw|
              if kw.key?(:discarded_at) || (args.first.is_a?(Hash) && args.first.key?(:discarded_at))
                m.receiver.errors.add(:base, "論理削除に失敗しました")
                false
              else
                m.call(*args, **kw)
              end
            end

            delete admin_event_path(event)
            follow_redirect!

            expect(response.body).not_to include(I18n.t("admin.events.deleted"))
            expect(response.body).to include(I18n.t("admin.events.delete_failed"))
            expect(event.reload.discarded?).to be false
            expect(trade.reload.discarded?).to be false
          end
        end

        context "when event discard fails" do
          it "does not discard the event and does not discard trades" do
            trade = create(:trade, event: event, user: general_user)
            allow_any_instance_of(Event).to receive(:save).and_wrap_original do |m, *args, **kw|
              if kw[:context] == :discard
                m.receiver.errors.add(:base, "論理削除に失敗しました")
                false
              else
                m.call(*args, **kw)
              end
            end

            delete admin_event_path(event)
            follow_redirect!

            expect(response.body).not_to include(I18n.t("admin.events.deleted"))
            expect(response.body).to include(I18n.t("admin.events.delete_failed"))
            expect(event.reload.discarded?).to be false
            expect(trade.reload.discarded?).to be false
          end
        end
      end
    end
  end
end
