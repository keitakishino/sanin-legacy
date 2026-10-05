module ErrorNotification
  class Throttle
    WINDOW = 5.minutes

    def initialize
      @mutex = Mutex.new
      @records = {}
    end

    def check(fingerprint, now: Time.current)
      @mutex.synchronize do
        cleanup(now)
        record = @records[fingerprint]

        if record.nil? || (now - record[:notified_at]) >= WINDOW
          suppressed = record&.dig(:suppressed) || 0
          @records[fingerprint] = { notified_at: now, suppressed: 0 }
          [ true, suppressed ]
        else
          record[:suppressed] += 1
          [ false, nil ]
        end
      end
    end

    private

    def cleanup(now)
      cutoff_time = now - (WINDOW * 2)
      @records.reject! { |_k, v| v[:notified_at] < cutoff_time && v[:suppressed].zero? }

      return if @records.size <= 1000

      @records.delete(@records.min_by { |_k, v| v[:notified_at] }.first)
    end
  end
end
