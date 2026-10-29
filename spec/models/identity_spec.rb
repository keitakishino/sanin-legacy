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
        new_identity = build(:discord_identity, uid: '123456789')
        expect(new_identity).to be_valid
      end

      it 'prevents duplicate uid for same provider' do
        new_identity = build(:identity, provider: :google, uid: 'unique_uid', user: create(:user))
        expect(new_identity).not_to be_valid
        expect(new_identity.errors[:uid]).to include('has already been taken')
      end
    end

    describe 'discord_uid_must_be_numeric' do
      context 'when provider is discord and uid is not numeric' do
        let(:identity) { build(:discord_identity, uid: 'invalid_uid') }

        it 'validates discord uid must be numeric' do
          expect(identity).not_to be_valid
          expect(identity.errors[:uid]).to include('must be numeric for Discord identities')
        end
      end

      context 'when provider is discord and uid is numeric' do
        let(:identity) { build(:discord_identity, uid: '987654321012345678') }

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
    it { is_expected.to define_enum_for(:provider).with_values(google: 0, discord: 2).with_prefix(true) }

    it 'has providers google=0 and discord=2 only' do
      expect(Identity.providers).to eq('google' => 0, 'discord' => 2)
    end
  end

  describe 'scopes' do
    let!(:google_identity) { create(:google_identity) }
    let!(:discord_identity) { create(:discord_identity) }

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

    describe '.discord_identities' do
      it 'returns only discord identities' do
        expect(Identity.discord_identities).to contain_exactly(discord_identity)
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

    context 'when provider is discord' do
      let(:identity) { build(:discord_identity) }

      it 'returns "Discord"' do
        expect(identity.provider_display_name).to eq('Discord')
      end
    end
  end

  describe '#twitter_profile_url' do
    it 'does not respond to twitter_profile_url' do
      expect(build(:discord_identity)).not_to respond_to(:twitter_profile_url)
    end
  end
end
