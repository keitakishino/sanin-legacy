require 'rails_helper'

RSpec.describe Expansion, type: :model do
  describe 'validations' do
    context 'presence validations' do
      it 'requires scryfall_set_code' do
        expansion = build(:expansion, scryfall_set_code: nil)
        expect(expansion.valid?).to be false
        expect(expansion.errors[:scryfall_set_code]).to include("can't be blank")
      end

      it 'requires name' do
        expansion = build(:expansion, name: nil)
        expect(expansion.valid?).to be false
        expect(expansion.errors[:name]).to include("can't be blank")
      end
    end

    context 'uniqueness validations' do
      it 'requires scryfall_set_code to be unique' do
        create(:expansion, scryfall_set_code: 'THB')
        expansion = build(:expansion, scryfall_set_code: 'THB')
        expect(expansion.valid?).to be false
        expect(expansion.errors[:scryfall_set_code]).to include('has already been taken')
      end
    end

    context 'length validations' do
      it 'enforces maximum length of 255 for scryfall_set_code' do
        expansion = build(:expansion, scryfall_set_code: 'a' * 256)
        expect(expansion.valid?).to be false
      end

      it 'enforces maximum length of 255 for name' do
        expansion = build(:expansion, name: 'a' * 256)
        expect(expansion.valid?).to be false
      end

      it 'enforces maximum length of 255 for name_ja' do
        expansion = build(:expansion, name_ja: 'あ' * 256)
        expect(expansion.valid?).to be false
      end
    end
  end

  describe 'creation' do
    context 'with valid attributes' do
      it 'creates an expansion' do
        expansion = build(:expansion)
        expect(expansion).to be_valid
        expect { expansion.save }.to change(Expansion, :count).by(1)
      end

      it 'creates an expansion with name_ja' do
        expansion = create(:expansion, name_ja: 'セット名')
        expect(expansion.name_ja).to eq('セット名')
      end

      it 'creates an expansion without name_ja' do
        expansion = create(:expansion, name_ja: nil)
        expect(expansion.name_ja).to be_nil
        expect(expansion).to be_persisted
      end

      it 'generates created_at timestamp' do
        expansion = create(:expansion)
        expect(expansion.created_at).to be_present
        expect(expansion.created_at).to be_a(Time)
      end

      it 'generates updated_at timestamp' do
        expansion = create(:expansion)
        expect(expansion.updated_at).to be_present
        expect(expansion.updated_at).to be_a(Time)
      end
    end

    context 'with invalid attributes' do
      it 'fails without scryfall_set_code' do
        expansion = build(:expansion, scryfall_set_code: nil)
        expect(expansion).not_to be_valid
        expect(expansion.errors[:scryfall_set_code]).to include("can't be blank")
      end

      it 'fails without name' do
        expansion = build(:expansion, name: nil)
        expect(expansion).not_to be_valid
        expect(expansion.errors[:name]).to include("can't be blank")
      end

      it 'fails when scryfall_set_code is empty string' do
        expansion = build(:expansion, scryfall_set_code: '')
        expect(expansion).not_to be_valid
      end

      it 'fails when name is empty string' do
        expansion = build(:expansion, name: '')
        expect(expansion).not_to be_valid
      end
    end

    context 'uniqueness constraints' do
      it 'fails when scryfall_set_code is duplicated' do
        create(:expansion, scryfall_set_code: 'THB')
        expansion = build(:expansion, scryfall_set_code: 'THB')
        expect(expansion).not_to be_valid
        expect(expansion.errors[:scryfall_set_code]).to include('has already been taken')
      end

      it 'allows different scryfall_set_codes' do
        create(:expansion, scryfall_set_code: 'THB')
        expansion = build(:expansion, scryfall_set_code: 'M21')
        expect(expansion).to be_valid
      end
    end

    context 'length constraints' do
      it 'fails when scryfall_set_code exceeds 255 characters' do
        expansion = build(:expansion, scryfall_set_code: 'a' * 256)
        expect(expansion).not_to be_valid
      end

      it 'fails when name exceeds 255 characters' do
        expansion = build(:expansion, name: 'a' * 256)
        expect(expansion).not_to be_valid
      end

      it 'fails when name_ja exceeds 255 characters' do
        expansion = build(:expansion, name_ja: 'あ' * 256)
        expect(expansion).not_to be_valid
      end

      it 'succeeds with scryfall_set_code at 255 characters' do
        expansion = build(:expansion, scryfall_set_code: 'a' * 255)
        expect(expansion).to be_valid
      end

      it 'succeeds with name at 255 characters' do
        expansion = build(:expansion, name: 'a' * 255)
        expect(expansion).to be_valid
      end

      it 'succeeds with name_ja at 255 characters' do
        expansion = build(:expansion, name_ja: 'あ' * 255)
        expect(expansion).to be_valid
      end
    end
  end

  describe 'schema' do
    it 'has the expected columns' do
      expect(Expansion.column_names).to include(
        'id',
        'scryfall_set_code',
        'name',
        'name_ja',
        'created_at',
        'updated_at'
      )
    end

    it 'has scryfall_set_code as non-nullable string' do
      column = Expansion.columns.find { |c| c.name == 'scryfall_set_code' }
      expect(column.type).to eq(:string)
      expect(column.null).to be false
    end

    it 'has name as non-nullable string' do
      column = Expansion.columns.find { |c| c.name == 'name' }
      expect(column.type).to eq(:string)
      expect(column.null).to be false
    end

    it 'has name_ja as nullable string' do
      column = Expansion.columns.find { |c| c.name == 'name_ja' }
      expect(column.type).to eq(:string)
      expect(column.null).to be true
    end
  end
end
