class GuestParticipantLinker
  Candidate = Data.define(:normalized_name, :guest_names, :proxy_orders, :count, :conflicts) do
    def selectable?
      conflicts.empty?
    end
  end

  Result = Data.define(:success, :normalized_name, :guest_names, :participant_ids, :proxy_order_ids, :count, :errors) do
    def success?
      success
    end
  end

  def initialize(user:, guest_name_key: nil, actor: nil, request_id: nil)
    @user = user
    @guest_name_key = guest_name_key.present? ? self.class.normalize(guest_name_key) : nil
    @actor = actor
    @request_id = request_id
  end

  def candidates(q = nil)
    normalized_q = q.present? ? self.class.normalize(q) : nil

    participants = ProxyOrderParticipant.with_discarded
      .where(user_id: nil)
      .where.not(guest_name: nil)
      .select(:id, :proxy_order_id, :guest_name, :discarded_at)

    orders = ProxyOrder.with_discarded
      .where(id: participants.map(&:proxy_order_id).uniq)
      .select(:id, :event_id, :discarded_at)

    events_map = Event.unscoped
      .where(id: orders.map(&:event_id).uniq)
      .pluck(:id, :title)
      .to_h

    candidates_hash = {}

    participants.each do |p|
      normalized = self.class.normalize(p.guest_name)
      candidates_hash[normalized] ||= { guest_names: Set.new, valid_proxy_orders: Set.new, all_proxy_orders: Set.new }
      candidates_hash[normalized][:guest_names] << p.guest_name
      candidates_hash[normalized][:all_proxy_orders] << p.proxy_order_id

      order = orders.find { |o| o.id == p.proxy_order_id }
      if order && p.discarded_at.nil? && order.discarded_at.nil?
        candidates_hash[normalized][:valid_proxy_orders] << p.proxy_order_id
      end
    end

    candidates_hash.delete_if { |_, v| v[:valid_proxy_orders].empty? }

    user_participants = ProxyOrderParticipant.with_discarded
      .where(user_id: @user.id)
      .to_a

    user_participant_order_ids = user_participants.map(&:proxy_order_id).uniq

    result = candidates_hash.map do |normalized_name, data|
      conflicting_order_ids = data[:all_proxy_orders].select { |oid| user_participant_order_ids.include?(oid) }.uniq

      conflicts = conflicting_order_ids.map do |order_id|
        user_parts_for_order = user_participants.select { |p| p.proxy_order_id == order_id }
        order = orders.find { |o| o.id == order_id }
        event_title = events_map[order&.event_id] || "Unknown"

        if user_parts_for_order.any? { |p| p.discarded_at.nil? }
          I18n.t("admin.users.guest_link.conflict", order: event_title, username: @user.username)
        else
          I18n.t("admin.users.guest_link.conflict_discarded", order: event_title, username: @user.username)
        end
      end

      valid_proxy_orders = orders.select { |o| data[:valid_proxy_orders].include?(o.id) }
        .sort_by do |o|
          event = Event.unscoped.find_by(id: o.event_id)
          event_timestamp = event&.event_date&.to_time&.to_i || 0
          [ -event_timestamp, -o.id ]
        end

      Candidate.new(
        normalized_name:,
        guest_names: data[:guest_names].to_a,
        proxy_orders: valid_proxy_orders,
        count: data[:valid_proxy_orders].size,
        conflicts:
      )
    end

    if normalized_q.present?
      result.select! { |c| c.normalized_name.include?(normalized_q) }
    end

    result.sort_by(&:normalized_name)
  end

  def call
    normalized_key = @guest_name_key

    guest_names = []
    participant_ids = []
    proxy_order_ids = []
    error_messages = []
    collision_detected = false

    ActiveRecord::Base.transaction do
      participants = ProxyOrderParticipant.with_discarded
        .where(user_id: nil)
        .where.not(guest_name: nil)
        .lock
        .to_a

      target_participants = participants.select do |p|
        self.class.normalize(p.guest_name) == normalized_key
      end

      if target_participants.empty?
        AuditLog.record!(
          user: @actor,
          action: "user.link_guest_participants",
          target: @user,
          result: :failure,
          request_id: @request_id,
          details: { reason: I18n.t("admin.users.guest_link.not_found"), normalized_name: normalized_key }
        )

        return Result.new(
          success: false,
          normalized_name: normalized_key,
          guest_names: [],
          participant_ids: [],
          proxy_order_ids: [],
          count: 0,
          errors: [ I18n.t("admin.users.guest_link.not_found") ]
        )
      end

      target_order_ids = target_participants.map(&:proxy_order_id).uniq
      user_participants = ProxyOrderParticipant.with_discarded
        .where(user_id: @user.id)
        .lock
        .to_a

      user_participant_order_ids = user_participants.map(&:proxy_order_id).uniq
      conflicting_order_ids = target_order_ids & user_participant_order_ids

      if conflicting_order_ids.present?
        orders = ProxyOrder.with_discarded.where(id: conflicting_order_ids)
        events_map = Event.unscoped.where(id: orders.map(&:event_id).uniq).pluck(:id, :title).to_h

        error_messages = conflicting_order_ids.map do |order_id|
          user_parts = user_participants.select { |p| p.proxy_order_id == order_id }
          order = orders.find { |o| o.id == order_id }
          event_title = events_map[order&.event_id] || "Unknown"

          if user_parts.any? { |p| p.discarded_at.nil? }
            I18n.t("admin.users.guest_link.conflict", order: event_title, username: @user.username)
          else
            I18n.t("admin.users.guest_link.conflict_discarded", order: event_title, username: @user.username)
          end
        end

        collision_detected = true
        raise ActiveRecord::Rollback
      end

      target_participants.each do |p|
        original_guest_name = p.guest_name
        guest_names << original_guest_name
        participant_ids << p.id
        proxy_order_ids << p.proxy_order_id

        p.update!(guest_name: nil, user_id: @user.id, linked_from_guest_name: original_guest_name)
      end
    end

    if collision_detected
      AuditLog.record!(
        user: @actor,
        action: "user.link_guest_participants",
        target: @user,
        result: :failure,
        request_id: @request_id,
        details: { reason: error_messages.join(", "), normalized_name: normalized_key }
      )

      return Result.new(
        success: false,
        normalized_name: normalized_key,
        guest_names: [],
        participant_ids: [],
        proxy_order_ids: [],
        count: 0,
        errors: error_messages
      )
    end

    AuditLog.record!(
      user: @actor,
      action: "user.link_guest_participants",
      target: @user,
      result: :success,
      request_id: @request_id,
      details: {
        guest_name: guest_names,
        normalized_name: normalized_key,
        participant_ids:,
        proxy_order_ids: proxy_order_ids.uniq,
        count: participant_ids.size
      }
    )

    Result.new(
      success: true,
      normalized_name: normalized_key,
      guest_names:,
      participant_ids:,
      proxy_order_ids: proxy_order_ids.uniq,
      count: participant_ids.size,
      errors: []
    )
  end

  class << self
    def normalize(name)
      ProxyOrderParticipant.normalize_name(name)
    end
  end
end
