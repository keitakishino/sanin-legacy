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

    describe "#to_line の status_code" do
      it "status_code がある場合は末尾に付加される" do
        log = create(:audit_log, result: :success, status_code: 302)
        line = log.to_line
        expect(line).to include("成功(302)")
      end

      it "status_code が 422 の失敗行は失敗(422) を含む" do
        log = create(:audit_log, result: :failure, status_code: 422)
        line = log.to_line
        expect(line).to include("失敗(422)")
      end

      it "status_code が nil の場合は付加されない" do
        log = create(:audit_log, result: :success, status_code: nil)
        line = log.to_line
        expect(line).to include("成功")
        expect(line).not_to match(/成功\(\d/)
      end

      it "record! で status_code を指定すると保存される" do
        user = create(:admin_user)
        event = create(:event)

        AuditLog.record!(
          user: user,
          action: "event.create",
          target: event,
          result: :success,
          status_code: 302
        )

        log = AuditLog.where(action: "event.create").last
        expect(log.status_code).to eq(302)
      end

      it "record! で user_id を指定すると保存される" do
        AuditLog.record!(
          user_id: 42,
          action: "system.error",
          result: :failure,
          status_code: 500
        )

        log = AuditLog.where(action: "system.error").last
        expect(log.user_id).to eq(42)
      end
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

  describe ".exception_details" do
    it "formats message with line limit of 300 characters per line" do
      # 各行 300 文字以上で複数行のメッセージ
      msg = ("a" * 350) + "\n" + ("b" * 350)
      exception = RuntimeError.new(msg)

      details = AuditLog.exception_details(exception, path: "/test", http_method: "GET")

      # 各行が 300 文字で切られるため、1行目は "a" * 300 + 省略記号
      lines = details["message"].split("\n")
      expect(lines[0].length).to be <= AuditLog::EXCEPTION_MESSAGE_LINE_LIMIT + AuditLog::TRUNCATION_MARK.length
    end

    it "limits total message length to 1000 characters" do
      # 複数行で1000文字を超えるメッセージ
      # 各行が400文字だと300文字に切られる（EXCEPTION_MESSAGE_LINE_LIMIT）
      # 4行×300文字 + 3つの改行 = 1203文字なので、1000文字で truncation される
      msg = ("x" * 400 + "\n") * 4
      exception = RuntimeError.new(msg)

      details = AuditLog.exception_details(exception, path: "/test", http_method: "GET")

      expect(details["message"].length).to be <= AuditLog::EXCEPTION_MESSAGE_LIMIT + AuditLog::TRUNCATION_MARK.length
      expect(details["message"]).to end_with(AuditLog::TRUNCATION_MARK)
    end

    it "limits backtrace to 200 lines" do
      exception = RuntimeError.new("boom")
      exception.set_backtrace(Array.new(500) { |i| "app/x.rb:#{i}" })

      details = AuditLog.exception_details(exception, path: "/test", http_method: "GET")

      backtrace_lines = details["backtrace"].split("\n")
      # 200行 + TRUNCATION_MARK
      expect(backtrace_lines.length).to be <= AuditLog::BACKTRACE_LINES_LIMIT + 1
      expect(details["backtrace"]).to include(AuditLog::TRUNCATION_MARK)
    end

    it "limits total backtrace characters to 30000" do
      exception = RuntimeError.new("boom")
      # 200行 x 100文字 = 20000文字のバックトレース
      exception.set_backtrace(Array.new(200) { |i| "a" * 100 })

      # cause を追加
      cause = RuntimeError.new("cause")
      cause.set_backtrace(Array.new(200) { |i| "b" * 100 })
      allow(exception).to receive(:cause).and_return(cause)

      details = AuditLog.exception_details(exception, path: "/test", http_method: "GET")

      total_backtrace_chars = details["backtrace"].bytesize
      details["causes"].each { |c| total_backtrace_chars += c["backtrace"].bytesize }

      # 30000文字以内
      expect(total_backtrace_chars).to be <= AuditLog::BACKTRACE_CHARS_LIMIT + (AuditLog::TRUNCATION_MARK.bytesize * 2)
    end

    it "follows cause chain up to 5 levels" do
      e1 = RuntimeError.new("e1")
      e2 = RuntimeError.new("e2")
      e3 = RuntimeError.new("e3")
      e4 = RuntimeError.new("e4")
      e5 = RuntimeError.new("e5")
      e6 = RuntimeError.new("e6")
      e7 = RuntimeError.new("e7")

      allow(e1).to receive(:cause).and_return(e2)
      allow(e2).to receive(:cause).and_return(e3)
      allow(e3).to receive(:cause).and_return(e4)
      allow(e4).to receive(:cause).and_return(e5)
      allow(e5).to receive(:cause).and_return(e6)
      allow(e6).to receive(:cause).and_return(e7)

      details = AuditLog.exception_details(e1, path: "/test", http_method: "GET")

      expect(details["causes"].length).to eq(5)
      expect(details["causes"].map { |c| c["message"] }).to eq([ "e2", "e3", "e4", "e5", "e6" ])
    end

    it "detects circular cause references and stops" do
      e1 = RuntimeError.new("e1")
      e2 = RuntimeError.new("e2")
      e3 = RuntimeError.new("e3")

      # e1 -> e2 -> e3 -> e2（循環）
      allow(e1).to receive(:cause).and_return(e2)
      allow(e2).to receive(:cause).and_return(e3)
      allow(e3).to receive(:cause).and_return(e2)

      details = AuditLog.exception_details(e1, path: "/test", http_method: "GET")

      # e2, e3, e2（重複で止まる）→ 最終的に 2 つ
      expect(details["causes"].length).to eq(2)
      expect(details["causes"][0]["message"]).to eq("e2")
      expect(details["causes"][1]["message"]).to eq("e3")
    end

    it "handles nil exception without raising" do
      details = AuditLog.exception_details(nil, path: "/test", http_method: "GET")

      expect(details["reason"]).to eq("unknown error")
      expect(details["path"]).to eq("/test")
      expect(details["http_method"]).to eq("GET")
    end

    it "includes reason with class and first message line" do
      exception = RuntimeError.new("boom\nsecond line")

      details = AuditLog.exception_details(exception, path: "/test", http_method: "GET")

      expect(details["reason"]).to eq("RuntimeError: boom")
    end

    it "preserves path and http_method parameters" do
      exception = RuntimeError.new("boom")

      details = AuditLog.exception_details(exception, path: "/admin/events?token=secret", http_method: "POST")

      expect(details["path"]).to eq("/admin/events?token=secret")
      expect(details["http_method"]).to eq("POST")
    end
  end

  describe "#to_line with backtrace" do
    it "outputs only reason for details with backtrace" do
      log = create(:audit_log, details: {
        "reason" => "RuntimeError: boom",
        "error_class" => "RuntimeError",
        "backtrace" => "app/foo.rb:1\napp/bar.rb:2",
        "causes" => []
      })

      line = log.to_line
      expect(line).to include("理由: RuntimeError: boom")
      expect(line).not_to include("app/foo.rb")
      expect(line).not_to include("details=")
    end

    it "does not output backtrace when error_class is reason" do
      log = create(:audit_log, details: {
        "error_class" => "RuntimeError",
        "backtrace" => "app/foo.rb:1"
      })

      line = log.to_line
      expect(line).not_to include("app/foo.rb")
      expect(line).not_to include("details=")
      expect(line).to include("理由: RuntimeError")
    end

    it "outputs details as JSON when no backtrace and no reason" do
      log = create(:audit_log, details: { "key" => "value" })

      line = log.to_line
      expect(line).to include("details={")
    end
  end
end
