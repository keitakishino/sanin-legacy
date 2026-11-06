class AddPaymentFeeUsdToProxyOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :proxy_orders, :payment_fee_usd, :decimal, precision: 10, scale: 2, default: "0.0", null: false, comment: "決済手数料（$）"
  end
end
