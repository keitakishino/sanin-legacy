require 'rails_helper'

RSpec.describe 'AddForeignKeyToEventsCreatedBy' do
  describe 'schema' do
    it 'adds foreign key constraint to created_by_id' do
      foreign_keys = ActiveRecord::Base.connection.foreign_keys(:events)
      fk = foreign_keys.find { |key| key.column == 'created_by_id' }

      expect(fk).not_to be_nil
      expect(fk.to_table).to eq('users')
    end
  end
end
