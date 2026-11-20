class ReplaceFeeAmountsWithRatesOnProxyOrders < ActiveRecord::Migration[8.1]
  def change
    remove_column :proxy_orders, :tax_usd, :decimal, precision: 10, scale: 2, default: "0.0", null: false
    remove_column :proxy_orders, :customs_usd, :decimal, precision: 10, scale: 2, default: "0.0", null: false
    remove_column :proxy_orders, :payment_fee_usd, :decimal, precision: 10, scale: 2, default: "0.0", null: false, comment: "決済手数料（$）"

    add_column :proxy_orders, :payment_fee_rate, :decimal, precision: 5, scale: 2, default: "4.1", null: false, comment: "決済手数料率（%）"
    add_column :proxy_orders, :customs_rate, :decimal, precision: 5, scale: 2, default: "4.0", null: false, comment: "関税率（%）"
    add_column :proxy_orders, :consumption_tax_rate, :decimal, precision: 5, scale: 2, default: "10.0", null: false, comment: "消費税率（%）"
  end
end
