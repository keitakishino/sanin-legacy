# 認証系エンドポイントにレート制限をかけるための共通処理。
#
# Rails 8 の `rate_limit` をそのまま使うと Rails.cache（環境ごとに実体が違う）に
# 載ってしまうため、専用ストア（config/initializers/rate_limit.rb）を指定した
# ラッパーを用意している。
module RateLimitable
  extend ActiveSupport::Concern

  class_methods do
    def rate_limit_auth(to:, within:, name:, **options)
      rate_limit(
        to: to,
        within: within,
        name: name,
        store: Rails.application.config.x.rate_limit_store,
        **options
      )
    end
  end

  private

  # 上限に達したときは 429 でフォームを返す。
  # 攻撃者に残り試行回数などのヒントを与えないよう、文言は共通の 1 つだけにする。
  def render_rate_limited(template)
    flash.now[:alert] = t("errors.rate_limited")
    render template, status: :too_many_requests
  end
end
