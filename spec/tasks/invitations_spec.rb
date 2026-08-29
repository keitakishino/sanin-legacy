require 'rails_helper'
require 'rake'

RSpec.describe 'invitations:expire', type: :task do
  let(:rake_app) { Rake::Application.new }
  let(:rake_task) do
    rake_app.rake_require('tasks/invitations', [ Rails.root.join('lib').to_s ], [ 'lib/tasks/invitations.rake' ])
    Rake::Task.define_task(:environment)
    Rake::Task['invitations:expire']
  end

  describe 'invitations:expire' do
    after do
      rake_task.reenable
    end

    it 'expires active invitation codes with past expiration dates' do
      active_past_invitation = create(:invitation, status: :active).tap do |invitation|
        invitation.update_column(:expires_at, 1.day.ago)
      end

      rake_task.invoke

      active_past_invitation.reload
      expect(active_past_invitation.status).to eq('expired')
    end

    it 'does not affect active invitations with future expiration dates' do
      active_future_invitation = create(:invitation, status: :active, expires_at: 1.day.from_now)

      rake_task.invoke

      active_future_invitation.reload
      expect(active_future_invitation.status).to eq('active')
    end

    it 'does not affect already used invitations' do
      used_invitation = create(:used_invitation)

      rake_task.invoke

      used_invitation.reload
      expect(used_invitation.status).to eq('used')
    end

    it 'does not affect already expired invitations' do
      expired_invitation = create(:expired_invitation)

      rake_task.invoke

      expired_invitation.reload
      expect(expired_invitation.status).to eq('expired')
    end

    it 'does not affect revoked invitations' do
      revoked_invitation = create(:invitation, status: :revoked)

      rake_task.invoke

      revoked_invitation.reload
      expect(revoked_invitation.status).to eq('revoked')
    end

    it 'updates multiple expired active invitations at once' do
      expired_past_invitation1 = create(:invitation, status: :active).tap do |invitation|
        invitation.update_column(:expires_at, 2.days.ago)
      end
      expired_past_invitation2 = create(:invitation, status: :active).tap do |invitation|
        invitation.update_column(:expires_at, 1.hour.ago)
      end

      rake_task.invoke

      expired_past_invitation1.reload
      expired_past_invitation2.reload
      expect(expired_past_invitation1.status).to eq('expired')
      expect(expired_past_invitation2.status).to eq('expired')
    end

    it 'completes successfully with no expired invitations to update' do
      create(:invitation, status: :active, expires_at: 1.day.from_now)

      expect { rake_task.invoke }.not_to raise_error
    end

    it 'outputs the count of expired invitation codes' do
      create(:invitation, status: :active).tap do |invitation|
        invitation.update_column(:expires_at, 1.day.ago)
      end
      create(:invitation, status: :active).tap do |invitation|
        invitation.update_column(:expires_at, 2.days.ago)
      end

      expect { rake_task.invoke }.to output(/Expired 2 invitation codes/).to_stdout
    end

    it 'outputs zero when no invitations are expired' do
      create(:invitation, status: :active, expires_at: 1.day.from_now)

      expect { rake_task.invoke }.to output(/Expired 0 invitation codes/).to_stdout
    end
  end
end
