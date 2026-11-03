class GuestParticipantUnlinker
  Result = Data.define(:success, :normalized_name, :guest_names, :participant_ids, :proxy_order_ids, :count, :errors) do
    def success?
      success
    end
  end

  LinkedGroup = Data.define(:normalized_name, :guest_names, :order_titles, :count)

  def initialize(user:, name_key:, actor: nil, request_id: nil)
    @user = user
    @name_key = name_key.present? ? self.class.normalize(name_key) : nil
    @actor = actor
    @request_id = request_id
  end

  def call
    normalized_key = @name_key

    guest_names = []
    participant_ids = []
    proxy_order_ids = []
    error_messages = []
    collision_detected = false

    ActiveRecord::Base.transaction do
      # Get all linked participants for the user (including discarded)
      participants = ProxyOrderParticipant.with_discarded
        .where(user_id: @user.id)
        .where.not(linked_from_guest_name: nil)
        .lock
        .to_a

      # Filter to those matching the normalized name
      target_participants = participants.select do |p|
        self.class.normalize(p.linked_from_guest_name) == normalized_key
      end

      if target_participants.empty?
        AuditLog.record!(
          user: @actor,
          action: "user.unlink_guest_participants",
          target: @user,
          result: :failure,
          request_id: @request_id,
          details: { reason: I18n.t("admin.users.guest_link.unlink_not_found"), normalized_name: normalized_key }
        )

        return Result.new(
          success: false,
          normalized_name: normalized_key,
          guest_names: [],
          participant_ids: [],
          proxy_order_ids: [],
          count: 0,
          errors: [ I18n.t("admin.users.guest_link.unlink_not_found") ]
        )
      end

      target_order_ids = target_participants.map(&:proxy_order_id).uniq

      # Name conflict check: look for guest_name entries with same normalized name in target orders
      guest_participants = ProxyOrderParticipant.with_discarded
        .where(proxy_order_id: target_order_ids, user_id: nil)
        .where.not(guest_name: nil)
        .lock
        .to_a

      orders = ProxyOrder.with_discarded.where(id: target_order_ids)
      events_map = Event.unscoped.where(id: orders.map(&:event_id).uniq).pluck(:id, :title).to_h

      guest_participants.each do |p|
        if self.class.normalize(p.guest_name) == normalized_key
          order = orders.find { |o| o.id == p.proxy_order_id }
          event_title = events_map[order&.event_id] || "Unknown"
          target_name = target_participants.find { |tp| tp.proxy_order_id == p.proxy_order_id }&.linked_from_guest_name || normalized_key

          if p.discarded_at.nil?
            error_messages << I18n.t("admin.users.guest_link.unlink_conflict_name", order: event_title, name: target_name)
          else
            error_messages << I18n.t("admin.users.guest_link.unlink_conflict_name_discarded", order: event_title, name: target_name)
          end
        end
      end

      # Username conflict check
      user_usernames = User.pluck(:username).map { |u| self.class.normalize(u) }
      if user_usernames.include?(normalized_key)
        target_name = target_participants.first.linked_from_guest_name
        error_messages << I18n.t("admin.users.guest_link.unlink_conflict_username", name: target_name)
      end

      if error_messages.present?
        collision_detected = true
        raise ActiveRecord::Rollback
      end

      # Perform updates
      target_participants.each do |p|
        original_linked_name = p.linked_from_guest_name
        guest_names << original_linked_name
        participant_ids << p.id
        proxy_order_ids << p.proxy_order_id

        begin
          p.update!(guest_name: original_linked_name, user_id: nil, linked_from_guest_name: nil)
        rescue ActiveRecord::RecordInvalid => e
          error_messages.concat(e.record.errors.full_messages)
          collision_detected = true
          raise ActiveRecord::Rollback
        end
      end
    end

    if collision_detected
      AuditLog.record!(
        user: @actor,
        action: "user.unlink_guest_participants",
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
      action: "user.unlink_guest_participants",
      target: @user,
      result: :success,
      request_id: @request_id,
      details: {
        guest_name: guest_names.uniq,
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

    def linked_groups(user)
      participants = ProxyOrderParticipant.with_discarded
        .where(user_id: user.id)
        .where.not(linked_from_guest_name: nil)
        .order(:proxy_order_id, :id)
        .to_a

      groups_by_normalized = participants.group_by { |p| normalize(p.linked_from_guest_name) }

      proxy_order_ids = participants.map(&:proxy_order_id).uniq
      orders_map = ProxyOrder.with_discarded.where(id: proxy_order_ids).index_by(&:id)
      event_ids = orders_map.values.map(&:event_id).uniq
      events_map = Event.unscoped.where(id: event_ids).pluck(:id, :title).to_h

      groups_by_normalized.map do |normalized_name, group_participants|
        guest_names = group_participants.map(&:linked_from_guest_name).uniq
        count = group_participants.size
        order_ids = group_participants.map(&:proxy_order_id).uniq.sort
        order_titles = order_ids.map { |order_id| events_map[orders_map[order_id]&.event_id] }.compact

        LinkedGroup.new(
          normalized_name:,
          guest_names:,
          order_titles:,
          count:
        )
      end.sort_by(&:normalized_name)
    end
  end
end
