require 'rails_helper'

RSpec.describe 'Admin Event Type', type: :system do
  let(:admin_user) { create(:admin_user, email: 'admin@example.com', password: 'password123') }
  let(:regular_user) { create(:user, email: 'user@example.com', password: 'password123') }

  describe 'C1: Create event with type selection' do
    before do
      sign_in(admin_user)
      visit new_admin_event_path
    end

    it 'displays radio buttons for event types' do
      expect(page).to have_content('種類')
      expect(page).to have_selector('input[type="radio"][value="trade"]')
      expect(page).to have_selector('input[type="radio"][value="tournament"]')
      expect(page).to have_selector('input[type="radio"][value="proxy_order"]')
    end

    it 'has trade as default selection' do
      expect(page).to have_checked_field('トレード')
    end

    it 'shows only expected form fields for tournament event' do
      choose 'event_event_type_tournament'

      # Check that only the expected input types exist (excluding radios which are multiple)
      expect(page).to have_field('event[title]', type: 'text')
      expect(page).to have_field('event[description]', type: 'textarea')
      expect(page).to have_field('event[event_date]', type: 'date')
    end

    it 'creates tournament event successfully' do
      choose 'event_event_type_tournament'
      fill_in 'event[title]', with: 'Tournament Event'
      fill_in 'event[description]', with: 'Tournament description'
      fill_in 'event[event_date]', with: (Date.today + 7.days).strftime('%Y-%m-%d')

      click_button I18n.t("admin.events.submit")

      expect(page).to have_current_path(admin_events_path)
      expect(Event.last.tournament?).to be true
      expect(page).to have_content('大会')
    end

    it 'creates proxy_order event successfully' do
      choose 'event_event_type_proxy_order'
      fill_in 'event[title]', with: 'Proxy Order Event'
      fill_in 'event[description]', with: 'Proxy order description'
      fill_in 'event[event_date]', with: (Date.today + 7.days).strftime('%Y-%m-%d')

      click_button I18n.t("admin.events.submit")

      expect(page).to have_current_path(admin_events_path)
      expect(Event.last.proxy_order?).to be true
    end

    it 'creates trade event by default' do
      fill_in 'event[title]', with: 'Trade Event'
      fill_in 'event[description]', with: 'Trade description'
      fill_in 'event[event_date]', with: (Date.today + 7.days).strftime('%Y-%m-%d')

      click_button I18n.t("admin.events.submit")

      # click_button はリクエストの完了を待たないので、先に画面遷移を確かめてから DB を見る
      expect(page).to have_current_path(admin_events_path)
      expect(Event.last.trade?).to be true
    end
  end

  describe 'C2: Edit event type immutability' do
    let(:tournament_event) { create(:event, :tournament, created_by: admin_user) }

    before do
      sign_in(admin_user)
      visit edit_admin_event_path(tournament_event)
    end

    it 'does not display event_type input field' do
      expect(page).not_to have_selector('input[name="event[event_type]"]')
      expect(page).not_to have_selector('select[name="event[event_type]"]')
    end

    it 'displays event type as read-only text' do
      expect(page).to have_selector('#event_type_display')
      expect(page).to have_content('大会')
      expect(page).to have_content('種類は作成後に変更できません')
    end

    it 'allows updating other attributes' do
      fill_in 'event[title]', with: 'Updated Title'
      click_button I18n.t("admin.events.submit")

      expect(page).to have_current_path(admin_events_path)
      expect(tournament_event.reload.title).to eq('Updated Title')
      expect(tournament_event.reload.tournament?).to be true
    end
  end

  describe 'C3: Event detail modal and trade restrictions' do
    let(:tournament_event) { create(:event, :tournament, event_date: Event.current_date + 7.days) }
    let(:trade_event) { create(:event, :trade, event_date: Event.current_date + 8.days) }

    before do
      sign_in(regular_user)
      # Ensure events are created before visiting the page
      tournament_event
      trade_event
      visit events_path
    end

    it 'tournament event modal does not show trade link' do
      find("a[href=\"#{event_path(tournament_event)}\"]").click
      expect(page).to have_content(tournament_event.title)
      expect(page).to have_content(tournament_event.event_date.strftime('%Y年%m月%d日'))
      expect(page).to have_content(tournament_event.description)
      expect(page).not_to have_link('自分のトレードを編集する')
    end

    it 'trade event modal shows trade link' do
      find("a[href=\"#{event_path(trade_event)}\"]").click
      expect(page).to have_link('自分のトレードを編集する')
    end

    it 'redirects when accessing trade path for tournament event' do
      visit trade_path(tournament_event.id)
      expect(page).to have_current_path(events_path)
      expect(Trade.where(event: tournament_event, user: regular_user)).not_to exist
    end
  end
end
