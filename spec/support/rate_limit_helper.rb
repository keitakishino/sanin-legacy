# レート制限は専用ストア（config/initializers/rate_limit.rb）にカウンタを持つ。
# プロセス内メモリなので、example 間で持ち越さないよう毎回クリアする。
RSpec.configure do |config|
  config.before(:each) do
    Rails.application.config.x.rate_limit_store.clear
  end
end
