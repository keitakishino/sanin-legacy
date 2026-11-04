# 認証系エンドポイント（サインイン・サインアップ・招待コード入力）の
# 総当たり対策で使うレート制限用ストア。
#
# Rails.cache をそのまま使わないのは次の 2 点のため:
#   - 環境ごとに実体が違う（本番 :memory_store / テスト :null_store）。
#     :null_store だと increment が nil を返し、レート制限が一切効かない。
#   - Rails.cache.clear のような一般のキャッシュ操作で、
#     レート制限のカウンタまで巻き添えで消えてしまう。
#
# 現状はアプリケーションサーバが 1 ホストなのでプロセス内メモリで足りる。
# 複数ホストに広げるときは、ここを共有ストア（Redis など）に差し替える。
Rails.application.config.x.rate_limit_store = ActiveSupport::Cache::MemoryStore.new(size: 2.megabytes)
