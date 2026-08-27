require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:identities).dependent(:destroy) }
    it { is_expected.to have_many(:invitations_issued).dependent(:restrict_with_exception) }
    it { is_expected.to have_many(:invitations_used).dependent(:restrict_with_exception) }
    it { is_expected.to have_many(:created_events).dependent(:restrict_with_exception) }
  end

  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_uniqueness_of(:username) }
    it { is_expected.to validate_length_of(:username).is_at_least(3).is_at_most(50) }

    it { is_expected.to validate_uniqueness_of(:email).allow_nil }

    describe 'password validation' do
      context 'when password is provided' do
        subject { build(:user, password: 'password123', password_confirmation: 'password123') }

        it { is_expected.to validate_presence_of(:password) }
        it { is_expected.to validate_presence_of(:password_confirmation) }
        it { is_expected.to validate_length_of(:password).is_at_least(8) }
      end

      context 'when password is not provided' do
        subject { build(:user, password: nil, password_confirmation: nil) }

        it { is_expected.not_to validate_presence_of(:password) }
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:role).with_values(general: 0, admin: 1).with_prefix(true) }
  end

  describe 'has_secure_password' do
    let(:user) { build(:user, password: 'password123', password_confirmation: 'password123') }

    it 'authenticates with correct password' do
      user.save
      expect(user.authenticate('password123')).to eq(user)
    end

    it 'does not authenticate with incorrect password' do
      user.save
      expect(user.authenticate('wrongpassword')).to eq(false)
    end
  end

  describe 'scopes' do
    let!(:admin_user) { create(:admin_user) }
    let!(:general_user) { create(:user) }

    describe '.admins' do
      it 'returns only admin users' do
        expect(User.admins).to contain_exactly(admin_user)
      end
    end

    describe '.general_users' do
      it 'returns only general users' do
        expect(User.general_users).to contain_exactly(general_user)
      end
    end
  end

  describe 'email validation' do
    context 'when email is provided' do
      it 'validates email format' do
        user = build(:user, email: 'invalid-email')
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('is invalid')
      end

      it 'allows valid email format' do
        user = build(:user, email: 'valid@example.com')
        expect(user).to be_valid
      end
    end

    context 'when email is nil' do
      it 'is valid' do
        user = build(:user, email: nil)
        expect(user).to be_valid
      end
    end
  end
end
