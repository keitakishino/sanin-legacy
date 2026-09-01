require "rails_helper"

RSpec.describe "HistoriesController", type: :request do
  describe "GET /histories" do
    context "when user is not authenticated" do
      it "redirects to signin page" do
        get "/histories"

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to("/signin")
      end
    end

    context "when user is authenticated" do
      let(:user) { create(:user, password: "password123") }
      let(:other_user) { create(:user, password: "password123") }
      let(:event) { create(:event) }

      before do
        post "/signin", params: { email: user.email, password: "password123" }
        follow_redirect!
      end

      context "with no trades" do
        it "returns 200" do
          get "/histories"

          expect(response).to have_http_status(:ok)
        end

        it "shows empty state message" do
          get "/histories"

          expect(response.body).to include("完了またはキャンセルされたトレードはありません")
        end

        it "displays page title" do
          get "/histories"

          expect(response.body).to include("トレード履歴")
        end
      end

      context "with completed trades" do
        let!(:completed_trade) do
          create(:trade, user:, event:, status: :completed, completed_at: 1.day.ago,
                         offers_total_amount: 1000, wants_total_amount: 900, net_amount: 100)
        end

        it "returns 200" do
          get "/histories"

          expect(response).to have_http_status(:ok)
        end

        it "displays completed trade" do
          get "/histories"

          expect(response.body).to include(event.title)
          expect(response.body).to include("完了")
        end

        it "displays trade amounts" do
          get "/histories"

          expect(response.body).to include("1,000")
          expect(response.body).to include("900")
          expect(response.body).to include("100")
        end

        it "displays completed_at date" do
          get "/histories"

          expect(response.body).to include(completed_trade.completed_at.strftime("%Y年%m月%d日"))
        end
      end

      context "with cancelled trades" do
        let!(:cancelled_trade) do
          create(:trade, user:, event:, status: :cancelled, cancelled_reason: "都合により中止",
                         offers_total_amount: 500, wants_total_amount: 400, net_amount: 100)
        end

        it "displays cancelled trade" do
          get "/histories"

          expect(response.body).to include(event.title)
          expect(response.body).to include("キャンセル")
        end

        it "displays cancelled reason with title attribute" do
          get "/histories"

          expect(response.body).to include('title="都合により中止"')
        end
      end

      context "with completed and cancelled trades mixed" do
        let(:event2) { create(:event) }
        let!(:completed_trade) do
          create(:trade, user:, event:, status: :completed, completed_at: 1.hour.ago)
        end
        let!(:cancelled_trade) do
          create(:trade, user:, event: event2, status: :cancelled, updated_at: 2.hours.ago)
        end

        it "displays both trades" do
          get "/histories"

          expect(response.body).to include("完了")
          expect(response.body).to include("キャンセル")
        end

        it "sorts by completed_at descending (most recent first)" do
          get "/histories"

          expect(response.body).to include("完了")
          # The completed_trade should appear before cancelled_trade in the HTML
          completed_index = response.body.index("完了")
          cancelled_index = response.body.index("キャンセル")
          expect(completed_index).to be < cancelled_index
        end
      end

      context "with newer cancelled trade than completed trade" do
        let(:event2) { create(:event) }
        let!(:completed_trade) do
          create(:trade, user:, event:, status: :completed, completed_at: 2.hours.ago,
                         offers_total_amount: 1000, wants_total_amount: 900, net_amount: 100)
        end
        let!(:newer_cancelled_trade) do
          create(:trade, user:, event: event2, status: :cancelled,
                         cancelled_reason: "cancelled_newer", offers_total_amount: 500,
                         wants_total_amount: 400, net_amount: 100).tap do |trade|
            trade.update_column(:updated_at, 1.hour.ago)
          end
        end

        it "sorts by coalesced timestamp (cancelled_at or updated_at) descending" do
          get "/histories"

          # Extract the tbody content to check trade order
          tbody_match = response.body.match(/<tbody[^>]*>(.*?)<\/tbody>/m)
          tbody_content = tbody_match[1] if tbody_match

          # Use event titles to identify trades in the correct order
          # The newer cancelled_trade (event2) should appear before completed_trade (event)
          event2_index = tbody_content.index(event2.title) if tbody_content
          event_index = tbody_content.index(event.title) if tbody_content

          expect(event2_index).to be_present, "event2 title should be present"
          expect(event_index).to be_present, "event title should be present"
          expect(event2_index).to be < event_index, "cancelled trade (event2) should appear before completed trade (event)"
        end
      end

      context "with older cancelled trade than completed trade" do
        let(:event2) { create(:event) }
        let!(:old_cancelled_trade) do
          create(:trade, user:, event:, status: :cancelled,
                         cancelled_reason: "cancelled_older", offers_total_amount: 500,
                         wants_total_amount: 400, net_amount: 100).tap do |trade|
            trade.update_column(:updated_at, 5.hours.ago)
          end
        end
        let!(:recent_completed_trade) do
          create(:trade, user:, event: event2, status: :completed, completed_at: 1.hour.ago,
                         offers_total_amount: 1000, wants_total_amount: 900, net_amount: 100)
        end

        it "sorts the recently completed trade before the older cancelled trade" do
          get "/histories"

          # Extract the tbody content to check trade order
          tbody_match = response.body.match(/<tbody[^>]*>(.*?)<\/tbody>/m)
          tbody_content = tbody_match[1] if tbody_match

          # Use event titles to identify trades in the correct order
          # The recent_completed_trade (event2) should appear before old_cancelled_trade (event)
          event2_index = tbody_content.index(event2.title) if tbody_content
          event_index = tbody_content.index(event.title) if tbody_content

          expect(event2_index).to be_present, "event2 title should be present"
          expect(event_index).to be_present, "event title should be present"
          expect(event2_index).to be < event_index, "completed trade (event2) should appear before cancelled trade (event)"
        end
      end

      context "with discarded event" do
        let!(:discarded_event) { create(:event, discarded_at: 1.day.ago) }
        let!(:trade) do
          create(:trade, user:, event: discarded_event, status: :completed, completed_at: 1.day.ago)
        end

        it "displays '（イベント情報不可）' for discarded event title" do
          get "/histories"

          expect(response.body).to include("（イベント情報不可）")
        end

        it "does not display discarded event title" do
          get "/histories"

          expect(response.body).not_to include(discarded_event.title)
        end
      end

      context "with pagination" do
        before do
          # Create 25 trades with different events to avoid unique constraint
          25.times do |i|
            evt = create(:event)
            create(:trade, user:, event: evt, status: :completed, completed_at: Time.current - i.hours)
          end
        end

        it "displays only 20 trades per page on first page" do
          get "/histories"

          # Count the number of table rows (excluding header)
          # Each trade row has a unique "完了" badge
          rows = response.body.scan(/<tr class="border-b hover:bg-gray-50">/).count
          expect(rows).to eq(20)
        end

        it "displays pagination controls" do
          get "/histories"

          expect(response.body).to include("pagination") # Kaminari adds pagination class
        end

        it "navigates to second page" do
          get "/histories?page=2"

          expect(response).to have_http_status(:ok)
        end
      end

      context "viewing other user's trades" do
        let(:other_event) { create(:event) }
        let!(:other_user_trade) do
          create(:trade, user: other_user, event: other_event, status: :completed, completed_at: 1.day.ago)
        end

        it "does not display other user's trades" do
          get "/histories"

          # Verify only the current user's trades are shown (empty in this case)
          expect(response.body).to include("完了またはキャンセルされたトレードはありません")
        end
      end

      context "with trade card offers and wants" do
        let!(:trade) do
          create(:trade, user:, event:, status: :completed, completed_at: 1.day.ago)
        end
        let!(:offer) { create(:trade_card_offer, trade:, card_name: "Lightning Bolt") }
        let!(:want) { create(:trade_card_want, trade:, card_name: "Black Lotus") }

        it "displays trade card offers and wants" do
          get "/histories"

          expect(response.body).to include("Lightning Bolt")
          expect(response.body).to include("Black Lotus")
        end

        it "displays '出:' prefix for offers" do
          get "/histories"

          expect(response.body).to include("出:")
        end

        it "displays '欲:' prefix for wants" do
          get "/histories"

          expect(response.body).to include("欲:")
        end
      end

      context "with no cancelled_reason" do
        let!(:cancelled_trade) do
          create(:trade, user:, event:, status: :cancelled, cancelled_reason: nil)
        end

        it "displays '—' for empty cancelled reason" do
          get "/histories"

          expect(response.body).to include("—")
        end
      end

      context "with pending and in_progress trades" do
        let(:event2) { create(:event) }
        let!(:pending_trade) { create(:trade, user:, event:, status: :pending) }
        let!(:in_progress_trade) { create(:trade, user:, event: event2, status: :in_progress) }

        it "does not display pending or in_progress trades" do
          get "/histories"

          # Should show empty state message since no completed or cancelled trades
          expect(response.body).to include("完了またはキャンセルされたトレードはありません")
        end
      end
    end
  end
end
