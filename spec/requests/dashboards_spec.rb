require "rails_helper"

RSpec.describe "Dashboards", type: :request do
  let(:user) { create(:user, email: "test@example.com", password: "password123") }
  let(:other_user) { create(:user, email: "other@example.com", password: "password456") }
  let(:event) { create(:event) }

  before do
    # Ensure host is set correctly for request specs
    host! "www.example.com"
  end

  describe "GET /" do
    context "when user is not logged in" do
      it "redirects to signin page" do
        get "/"
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is logged in" do
      before do
        post signin_path, params: { email: user.email, password: "password123" }
        follow_redirect!
      end

      it "returns status 200" do
        get "/"
        expect(response).to have_http_status(:ok)
      end

      it "displays the dashboard page" do
        get "/"
        expect(response.body).to include("ダッシュボード")
      end

      it "includes empty turbo-frame element with src attribute for lazy loading" do
        get "/"
        expect(response.body).to include('id="incomplete_trades"')
        expect(response.body).to include('src="/dashboards/incomplete_trades"')
        expect(response.body).to include('loading="lazy"')
      end

      context "when user has no incomplete trades" do
        it "does not include trades content in main page" do
          get "/"
          # The main page should only have the empty turbo-frame tag
          expect(response.body).not_to include("トレードはまだありません")
        end

        it "displays 'トレードはまだありません' when accessing incomplete_trades endpoint" do
          get "/dashboards/incomplete_trades"
          expect(response.body).to include("トレードはまだありません")
        end
      end

      context "when user has incomplete trades" do
        let(:event2) { create(:event) }
        let!(:pending_trade) { create(:trade, user:, event:, status: :pending) }
        let!(:in_progress_trade) { create(:trade, user:, event: event2, status: :in_progress) }

        it "does not display trades content in main dashboard page" do
          get "/"
          # Main dashboard should be empty, content loaded via turbo-frame
          expect(response.body).not_to include(event.title)
        end

        it "displays pending trade with status badge via incomplete_trades endpoint" do
          get "/dashboards/incomplete_trades"
          expect(response.body).to include(event.title)
          expect(response.body).to include("未処理")
        end

        it "displays in_progress trade with status badge via incomplete_trades endpoint" do
          get "/dashboards/incomplete_trades"
          expect(response.body).to include("進行中")
        end

        it "displays trade aggregates via incomplete_trades endpoint" do
          get "/dashboards/incomplete_trades"
          expect(response.body).to include("出す合計")
          expect(response.body).to include("欲しい合計")
          expect(response.body).to include("差分")
        end

        it "displays incomplete trades in order (newest first) via incomplete_trades endpoint" do
          event3 = create(:event)
          event4 = create(:event)
          older_trade = create(:trade, user:, event: event3, status: :pending, created_at: 1.day.ago)
          newer_trade = create(:trade, user:, event: event4, status: :pending, created_at: 1.hour.ago)

          get "/dashboards/incomplete_trades"

          older_index = response.body.index("出す合計")
          newer_index = response.body.rindex("出す合計")
          expect(newer_index).to be > older_index
        end

        it "displays maximum 3 incomplete trades when more than 3 exist via incomplete_trades endpoint" do
          create(:trade, user:, event: create(:event), status: :pending)
          create(:trade, user:, event: create(:event), status: :pending)
          create(:trade, user:, event: create(:event), status: :pending)
          create(:trade, user:, event: create(:event), status: :pending)
          create(:trade, user:, event: create(:event), status: :pending)

          get "/dashboards/incomplete_trades"

          # Count occurrences of "出す合計" (each trade has one)
          count = response.body.scan("出す合計").count
          expect(count).to eq(3)
        end

        it "does not display completed trades via incomplete_trades endpoint" do
          completed_trade = create(:trade, user:, event: create(:event), status: :completed)

          get "/dashboards/incomplete_trades"

          # Response should only have incomplete trades, not completed
          # Check by counting trade cards instead of relying on created_at string
          count = response.body.scan('class="bg-white border border-stone-200 rounded-[10px]').count
          expect(count).to eq(2) # Only pending and in_progress trades
        end

        it "does not display cancelled trades via incomplete_trades endpoint" do
          cancelled_trade = create(:trade, user:, event: create(:event), status: :cancelled)

          get "/dashboards/incomplete_trades"

          # Response should only have incomplete trades, not cancelled
          count = response.body.scan('class="bg-white border border-stone-200 rounded-[10px]').count
          expect(count).to eq(2) # Only pending and in_progress trades
        end
      end

      context "when other user has incomplete trades" do
        let!(:other_user_trade) { create(:trade, user: other_user, event:, status: :pending) }

        it "does not display other user's trades in incomplete_trades endpoint" do
          get "/dashboards/incomplete_trades"

          # Should display empty message
          expect(response.body).to include("トレードはまだありません")
        end
      end

      context "when user has trades with associated event" do
        let!(:trade) { create(:trade, user:, event:, status: :pending, offers_total_amount: 1000, wants_total_amount: 500, net_amount: 500) }

        it "displays event date formatted correctly via incomplete_trades endpoint" do
          get "/dashboards/incomplete_trades"
          formatted_date = event.event_date.strftime("%Y年%m月%d日")
          expect(response.body).to include(formatted_date)
        end

        it "displays trade link to show action via incomplete_trades endpoint" do
          get "/dashboards/incomplete_trades"
          expect(response.body).to include(trade_path(event.id))
        end

        it "displays status enum translation via incomplete_trades endpoint" do
          get "/dashboards/incomplete_trades"
          expect(response.body).to include(I18n.t("activerecord.enums.trade.status.pending"))
        end
      end
    end
  end

  describe "GET /dashboards/incomplete_trades" do
    context "when user is not logged in" do
      it "redirects to signin page" do
        get "/dashboards/incomplete_trades"
        expect(response).to redirect_to(signin_path)
      end
    end

    context "when user is logged in" do
      before do
        post signin_path, params: { email: user.email, password: "password123" }
      end

      it "returns status 200" do
        get "/dashboards/incomplete_trades"
        expect(response).to have_http_status(:ok)
      end

      it "returns content without layout" do
        get "/dashboards/incomplete_trades"
        # Should have turbo-frame but no HTML structure (no doctype, html, body tags)
        expect(response.body).not_to include("<!DOCTYPE html>")
      end

      it "includes turbo-frame with incomplete_trades id" do
        get "/dashboards/incomplete_trades"
        expect(response.body).to include('id="incomplete_trades"')
      end

      context "when user has no trades" do
        it "displays empty message" do
          get "/dashboards/incomplete_trades"
          expect(response.body).to include("トレードはまだありません")
        end
      end

      context "when user has incomplete trades" do
        let(:event2) { create(:event) }
        let!(:pending_trade) { create(:trade, user:, event:, status: :pending) }
        let!(:in_progress_trade) { create(:trade, user:, event: event2, status: :in_progress) }

        it "returns trade details" do
          get "/dashboards/incomplete_trades"
          expect(response.body).to include(event.title)
          expect(response.body).to include(event2.title)
        end

        it "includes trade aggregates" do
          get "/dashboards/incomplete_trades"
          expect(response.body).to include("出す合計")
          expect(response.body).to include("欲しい合計")
          expect(response.body).to include("差分")
        end
      end
    end
  end
end
