require 'rails_helper'

RSpec.describe Identity, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:identity) }

    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:uid) }
    it { is_expected.to validate_presence_of(:user_id) }

    describe 'uid uniqueness scope to provider' do
      let!(:identity) { create(:identity, provider: :google, uid: 'unique_uid') }

      it 'allows same uid for different providers' do
        new_identity = build(:twitter_identity, uid: '123456789')
        expect(new_identity).to be_valid
      end

      it 'prevents duplicate uid for same provider' do
        new_identity = build(:identity, provider: :google, uid: 'unique_uid', user: create(:user))
        expect(new_identity).not_to be_valid
        expect(new_identity.errors[:uid]).to include('has already been taken')
      end
    end

    describe 'twitter_uid_must_be_numeric' do
      context 'when provider is twitter and uid is not numeric' do
        let(:identity) { build(:twitter_identity, uid: 'invalid_uid') }

        it 'is invalid' do
          expect(identity).not_to be_valid
          expect(identity.errors[:uid]).to include('must be numeric for Twitter identities')
        end
      end

      context 'when provider is twitter and uid is numeric' do
        let(:identity) { build(:twitter_identity, uid: '987654321012345678') }

        it 'is valid' do
          expect(identity).to be_valid
        end
      end

      context 'when provider is google and uid is not numeric' do
        let(:identity) { build(:google_identity, uid: 'abc123def456') }

        it 'is valid (no numeric validation for google)' do
          expect(identity).to be_valid
        end
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:provider).with_values(google: 0, twitter: 1).with_prefix(true) }
  end

  describe 'scopes' do
    let!(:google_identity) { create(:google_identity) }
    let!(:twitter_identity) { create(:twitter_identity) }

    describe '.by_provider' do
      it 'returns identities by specified provider' do
        expect(Identity.by_provider(:google)).to contain_exactly(google_identity)
      end
    end

    describe '.google_identities' do
      it 'returns only google identities' do
        expect(Identity.google_identities).to contain_exactly(google_identity)
      end
    end

    describe '.twitter_identities' do
      it 'returns only twitter identities' do
        expect(Identity.twitter_identities).to contain_exactly(twitter_identity)
      end
    end
  end

  describe '#provider_display_name' do
    context 'when provider is google' do
      let(:identity) { build(:google_identity) }

      it 'returns "Google"' do
        expect(identity.provider_display_name).to eq('Google')
      end
    end

    context 'when provider is twitter' do
      let(:identity) { build(:twitter_identity) }

      it 'returns "Twitter(X)"' do
        expect(identity.provider_display_name).to eq('Twitter(X)')
      end
    end
  end

  describe '#twitter_profile_url' do
    context 'when provider is twitter and uid is valid numeric ID' do
      let(:identity) { build(:twitter_identity, uid: '987654321012345678') }

      it 'returns Twitter profile intent URL with user_id' do
        expected_url = 'https://twitter.com/intent/user?user_id=987654321012345678'
        expect(identity.twitter_profile_url).to eq(expected_url)
      end
    end

    context 'when provider is twitter and uid is invalid (not numeric)' do
      let(:identity) { build(:twitter_identity, uid: 'invalid_uid_with_letters') }

      it 'returns nil' do
        expect(identity.twitter_profile_url).to be_nil
      end
    end

    context 'when provider is twitter and uid contains special characters' do
      let(:identity) { build(:twitter_identity, uid: '123456789@invalid') }

      it 'returns nil' do
        expect(identity.twitter_profile_url).to be_nil
      end
    end

    context 'when provider is google' do
      let(:identity) { build(:google_identity) }

      it 'returns nil' do
        expect(identity.twitter_profile_url).to be_nil
      end
    end
  end
end
