require 'rails_helper'

RSpec.describe 'CreateEvents' do
  describe 'schema' do
    it 'creates events table with correct columns' do
      expect(ActiveRecord::Base.connection.table_exists?(:events)).to be true

      columns = ActiveRecord::Base.connection.columns(:events).map(&:name)
      expect(columns).to include('id', 'title', 'description', 'event_date', 'created_by_id', 'spreadsheet_id', 'discarded_at', 'created_at', 'updated_at')
    end

    it 'has correct column types' do
      columns_hash = ActiveRecord::Base.connection.columns(:events).index_by(&:name)

      expect(columns_hash['title'].type).to eq :string
      expect(columns_hash['description'].type).to eq :text
      expect(columns_hash['event_date'].type).to eq :date
      expect(columns_hash['created_by_id'].type).to eq :integer
      expect(columns_hash['spreadsheet_id'].type).to eq :string
      expect(columns_hash['discarded_at'].type).to eq :datetime
    end

    it 'has correct constraints' do
      columns_hash = ActiveRecord::Base.connection.columns(:events).index_by(&:name)

      expect(columns_hash['title'].null).to be false
      expect(columns_hash['event_date'].null).to be false
    end
  end

  describe 'indices' do
    it 'creates required indices' do
      indexes = ActiveRecord::Base.connection.indexes(:events).map(&:name)

      expect(indexes).to include('index_events_on_created_by_id')
      expect(indexes).to include('index_events_on_discarded_at')
      expect(indexes).to include('index_events_on_event_date_and_discarded_at')
      expect(indexes).to include('index_events_on_title')
    end

    it 'creates composite index on event_date and discarded_at' do
      indexes = ActiveRecord::Base.connection.indexes(:events)
      composite_index = indexes.find { |idx| idx.name == 'index_events_on_event_date_and_discarded_at' }

      expect(composite_index).not_to be_nil
      expect(composite_index.columns).to eq([ 'event_date', 'discarded_at' ])
    end
  end
end
