require "rails_helper"

describe AuditLog do
  describe ".record!" do
    it "記録を保存する" do
      user = create(:admin_user)
      event = create(:event)

      expect {
        AuditLog.record!(
          user: user,
          action: "event.discard",
          target: event,
          result: :failure,
          details: { reason: "x" },
          request_id: "abc"
        )
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.user_id).to eq(user.id)
      expect(log.action).to eq("event.discard")
      expect(log.target_type).to eq("Event")
      expect(log.target_id).to eq(event.id)
      expect(log.result).to eq("failure")
      expect(log.details).to eq({ "reason" => "x" })
      expect(log.request_id).to eq("abc")
      expect(log.created_at).to be_present
    end

    it "詳細が保存できない値の場合は例外を伝播させない" do
      user = create(:admin_user)
      event = create(:event)

      expect {
        AuditLog.record!(
          user: user,
          action: "event.discard",
          target: event,
          result: :failure,
          details: { bad: "a\u0000b" },
          request_id: "abc"
        )
      }.not_to raise_error

      expect(AuditLog.count).to eq(0)
    end

    it "create! が例外を起こしても通常の値での記録は成功する" do
      user = create(:admin_user)
      event = create(:event)

      allow(AuditLog).to receive(:create!).and_raise(ActiveRecord::StatementInvalid)
      expect {
        AuditLog.record!(
          user: user,
          action: "event.discard",
          target: event,
          result: :failure,
          details: { reason: "x" },
          request_id: "abc"
        )
      }.not_to raise_error

      expect(AuditLog.count).to eq(0)
    end

    it "3か月より古い行が削除される" do
      travel_to(Time.zone.local(2026, 10, 5, 12)) do
        create(:audit_log, created_at: 4.months.ago)
        create(:audit_log, created_at: 2.months.ago)

        AuditLog.record!(
          user: create(:admin_user),
          action: "event.create",
          result: :success
        )

        expect(AuditLog.where(created_at: ...3.months.ago).count).to eq(0)
        expect(AuditLog.where(created_at: 3.months.ago..).count).to eq(2)
      end
    end

    it "同じ日のうちに複数回呼んでも古い行の削除処理は1日1回" do
      travel_to(Time.zone.local(2026, 10, 5, 12)) do
        create(:audit_log, created_at: 4.months.ago)

        # 1回目の記録
        AuditLog.record!(
          user: create(:admin_user),
          action: "event.create",
          result: :success
        )

        # 古い行がすでに削除されているか確認
        expect(AuditLog.where(created_at: ...3.months.ago).count).to eq(0)
        expect(AuditLog.where(created_at: 3.months.ago..).count).to eq(1)

        # 2回目の記録時点で古い行を作る（1回目の削除後）
        create(:audit_log, created_at: 4.months.ago)

        # 2回目の記録
        AuditLog.record!(
          user: create(:admin_user),
          action: "event.discard",
          result: :success
        )

        # この古い行は削除されていない（同じ日なので掃除は1回だけ）
        expect(AuditLog.where(created_at: ...3.months.ago).count).to eq(1)
        expect(AuditLog.where(created_at: 3.months.ago..).count).to eq(2)
      end

      # 翌日に進めて記録
      travel_to(Time.zone.local(2026, 10, 6, 12)) do
        AuditLog.record!(
          user: create(:admin_user),
          action: "event.update",
          result: :success
        )

        # この時点で古い行が削除される
        expect(AuditLog.where(created_at: ...3.months.ago).count).to eq(0)
        expect(AuditLog.where(created_at: 3.months.ago..).count).to eq(3)
      end
    end

    it "to_line が正しい形式で出力される" do
      user = create(:admin_user)
      log = create(:audit_log, user: user, action: "event.discard", result: :failure,
                                details: { reason: "past date" }, request_id: "abc123")

      line = log.to_line
      expect(line).to include("失敗")
      expect(line).to include("user #{user.id} (admin)")
      expect(line).to include("request_id=abc123")
      expect(line).to include("理由: past date")
    end

    it "user_id が nil の場合の出力" do
      log = create(:audit_log, user: nil)
      line = log.to_line
      expect(line).to include("user -")
    end

    it "トランザクション内での記録失敗時に外側のトランザクションが壊れない" do
      user = create(:admin_user)
      event = create(:event)

      expect {
        ActiveRecord::Base.transaction do
          AuditLog.record!(
            user: user,
            action: "event.discard",
            target: event,
            result: :failure,
            details: { bad: "a\u0000b" }
          )

          # 外側のトランザクションは続行できる
          create(:event, title: "after record")
        end
      }.to change(Event, :count).by(1)

      expect(AuditLog.count).to eq(0)
      expect(Event.where(title: "after record").count).to eq(1)
    end
  end
end
