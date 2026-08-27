require 'rails_helper'

RSpec.describe Invitation, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:issued_by).class_name('User') }
    it { is_expected.to belong_to(:used_by).class_name('User').optional }
  end

  describe 'validations' do
    subject { build(:invitation) }

    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_uniqueness_of(:code) }
    it { is_expected.to validate_presence_of(:issued_by_id) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:expires_at) }

    describe 'code format validation' do
      it 'allows alphanumeric codes' do
        invitation = build(:invitation, code: 'abc123XYZ')
        expect(invitation).to be_valid
      end

      it 'rejects codes with special characters' do
        invitation = build(:invitation, code: 'abc-123')
        expect(invitation).not_to be_valid
        expect(invitation.errors[:code]).to include('must contain only alphanumeric characters')
      end

      it 'rejects codes with spaces' do
        invitation = build(:invitation, code: 'abc 123')
        expect(invitation).not_to be_valid
      end
    end

    describe 'signup_token uniqueness validation' do
      let(:invitation) { create(:invitation, signup_token: 'token123') }

      it 'allows duplicate nil signup_token' do
        new_invitation = build(:invitation, signup_token: nil)
        expect(new_invitation).to be_valid
      end

      it 'prevents duplicate signup_token' do
        new_invitation = build(:invitation, signup_token: 'token123')
        expect(new_invitation).not_to be_valid
        expect(new_invitation.errors[:signup_token]).to include('has already been taken')
      end
    end

    describe 'custom validations on create' do
      describe 'issued_by_is_admin' do
        it 'prevents non-admin users from issuing invitations' do
          general_user = create(:user)
          invitation = build(:invitation, issued_by: general_user)
          expect(invitation).not_to be_valid
          expect(invitation.errors[:issued_by]).to include('must be an admin user')
        end

        it 'allows admin users to issue invitations' do
          admin_user = create(:admin_user)
          invitation = build(:invitation, issued_by: admin_user)
          expect(invitation).to be_valid
        end
      end

      describe 'expires_at_in_future' do
        it 'prevents past expiration dates' do
          invitation = build(:invitation, expires_at: 1.day.ago)
          expect(invitation).not_to be_valid
          expect(invitation.errors[:expires_at]).to include('must be in the future')
        end

        it 'allows future expiration dates' do
          invitation = build(:invitation, expires_at: 1.day.from_now)
          expect(invitation).to be_valid
        end
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(active: 0, used: 1, expired: 2, revoked: 3).with_prefix(true) }
  end

  describe 'scopes' do
    let!(:active_invitation) { create(:invitation, status: :active) }
    let!(:used_invitation) { create(:used_invitation) }
    let!(:expired_invitation) { create(:expired_invitation) }
    let!(:revoked_invitation) { create(:revoked_invitation) }

    describe '.active_invitations' do
      it 'returns only active invitations' do
        expect(Invitation.active_invitations).to contain_exactly(active_invitation)
      end
    end

    describe '.used_invitations' do
      it 'returns only used invitations' do
        expect(Invitation.used_invitations).to contain_exactly(used_invitation)
      end
    end

    describe '.expired_invitations' do
      it 'returns only expired invitations' do
        expect(Invitation.expired_invitations).to contain_exactly(expired_invitation)
      end
    end

    describe '.revoked_invitations' do
      it 'returns only revoked invitations' do
        expect(Invitation.revoked_invitations).to contain_exactly(revoked_invitation)
      end
    end

    describe '.not_used' do
      it 'returns active, expired, and revoked invitations' do
        expect(Invitation.not_used).to contain_exactly(active_invitation, expired_invitation, revoked_invitation)
      end
    end

    describe '.expired_and_active' do
      it 'returns expired and active invitations' do
        expect(Invitation.expired_and_active).to contain_exactly(active_invitation, expired_invitation)
      end
    end
  end

  describe '#expired?' do
    context 'when expires_at is in the past' do
      let(:invitation) { build(:expired_invitation) }

      it 'returns true' do
        expect(invitation.expired?).to be true
      end
    end

    context 'when expires_at is in the future' do
      let(:invitation) { build(:invitation) }

      it 'returns false' do
        expect(invitation.expired?).to be false
      end
    end
  end

  describe '#used?' do
    context 'when status is used' do
      let(:invitation) { build(:used_invitation) }

      it 'returns true' do
        expect(invitation.used?).to be true
      end
    end

    context 'when status is not used' do
      let(:invitation) { build(:invitation) }

      it 'returns false' do
        expect(invitation.used?).to be false
      end
    end
  end

  describe '#available?' do
    context 'when active and not expired' do
      let(:invitation) { build(:invitation) }

      it 'returns true' do
        expect(invitation.available?).to be true
      end
    end

    context 'when expired' do
      let(:invitation) { build(:expired_invitation) }

      it 'returns false' do
        expect(invitation.available?).to be false
      end
    end

    context 'when not active' do
      let(:invitation) { build(:used_invitation) }

      it 'returns false' do
        expect(invitation.available?).to be false
      end
    end
  end

  describe '#use_by' do
    let(:invitation) { create(:invitation) }
    let(:user) { create(:user) }

    it 'updates used_by, used_at, and status' do
      invitation.use_by(user)
      expect(invitation.used_by).to eq(user)
      expect(invitation.used_at).to be_within(1.second).of(Time.current)
      expect(invitation.status).to eq('used')
    end
  end

  describe '#generate_signup_token' do
    let(:invitation) { create(:invitation) }

    it 'generates a random alphanumeric token' do
      token = invitation.generate_signup_token
      expect(token).to match(/\A[a-zA-Z0-9]{24}\z/)
    end

    it 'updates signup_token' do
      token = invitation.generate_signup_token
      expect(invitation.signup_token).to eq(token)
    end

    it 'sets signup_token_expires_at to 1 hour from now' do
      freeze_time do
        invitation.generate_signup_token
        expect(invitation.signup_token_expires_at).to be_within(1.second).of(1.hour.from_now)
      end
    end
  end

  describe '.find_by_code' do
    let(:invitation) { create(:invitation, code: 'TESTCODE') }

    it 'finds invitation by code' do
      expect(Invitation.find_by_code('TESTCODE')).to eq(invitation)
    end

    it 'returns nil if code not found' do
      expect(Invitation.find_by_code('NOTFOUND')).to be_nil
    end
  end

  describe '.find_by_signup_token' do
    let(:invitation) { create(:invitation) }

    before { invitation.generate_signup_token }

    it 'finds invitation by signup_token' do
      expect(Invitation.find_by_signup_token(invitation.signup_token)).to eq(invitation)
    end

    it 'returns nil if token not found' do
      expect(Invitation.find_by_signup_token('NOTFOUND')).to be_nil
    end
  end

  describe '.expire_old_codes' do
    let!(:active_invitation) { create(:invitation, status: :active, expires_at: 1.day.ago) }
    let!(:future_invitation) { create(:invitation, status: :active, expires_at: 1.day.from_now) }
    let!(:already_expired) { create(:expired_invitation) }

    it 'marks active invitations with past expiration dates as expired' do
      Invitation.expire_old_codes
      active_invitation.reload
      expect(active_invitation.status).to eq('expired')
    end

    it 'does not affect future active invitations' do
      Invitation.expire_old_codes
      future_invitation.reload
      expect(future_invitation.status).to eq('active')
    end

    it 'does not affect already expired invitations' do
      Invitation.expire_old_codes
      already_expired.reload
      expect(already_expired.status).to eq('expired')
    end
  end
end
