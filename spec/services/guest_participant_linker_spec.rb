require "rails_helper"

RSpec.describe GuestParticipantLinker do
  let(:target_user) { create(:user, username: "target_user") }
  let(:admin) { create(:user) }
  let(:event_a) { create(:event, :proxy_order, title: "Event A") }
  let(:event_b) { create(:event, :proxy_order, title: "Event B") }
  let(:order_a) { create(:proxy_order, event: event_a) }
  let(:order_b) { create(:proxy_order, event: event_b) }

  describe "#candidates" do
    context "with guest participants" do
      before do
        create(:proxy_order_participant, :guest, proxy_order: order_a, guest_name: "Yamada")
      end

      it "groups by normalized name" do
        linker = GuestParticipantLinker.new(user: target_user)
        candidates = linker.candidates
        yamada_candidate = candidates.find { |c| c.normalized_name == "yamada" }
        expect(yamada_candidate).to be_present
        expect(yamada_candidate.count).to eq(1)
        expect(yamada_candidate.guest_names).to contain_exactly("Yamada")
      end

      it "filters candidates by partial normalized match" do
        linker = GuestParticipantLinker.new(user: target_user)
        candidates = linker.candidates("yam")
        expect(candidates.size).to eq(1)
        expect(candidates.first.normalized_name).to eq("yamada")
      end

      it "returns all candidates when query is empty" do
        linker = GuestParticipantLinker.new(user: target_user)
        candidates = linker.candidates(nil)
        expect(candidates.size).to eq(1)
      end
    end

    context "when target user is already a participant" do
      before do
        create(:proxy_order_participant, :guest, proxy_order: order_a, guest_name: "Yamada")
        create(:proxy_order_participant, proxy_order: order_a, user: target_user)
      end

      it "marks the candidate as not selectable" do
        linker = GuestParticipantLinker.new(user: target_user)
        candidates = linker.candidates
        yamada_candidate = candidates.find { |c| c.normalized_name == "yamada" }
        expect(yamada_candidate.selectable?).to be false
        expect(yamada_candidate.conflicts).not_to be_empty
        expect(yamada_candidate.conflicts.first).to include(event_a.title)
      end
    end

    context "when target user has discarded participation" do
      before do
        create(:proxy_order_participant, :guest, proxy_order: order_a, guest_name: "Yamada")
        participant = create(:proxy_order_participant, proxy_order: order_a, user: target_user)
        participant.update_column(:discarded_at, Time.current)
      end

      it "still marks candidate as not selectable with discarded message" do
        linker = GuestParticipantLinker.new(user: target_user)
        candidates = linker.candidates
        yamada_candidate = candidates.find { |c| c.normalized_name == "yamada" }
        expect(yamada_candidate.selectable?).to be false
        expect(yamada_candidate.conflicts.first).to include("削除済み")
      end
    end

    context "when guest order is discarded but user has valid participation" do
      before do
        create(:proxy_order_participant, :guest, proxy_order: order_a, guest_name: "Yamada")
        guest_in_discarded = create(:proxy_order_participant, :guest, proxy_order: order_b, guest_name: "yamada")
        order_b.discard!
        create(:proxy_order_participant, proxy_order: order_b, user: target_user)
      end

      it "marks candidate as not selectable" do
        linker = GuestParticipantLinker.new(user: target_user)
        candidates = linker.candidates
        yamada_candidate = candidates.find { |c| c.normalized_name == "yamada" }
        expect(yamada_candidate.selectable?).to be false
      end
    end

    it "returns candidates sorted by normalized name" do
      create(:proxy_order_participant, :guest, proxy_order: order_a, guest_name: "Suzuki")
      create(:proxy_order_participant, :guest, proxy_order: order_b, guest_name: "Alice")
      linker = GuestParticipantLinker.new(user: target_user)
      candidates = linker.candidates
      expect(candidates.map(&:normalized_name)).to eq([ "alice", "suzuki" ])
    end
  end

  describe "#call" do
    context "with valid participants to link" do
      before do
        create(:proxy_order_participant, :guest, proxy_order: order_a, guest_name: "Yamada")
      end

      it "links matching participant" do
        linker = GuestParticipantLinker.new(user: target_user, guest_name_key: "yamada", actor: admin)
        result = linker.call
        expect(result.success?).to be true
        expect(result.count).to eq(1)

        linked_participant = ProxyOrderParticipant.find(result.participant_ids.first)
        expect(linked_participant.user_id).to eq(target_user.id)
        expect(linked_participant.guest_name).to be_nil
        expect(linked_participant.linked_from_guest_name).to eq("Yamada")
      end
    end

    context "when no matching participants exist" do
      it "returns failure" do
        linker = GuestParticipantLinker.new(user: target_user, guest_name_key: "yamada", actor: admin)
        result = linker.call
        expect(result.success?).to be false
        expect(result.errors).to include(I18n.t("admin.users.guest_link.not_found"))
      end
    end

    context "with collision detection" do
      before do
        create(:proxy_order_participant, :guest, proxy_order: order_a, guest_name: "Yamada")
        create(:proxy_order_participant, proxy_order: order_a, user: target_user)
      end

      it "detects collision and rolls back" do
        linker = GuestParticipantLinker.new(user: target_user, guest_name_key: "yamada", actor: admin)
        result = linker.call

        expect(result.success?).to be false
        expect(result.errors).not_to be_empty

        guest_participant = ProxyOrderParticipant.find_by(proxy_order_id: order_a.id, user_id: nil)
        expect(guest_participant.guest_name).to eq("Yamada")
        expect(guest_participant.linked_from_guest_name).to be_nil
      end
    end

    context "audit logging on success" do
      before do
        create(:proxy_order_participant, :guest, proxy_order: order_a, guest_name: "Charlie")
      end

      it "records audit log with success" do
        linker = GuestParticipantLinker.new(user: target_user, guest_name_key: "charlie", actor: admin, request_id: "req-123")
        result = linker.call

        audit_log = AuditLog.find_by(action: "user.link_guest_participants", target_type: "User", target_id: target_user.id)
        expect(audit_log).to be_present
        expect(audit_log.result).to eq("success")
        expect(audit_log.user_id).to eq(admin.id)
        expect(audit_log.request_id).to eq("req-123")
        expect(audit_log.details["guest_name"]).to contain_exactly("Charlie")
        expect(audit_log.details["normalized_name"]).to eq("charlie")
        expect(audit_log.details["count"]).to eq(1)
      end
    end

    context "audit logging on failure" do
      before do
        create(:proxy_order_participant, :guest, proxy_order: order_a, guest_name: "Yamada")
        create(:proxy_order_participant, proxy_order: order_a, user: target_user)
      end

      it "records audit log with failure and reason" do
        linker = GuestParticipantLinker.new(user: target_user, guest_name_key: "yamada", actor: admin, request_id: "req-456")
        result = linker.call

        audit_log = AuditLog.find_by(action: "user.link_guest_participants", target_type: "User", target_id: target_user.id)
        expect(audit_log).to be_present
        expect(audit_log.result).to eq("failure")
        expect(audit_log.details["reason"]).to be_present
        expect(audit_log.details["normalized_name"]).to eq("yamada")
      end
    end

    context "when participant has allocations" do
      before do
        item = create(:proxy_order_item, proxy_order: order_a)
        participant = create(:proxy_order_participant, :guest, proxy_order: order_a, guest_name: "Yamada", handed_over_at: Time.current)
        create(:proxy_order_allocation, proxy_order_item: item, proxy_order_participant: participant, quantity: 2, lost_quantity: 1)
      end

      it "preserves allocations and handed_over_at" do
        allocation_before = ProxyOrderAllocation.first
        participant_before = ProxyOrderParticipant.find_by(proxy_order_id: order_a.id, user_id: nil)
        original_handed_over_at = participant_before.handed_over_at

        linker = GuestParticipantLinker.new(user: target_user, guest_name_key: "yamada", actor: admin)
        result = linker.call

        allocation_after = ProxyOrderAllocation.find(allocation_before.id)
        participant_after = ProxyOrderParticipant.find(participant_before.id)

        expect(allocation_after.quantity).to eq(2)
        expect(allocation_after.lost_quantity).to eq(1)
        expect(participant_after.handed_over_at).to eq(original_handed_over_at)
      end
    end

    context "with different proxy order statuses" do
      before do
        order_a.update_column(:status, "ordered")
        order_b.update_column(:status, "arrived")

        order_c = create(:proxy_order, event: create(:event, :proxy_order, title: "Event C"), status: "completed")
        create(:proxy_order_participant, :guest, proxy_order: order_a, guest_name: "Yamada")
        create(:proxy_order_participant, :guest, proxy_order: order_b, guest_name: "yamada")
        create(:proxy_order_participant, :guest, proxy_order: order_c, guest_name: "YAMADA")
      end

      it "links participants across different statuses" do
        linker = GuestParticipantLinker.new(user: target_user, guest_name_key: "yamada", actor: admin)
        result = linker.call

        expect(result.success?).to be true
        expect(result.count).to eq(3)

        [ order_a, order_b ].each do |order|
          linked = ProxyOrderParticipant.find_by(proxy_order_id: order.id, user_id: target_user.id)
          expect(linked).to be_present
          expect(linked.guest_name).to be_nil
        end
      end
    end
  end
end
