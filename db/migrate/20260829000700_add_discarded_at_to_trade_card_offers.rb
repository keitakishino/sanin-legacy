class AddDiscardedAtToTradeCardOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :trade_card_offers, :discarded_at, :datetime, comment: "論理削除フラグ（null=有効、datetime=削除日時）"
    add_index :trade_card_offers, :discarded_at
  end
end
