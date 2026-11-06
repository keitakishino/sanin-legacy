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

      context "一覧の列" do
        let!(:completed_trade) do
          create(:trade, user:, event:, status: :completed, completed_at: 1.day.ago,
                         offers_total_amount: 1000, wants_total_amount: 900, net_amount: 100)
        end

        before do
          create(:trade_card_offer, trade: completed_trade, quantity: 3)
          create(:trade_card_want, trade: completed_trade, quantity: 2)
        end

        it "出す枚数・ほしい枚数・差額を出さない" do
          get "/histories"

          expect(response.body).not_to include("出す枚数")
          expect(response.body).not_to include("ほしい枚数")
          expect(response.body).not_to include("差額")
        end

        it "行末にトレード詳細へのリンクを出す" do
          get "/histories"

          expect(response.body).to include("詳細を表示")
          expect(response.body).to include(%(href="#{trade_path(event.id)}"))
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

        it "トレード詳細へのリンクを出さない" do
          get "/histories"

          expect(response.body).not_to include("詳細を表示")
          expect(response.body).not_to include(%(href="#{trade_path(discarded_event.id)}"))
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
          rows = response.body.scan(/<tr class="border-b border-stone-200 hover:bg-stone-50">/).count
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
        let!(:offer1) { create(:trade_card_offer, trade:, card_name: "Lightning Bolt", quantity: 2) }
        let!(:offer2) { create(:trade_card_offer, trade:, card_name: "Mox Sapphire", quantity: 1) }
        let!(:want1) { create(:trade_card_want, trade:, card_name: "Black Lotus", quantity: 1) }

        it "does not display individual card names in history table" do
          get "/histories"

          # Individual card names should NOT be in the history view (掲示内容 column removed)
          expect(response.body).not_to include("Lightning Bolt")
          expect(response.body).not_to include("Black Lotus")
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

      context "history tabs" do
        it "displays navigation with history tabs" do
          get "/histories"

          html = Nokogiri::HTML(response.body)
          nav = html.at('nav[aria-label="履歴の種類"]')
          expect(nav).to be_present
        end

        it "displays trades and proxy orders tabs with correct links" do
          get "/histories"

          html = Nokogiri::HTML(response.body)
          nav = html.at('nav[aria-label="履歴の種類"]')
          trades_link = nav.at('a[href="/histories"]')
          proxy_orders_link = nav.at('a[href="/histories/proxy_orders"]')

          expect(trades_link).to be_present
          expect(trades_link.text.strip).to eq("トレード")
          expect(proxy_orders_link).to be_present
          expect(proxy_orders_link.text.strip).to eq("代理通販")
        end

        it "highlights trades tab as active" do
          get "/histories"

          html = Nokogiri::HTML(response.body)
          nav = html.at('nav[aria-label="履歴の種類"]')
          trades_link = nav.at('a[href="/histories"]')

          expect(trades_link["aria-current"]).to eq("page")
          expect(trades_link["class"]).to include("border-accent")
          expect(trades_link["class"]).to include("text-accent")
        end

        it "does not highlight proxy orders tab as active" do
          get "/histories"

          html = Nokogiri::HTML(response.body)
          nav = html.at('nav[aria-label="履歴の種類"]')
          proxy_orders_link = nav.at('a[href="/histories/proxy_orders"]')

          expect(proxy_orders_link["aria-current"]).to be_nil
          expect(proxy_orders_link["class"]).to include("border-transparent")
        end
      end

      context "header navigation" do
        it "displays history link with correct text in header" do
          get "/histories"

          html = Nokogiri::HTML(response.body)
          header_links = html.css('header a[href="/histories"]')
          link_texts = header_links.map(&:text).map(&:strip)

          expect(link_texts.any? { |text| text == "履歴" }).to be true
        end

        it "highlights history link in desktop header when on histories page" do
          get "/histories"

          html = Nokogiri::HTML(response.body)
          desktop_nav = html.at('nav:not([data-hamburger-menu-target])')
          history_link = desktop_nav&.at('a[href="/histories"]')

          expect(history_link).to be_present
          expect(history_link["class"]).to include("text-accent")
        end
      end
    end
  end

  describe "GET /histories/proxy_orders" do
    def row_id_for(proxy_order)
      "id=\"history_proxy_order_#{proxy_order.id}\""
    end

    def row_html_for(proxy_order)
      response.body[/<tr #{Regexp.escape(row_id_for(proxy_order))}.*?<\/tr>/m]
    end

    def create_proxy_order_for(participant_user, status: :completed, event_date: Date.current - 3.days, usd_jpy_rate: 150)
      event = create(:event, :proxy_order)
      event.update_column(:event_date, event_date)
      proxy_order = create(:proxy_order, event:, status:, usd_jpy_rate:,
                                         tax_usd: 0, customs_usd: 0, shipping_usd: 0)
      create(:proxy_order_participant, proxy_order:, user: participant_user)
      proxy_order
    end

    def add_card_to(proxy_order, participant, unit_price_usd: 30, quantity: 1, lost_quantity: 0)
      item = create(:proxy_order_item, proxy_order:)
      create(:proxy_order_price_line, proxy_order_item: item, unit_price_usd:, quantity:, lost_quantity:)
      create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant,
                                      quantity:, lost_quantity:)
      item
    end

    def count_sql_queries
      count = 0
      counter = lambda do |*, payload|
        count += 1 unless %w[SCHEMA CACHE].include?(payload[:name]) || payload[:cached]
      end
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      count
    end

    context "when user is not authenticated" do
      it "redirects to signin page" do
        get "/histories/proxy_orders"

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to("/signin")
      end
    end

    context "when user is authenticated" do
      let(:user) { create(:user, password: "password123") }
      let(:other_user) { create(:user, password: "password123") }

      before do
        post "/signin", params: { email: user.email, password: "password123" }
        follow_redirect!
      end

      context "with no proxy orders" do
        it "returns 200 and shows empty state message" do
          get "/histories/proxy_orders"

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("完了した代理通販はありません")
        end
      end

      context "with a completed proxy order the user participates in" do
        let!(:proxy_order) { create_proxy_order_for(user) }

        it "displays the event title, completed badge, and link to the detail page" do
          get "/histories/proxy_orders"

          row = row_html_for(proxy_order)
          expect(row).to be_present
          expect(row).to include(proxy_order.event.title)
          expect(row).to include(I18n.t("activerecord.enums.proxy_order.status.completed"))
          expect(row).to include("href=\"/proxy_orders/#{proxy_order.event_id}\"")
          expect(row).to include(I18n.t("histories.proxy_orders.view_details"))
        end

        it "displays the event date in long format" do
          get "/histories/proxy_orders"

          expect(response.body).to include(I18n.l(proxy_order.event.event_date, format: :long))
        end
      end

      context "with proxy orders that must not be listed" do
        it "does not list ordered proxy orders" do
          ordered = create_proxy_order_for(user, status: :ordered)

          get "/histories/proxy_orders"

          expect(response.body).not_to include(row_id_for(ordered))
        end

        it "does not list arrived proxy orders" do
          arrived = create_proxy_order_for(user, status: :arrived)

          get "/histories/proxy_orders"

          expect(response.body).not_to include(row_id_for(arrived))
        end

        it "does not list completed proxy orders the user does not participate in" do
          others = create_proxy_order_for(other_user)

          get "/histories/proxy_orders"

          expect(response.body).not_to include(row_id_for(others))
        end

        it "does not list discarded proxy orders" do
          discarded = create_proxy_order_for(user)
          discarded.update_column(:discarded_at, Time.current)

          get "/histories/proxy_orders"

          expect(response.body).not_to include(row_id_for(discarded))
        end

        it "does not list proxy orders whose event is discarded" do
          discarded_event_order = create_proxy_order_for(user)
          discarded_event_order.event.update_column(:discarded_at, Time.current)

          get "/histories/proxy_orders"

          expect(response.body).not_to include(row_id_for(discarded_event_order))
        end

        it "does not list proxy orders where the user's participation is discarded" do
          discarded_participation = create_proxy_order_for(user)
          ProxyOrderParticipant.with_discarded.find_by!(proxy_order: discarded_participation, user:)
                               .update_column(:discarded_at, Time.current)

          get "/histories/proxy_orders"

          expect(response.body).not_to include(row_id_for(discarded_participation))
        end

        it "does not list proxy orders where the user only appears as a guest" do
          guest_only = create(:proxy_order, event: create(:event, :proxy_order), status: :completed,
                                            tax_usd: 0, customs_usd: 0, shipping_usd: 0, usd_jpy_rate: 150)
          create(:proxy_order_participant, :guest, proxy_order: guest_only, guest_name: "ゲスト参加者")

          get "/histories/proxy_orders"

          expect(response.body).not_to include(row_id_for(guest_only))
        end
      end

      context "with multiple completed proxy orders" do
        it "sorts by event date descending, then by proxy order id descending" do
          older_event = create_proxy_order_for(user, event_date: Date.current - 10.days)
          newer_event = create_proxy_order_for(user, event_date: Date.current - 1.day)
          same_date_later = create_proxy_order_for(user, event_date: Date.current - 1.day)

          get "/histories/proxy_orders"

          positions = [ same_date_later, newer_event, older_event ].map do |po|
            response.body.index(row_id_for(po))
          end
          expect(positions).to all(be_present)
          expect(positions).to eq(positions.sort)
        end
      end

      context "with pagination" do
        before do
          @proxy_orders = Array.new(21) do |i|
            create_proxy_order_for(user, event_date: Date.current - i.days)
          end
        end

        it "shows 20 proxy orders on the first page" do
          get "/histories/proxy_orders"

          rows = response.body.scan(/<tr id="history_proxy_order_\d+"/).count
          expect(rows).to eq(20)
          expect(response.body).to include("pagination")
        end

        it "shows the 21st proxy order on the second page" do
          get "/histories/proxy_orders", params: { page: 2 }

          expect(response).to have_http_status(:ok)
          expect(response.body.scan(/<tr id="history_proxy_order_\d+"/).count).to eq(1)
          expect(response.body).to include(row_id_for(@proxy_orders.last))
        end
      end

      context "with payment amounts" do
        it "displays the payment in yen" do
          proxy_order = create_proxy_order_for(user)
          participant = proxy_order.proxy_order_participants.find_by!(user:)
          add_card_to(proxy_order, participant, unit_price_usd: 30)

          get "/histories/proxy_orders"

          expect(row_html_for(proxy_order)).to include("¥4,500")
        end

        it "displays ¥0 when the user lost all cards" do
          proxy_order = create_proxy_order_for(user)
          participant = proxy_order.proxy_order_participants.find_by!(user:)
          add_card_to(proxy_order, participant, quantity: 1, lost_quantity: 1)

          get "/histories/proxy_orders"

          expect(row_html_for(proxy_order)).to include("¥0")
        end

        it "displays pending when the exchange rate is not set" do
          proxy_order = create_proxy_order_for(user, usd_jpy_rate: nil)
          participant = proxy_order.proxy_order_participants.find_by!(user:)
          add_card_to(proxy_order, participant, unit_price_usd: 30)

          get "/histories/proxy_orders"

          expect(row_html_for(proxy_order)).to include(I18n.t("common.pending"))
        end

        it "shows the same amount for the user as the calculator on the detail page" do
          proxy_order = create_proxy_order_for(user)
          participant = proxy_order.proxy_order_participants.find_by!(user:)
          other_participant = create(:proxy_order_participant, :guest, proxy_order:)
          add_card_to(proxy_order, participant, unit_price_usd: 30, quantity: 2)
          create(:proxy_order_allocation, proxy_order_item: proxy_order.proxy_order_items.first,
                                          proxy_order_participant: other_participant, quantity: 1)
          expected = ProxyOrderCalculator.new(proxy_order.reload).payment_jpy(participant.reload)

          get "/histories/proxy_orders"

          expect(row_html_for(proxy_order)).to include(ActiveSupport::NumberHelper.number_to_currency(expected, unit: "¥", precision: 0, format: "%u%n"))
        end
      end

      context "with query count" do
        def create_orders(count)
          Array.new(count) do |i|
            proxy_order = create_proxy_order_for(user, event_date: Date.current - i.days)
            participant = proxy_order.proxy_order_participants.find_by!(user:)
            guest = create(:proxy_order_participant, :guest, proxy_order:)
            add_card_to(proxy_order, participant, unit_price_usd: 10, quantity: 2)
            create(:proxy_order_allocation, proxy_order_item: proxy_order.proxy_order_items.first,
                                            proxy_order_participant: guest, quantity: 1)
            proxy_order
          end
        end

        it "does not increase the number of queries as proxy orders grow" do
          create_orders(3)
          queries_for_three = count_sql_queries { get "/histories/proxy_orders" }

          create_orders(7)
          queries_for_ten = count_sql_queries { get "/histories/proxy_orders" }

          expect(response.body.scan(/<tr id="history_proxy_order_\d+"/).count).to eq(10)
          expect(queries_for_ten).to eq(queries_for_three)
        end
      end

      context "history tabs" do
        it "displays page title for proxy orders" do
          get "/histories/proxy_orders"

          expect(response.body).to include("通販履歴")
        end

        it "displays navigation with history tabs" do
          get "/histories/proxy_orders"

          html = Nokogiri::HTML(response.body)
          nav = html.at('nav[aria-label="履歴の種類"]')
          expect(nav).to be_present
        end

        it "displays trades and proxy orders tabs with correct links" do
          get "/histories/proxy_orders"

          html = Nokogiri::HTML(response.body)
          nav = html.at('nav[aria-label="履歴の種類"]')
          trades_link = nav.at('a[href="/histories"]')
          proxy_orders_link = nav.at('a[href="/histories/proxy_orders"]')

          expect(trades_link).to be_present
          expect(trades_link.text.strip).to eq("トレード")
          expect(proxy_orders_link).to be_present
          expect(proxy_orders_link.text.strip).to eq("代理通販")
        end

        it "highlights proxy orders tab as active" do
          get "/histories/proxy_orders"

          html = Nokogiri::HTML(response.body)
          nav = html.at('nav[aria-label="履歴の種類"]')
          proxy_orders_link = nav.at('a[href="/histories/proxy_orders"]')

          expect(proxy_orders_link["aria-current"]).to eq("page")
          expect(proxy_orders_link["class"]).to include("border-accent")
          expect(proxy_orders_link["class"]).to include("text-accent")
        end

        it "does not highlight trades tab as active" do
          get "/histories/proxy_orders"

          html = Nokogiri::HTML(response.body)
          nav = html.at('nav[aria-label="履歴の種類"]')
          trades_link = nav.at('a[href="/histories"]')

          expect(trades_link["aria-current"]).to be_nil
          expect(trades_link["class"]).to include("border-transparent")
        end
      end

      context "header navigation" do
        it "displays history link with correct text in header" do
          get "/histories/proxy_orders"

          html = Nokogiri::HTML(response.body)
          header_links = html.css('header a[href="/histories"]')
          link_texts = header_links.map(&:text).map(&:strip)

          expect(link_texts.any? { |text| text == "履歴" }).to be true
        end

        it "highlights history link in desktop header when on proxy orders page" do
          get "/histories/proxy_orders"

          html = Nokogiri::HTML(response.body)
          desktop_nav = html.at('nav:not([data-hamburger-menu-target])')
          history_link = desktop_nav&.at('a[href="/histories"]')

          expect(history_link).to be_present
          # Verify text-accent is present as a complete class, not just in "hover:text-accent"
          classes = history_link["class"].split
          expect(classes).to include("text-accent")
          expect(classes).not_to include("text-stone-800")
        end
      end
    end
  end
end
