require "rails_helper"

RSpec.describe GuestParticipantUnlinker do
  let(:target_user) { create(:user, username: "target_user") }
  let(:admin) { create(:user) }
  let(:event_a) { create(:event, :proxy_order, title: "Event A") }
  let(:event_b) { create(:event, :proxy_order, title: "Event B") }
  let(:event_c) { create(:event, :proxy_order, title: "Event C") }
  let(:order_a) { create(:proxy_order, event: event_a) }
  let(:order_b) { create(:proxy_order, event: event_b) }
  let(:order_c) { create(:proxy_order, event: event_c) }

  describe "#call" do
    context "with linked participants across multiple orders" do
      it "restores all matching linked participants to guest entries" do
        # Create linked participants with different text representations of the same name
        linked_a = create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: "Yamada")
        linked_b = create(:proxy_order_participant, proxy_order: order_b, user: target_user, linked_from_guest_name: "yamada")
        linked_c = create(:proxy_order_participant, proxy_order: order_c, user: target_user, linked_from_guest_name: "ＹＡＭＡＤＡ")

        # Create a different linked name in a different order that should not be affected
        order_d = create(:proxy_order, event: create(:event, :proxy_order, title: "Event D"))
        other_linked = create(:proxy_order_participant, proxy_order: order_d, user: target_user, linked_from_guest_name: "Suzuki")

        unlinker = GuestParticipantUnlinker.new(user: target_user, name_key: "yamada", actor: admin)
        result = unlinker.call

        expect(result.success?).to be true
        expect(result.count).to eq(3)

        # Verify all three linked participants are restored
        ProxyOrderParticipant.with_discarded.where(id: [ linked_a.id, linked_b.id, linked_c.id ]).each do |p|
          p.reload
          expect(p.user_id).to be_nil
          expect(p.linked_from_guest_name).to be_nil
        end

        # Verify guest_name is restored with original value
        expect(linked_a.reload.guest_name).to eq("Yamada")
        expect(linked_b.reload.guest_name).to eq("yamada")
        expect(linked_c.reload.guest_name).to eq("ＹＡＭＡＤＡ")

        # Verify other linked participant is unchanged
        expect(other_linked.reload.user_id).to eq(target_user.id)
        expect(other_linked.reload.linked_from_guest_name).to eq("Suzuki")
      end
    end

    context "when no matching linked participants exist" do
      it "returns failure with unlink_not_found message" do
        unlinker = GuestParticipantUnlinker.new(user: target_user, name_key: "yamada", actor: admin)
        result = unlinker.call

        expect(result.success?).to be false
        expect(result.errors).to include(I18n.t("admin.users.guest_link.unlink_not_found"))
      end
    end

    context "when there is a guest participant with the same normalized name in target order" do
      it "detects collision and rolls back" do
        # Create linked participant to unlink
        linked = create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: "Yamada")
        # Create conflicting guest participant in same order
        create(:proxy_order_participant, :guest, proxy_order: order_a, guest_name: "yamada")

        unlinker = GuestParticipantUnlinker.new(user: target_user, name_key: "yamada", actor: admin)
        result = unlinker.call

        expect(result.success?).to be false
        expect(result.errors.first).to include(I18n.t("admin.users.guest_link.unlink_conflict_name", order: "Event A", name: "Yamada"))

        # Verify rollback
        expect(linked.reload.user_id).to eq(target_user.id)
        expect(linked.reload.linked_from_guest_name).to eq("Yamada")
      end

      it "detects discarded guest participant collision" do
        linked = create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: "Yamada")
        discarded_guest = create(:proxy_order_participant, :guest, proxy_order: order_a, guest_name: "yamada")
        discarded_guest.update_column(:discarded_at, Time.current)

        unlinker = GuestParticipantUnlinker.new(user: target_user, name_key: "yamada", actor: admin)
        result = unlinker.call

        expect(result.success?).to be false
        expect(result.errors.first).to include(I18n.t("admin.users.guest_link.unlink_conflict_name_discarded", order: "Event A", name: "Yamada"))

        # Verify rollback
        expect(linked.reload.user_id).to eq(target_user.id)
      end
    end

    context "when a user with the same normalized username exists" do
      it "detects username collision and rolls back" do
        linked = create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: "Yamada")
        create(:user, username: "YAMADA")

        unlinker = GuestParticipantUnlinker.new(user: target_user, name_key: "yamada", actor: admin)
        result = unlinker.call

        expect(result.success?).to be false
        expect(result.errors).to include(I18n.t("admin.users.guest_link.unlink_conflict_username", name: "Yamada"))

        # Verify rollback
        expect(linked.reload.user_id).to eq(target_user.id)
        expect(linked.reload.linked_from_guest_name).to eq("Yamada")
      end
    end

    context "with linked and non-linked participants" do
      it "only unlinks participants with linked_from_guest_name" do
        # Create a participant without linked_from_guest_name (registered user)
        registered = create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: nil)
        # Create linked participant
        linked = create(:proxy_order_participant, proxy_order: order_b, user: target_user, linked_from_guest_name: "Yamada")

        unlinker = GuestParticipantUnlinker.new(user: target_user, name_key: "yamada", actor: admin)
        result = unlinker.call

        expect(result.success?).to be true
        expect(result.count).to eq(1)

        # Verify registered participant is unchanged
        expect(registered.reload.user_id).to eq(target_user.id)
        expect(registered.reload.linked_from_guest_name).to be_nil

        # Verify linked participant is unlinked
        expect(linked.reload.user_id).to be_nil
        expect(linked.reload.linked_from_guest_name).to be_nil
      end

      it "returns not_found when only non-linked participants exist" do
        create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: nil)

        unlinker = GuestParticipantUnlinker.new(user: target_user, name_key: "yamada", actor: admin)
        result = unlinker.call

        expect(result.success?).to be false
        expect(result.errors).to include(I18n.t("admin.users.guest_link.unlink_not_found"))
      end
    end

    context "when participant has allocations" do
      it "preserves allocations and handed_over_at" do
        item = create(:proxy_order_item, proxy_order: order_a)
        participant = create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: "Yamada", handed_over_at: Time.current)
        allocation = create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 2, lost_quantity: 1)

        allocation_before = allocation.reload
        participant_before = participant.reload
        original_handed_over_at = participant_before.handed_over_at

        unlinker = GuestParticipantUnlinker.new(user: target_user, name_key: "yamada", actor: admin)
        result = unlinker.call

        allocation_after = allocation.reload
        participant_after = participant.reload

        expect(allocation_after.quantity).to eq(2)
        expect(allocation_after.lost_quantity).to eq(1)
        expect(participant_after.handed_over_at).to eq(original_handed_over_at)
      end
    end

    context "audit logging on success" do
      before do
        create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: "Yamada")
        create(:proxy_order_participant, proxy_order: order_b, user: target_user, linked_from_guest_name: "yamada")
      end

      it "records audit log with success details" do
        unlinker = GuestParticipantUnlinker.new(user: target_user, name_key: "yamada", actor: admin, request_id: "req-123")
        result = unlinker.call

        audit_log = AuditLog.find_by(action: "user.unlink_guest_participants", target_type: "User", target_id: target_user.id)
        expect(audit_log).to be_present
        expect(audit_log.result).to eq("success")
        expect(audit_log.user_id).to eq(admin.id)
        expect(audit_log.request_id).to eq("req-123")
        expect(audit_log.details["guest_name"]).to match_array([ "Yamada", "yamada" ])
        expect(audit_log.details["normalized_name"]).to eq("yamada")
        expect(audit_log.details["count"]).to eq(2)
        expect(audit_log.details["participant_ids"].size).to eq(2)
        expect(audit_log.details["proxy_order_ids"]).to match_array([ order_a.id, order_b.id ])
      end
    end

    context "audit logging on failure" do
      before do
        create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: "Yamada")
        create(:proxy_order_participant, :guest, proxy_order: order_a, guest_name: "yamada")
      end

      it "records audit log with failure reason" do
        unlinker = GuestParticipantUnlinker.new(user: target_user, name_key: "yamada", actor: admin, request_id: "req-456")
        result = unlinker.call

        audit_log = AuditLog.find_by(action: "user.unlink_guest_participants", target_type: "User", target_id: target_user.id)
        expect(audit_log).to be_present
        expect(audit_log.result).to eq("failure")
        expect(audit_log.details["reason"]).to include("Event A")
        expect(audit_log.details["normalized_name"]).to eq("yamada")
      end
    end

    context "with different proxy order statuses" do
      before do
        order_a.update_column(:status, "ordered")
        order_b.update_column(:status, "arrived")
        order_c.update_column(:status, "completed")

        create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: "Yamada")
        create(:proxy_order_participant, proxy_order: order_b, user: target_user, linked_from_guest_name: "yamada")
        create(:proxy_order_participant, proxy_order: order_c, user: target_user, linked_from_guest_name: "YAMADA")
      end

      it "unlinks participants across different statuses" do
        unlinker = GuestParticipantUnlinker.new(user: target_user, name_key: "yamada", actor: admin)
        result = unlinker.call

        expect(result.success?).to be true
        expect(result.count).to eq(3)

        [ order_a, order_b, order_c ].each do |order|
          unlinked = ProxyOrderParticipant.find_by(proxy_order_id: order.id, user_id: nil, linked_from_guest_name: nil)
          expect(unlinked).to be_present
        end
      end
    end

    context "with discarded participants and orders" do
      it "includes discarded participants in unlinking" do
        linked = create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: "Yamada")
        linked.update_column(:discarded_at, Time.current)

        unlinker = GuestParticipantUnlinker.new(user: target_user, name_key: "yamada", actor: admin)
        result = unlinker.call

        expect(result.success?).to be true
        expect(result.count).to eq(1)

        linked.reload
        expect(linked.user_id).to be_nil
        expect(linked.linked_from_guest_name).to be_nil
      end
    end
  end

  describe ".linked_groups" do
    context "with linked participants across multiple orders" do
      it "groups by normalized name and includes all variations" do
        # Create linked participants with different text representations
        create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: "Yamada")
        create(:proxy_order_participant, proxy_order: order_b, user: target_user, linked_from_guest_name: "yamada")
        discarded = create(:proxy_order_participant, proxy_order: order_c, user: target_user, linked_from_guest_name: "YAMADA")
        discarded.update_column(:discarded_at, Time.current)

        # Create a different linked name in a different order
        order_d = create(:proxy_order, event: create(:event, :proxy_order, title: "Event D"))
        create(:proxy_order_participant, proxy_order: order_d, user: target_user, linked_from_guest_name: "Suzuki")

        groups = GuestParticipantUnlinker.linked_groups(target_user)

        expect(groups.size).to eq(2)

        # Find yamada group
        yamada_group = groups.find { |g| g.normalized_name == "yamada" }
        expect(yamada_group).to be_present
        expect(yamada_group.guest_names).to match_array([ "Yamada", "yamada", "YAMADA" ])
        expect(yamada_group.count).to eq(3)
        expect(yamada_group.order_titles).to match_array([ "Event A", "Event B", "Event C" ])

        # Find suzuki group
        suzuki_group = groups.find { |g| g.normalized_name == "suzuki" }
        expect(suzuki_group).to be_present
        expect(suzuki_group.guest_names).to match_array([ "Suzuki" ])
        expect(suzuki_group.count).to eq(1)
        expect(suzuki_group.order_titles).to match_array([ "Event D" ])
      end
    end

    context "when user has no linked participants" do
      it "returns empty array" do
        groups = GuestParticipantUnlinker.linked_groups(target_user)
        expect(groups).to eq([])
      end
    end

    context "with non-linked and linked participants" do
      it "excludes non-linked participants" do
        # Create non-linked participant
        create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: nil)
        # Create linked participant
        create(:proxy_order_participant, proxy_order: order_b, user: target_user, linked_from_guest_name: "Yamada")

        groups = GuestParticipantUnlinker.linked_groups(target_user)

        expect(groups.size).to eq(1)
        expect(groups.first.guest_names).to match_array([ "Yamada" ])
      end
    end

    context "with another user's linked participants" do
      it "excludes participants from other users" do
        other_user = create(:user, username: "other_user")
        create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: "Yamada")
        create(:proxy_order_participant, proxy_order: order_b, user: other_user, linked_from_guest_name: "Yamada")

        groups = GuestParticipantUnlinker.linked_groups(target_user)

        expect(groups.size).to eq(1)
        expect(groups.first.count).to eq(1)
      end
    end

    context "ordering" do
      it "returns groups sorted by normalized name" do
        create(:proxy_order_participant, proxy_order: order_a, user: target_user, linked_from_guest_name: "Yamada")
        create(:proxy_order_participant, proxy_order: order_b, user: target_user, linked_from_guest_name: "Alice")
        create(:proxy_order_participant, proxy_order: order_c, user: target_user, linked_from_guest_name: "Zoe")

        groups = GuestParticipantUnlinker.linked_groups(target_user)

        expect(groups.map(&:normalized_name)).to eq([ "alice", "yamada", "zoe" ])
      end
    end
  end
end
