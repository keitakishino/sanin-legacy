class AddLinkedFromGuestNameToProxyOrderParticipants < ActiveRecord::Migration[8.0]
  def change
    add_column :proxy_order_participants, :linked_from_guest_name, :string, comment: "紐づけ前の自由入力名（紐づけ解除で guest_name に戻す）"
  end
end
