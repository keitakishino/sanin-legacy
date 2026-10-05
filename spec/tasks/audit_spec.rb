require 'rails_helper'
require 'rake'

describe 'audit tasks', type: :task do
  let(:rake_app) { Rake::Application.new }

  def create_rake_task(task_name)
    rake_app.rake_require('tasks/audit', [ Rails.root.join('lib').to_s ], [ 'lib/tasks/audit.rake' ])
    Rake::Task.define_task(:environment)
    Rake::Task[task_name]
  end

  describe 'audit:show' do
    let(:rake_task) { create_rake_task('audit:show') }

    after do
      rake_task.reenable
    end

    it 'displays audit logs for a specific target' do
      user = create(:admin_user)
      create(:audit_log, target_type: 'Event', target_id: 17, action: 'event.create', user: user)
      create(:audit_log, target_type: 'Event', target_id: 17, action: 'event.update', user: user)
      create(:audit_log, target_type: 'Event', target_id: 18, action: 'event.create', user: user)
      create(:audit_log, target_type: 'Trade', target_id: 17, action: 'trade.create', user: user)

      output = capture_stdout { rake_task.invoke('Event', '17') }
      lines = output.strip.split("\n")

      expect(lines.size).to eq(2)
      expect(lines[0]).to include('Event#17')
      expect(lines[0]).to include('event.create')
      expect(lines[1]).to include('Event#17')
      expect(lines[1]).to include('event.update')
      expect(output).not_to include('Event#18')
      expect(output).not_to include('Trade')
    end

    it 'displays "no results" message when no logs found' do
      output = capture_stdout { rake_task.invoke('Event', '99') }
      expect(output).to include('該当する監査ログはありません')
    end

    it 'exits with error when arguments are missing' do
      expect { rake_task.invoke }.to raise_error(SystemExit) do |e|
        expect(e.status).to eq(1)
      end
    end
  end

  describe 'audit:recent' do
    let(:rake_task) { create_rake_task('audit:recent') }

    after do
      rake_task.reenable
    end

    it 'displays audit logs from the last N hours' do
      user = create(:admin_user)
      travel_to(Time.zone.local(2026, 10, 5, 12)) do
        create(:audit_log, action: 'event.update', user: user, created_at: 23.hours.ago)
        create(:audit_log, action: 'event.create', user: user, created_at: 25.hours.ago)

        output = capture_stdout { rake_task.invoke('24') }

        expect(output).to include('event.update')
        expect(output).not_to include('event.create')
      end
    end

    it 'uses 24 hours as default when hours argument is not provided' do
      user = create(:admin_user)
      travel_to(Time.zone.local(2026, 10, 5, 12)) do
        create(:audit_log, action: 'event.update', user: user, created_at: 12.hours.ago)
        create(:audit_log, action: 'event.create', user: user, created_at: 30.hours.ago)

        output = capture_stdout { rake_task.invoke }

        expect(output).to include('event.update')
        expect(output).not_to include('event.create')
      end
    end

    it 'displays "no results" message when no logs found' do
      output = capture_stdout { rake_task.invoke('1') }
      expect(output).to include('該当する監査ログはありません')
    end
  end

  describe 'audit:failures' do
    let(:rake_task) { create_rake_task('audit:failures') }

    after do
      rake_task.reenable
    end

    it 'displays only failed audit logs' do
      user = create(:admin_user)
      create(:audit_log, action: 'trade.discard', result: :failure, user: user)
      create(:audit_log, action: 'event.update', result: :success, user: user)

      output = capture_stdout { rake_task.invoke }

      expect(output).to include('trade.discard')
      expect(output).to include('失敗')
      expect(output).not_to include('event.update')
      expect(output).not_to include('成功')
    end

    it 'displays "no results" message when no failed logs found' do
      user = create(:admin_user)
      create(:audit_log, action: 'event.create', result: :success, user: user)

      output = capture_stdout { rake_task.invoke }

      expect(output).to include('該当する監査ログはありません')
    end
  end

  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end
end
