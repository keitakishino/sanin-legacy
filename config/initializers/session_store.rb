# セッションクッキーに有効期限を持たせる。
#
# 既定（期限なし）だとブラウザを閉じるまで有効なうえ、暗号化クッキーの中にも
# 期限が入らないため、漏れたクッキーをあとから投げ直されると無期限に通ってしまう。
# expire_after を入れると cookie の Expires と暗号化メッセージ内の期限の両方が
# 設定されるので、クライアント側の Expires を無視して投げ直されてもサーバ側で弾ける。
#
# この期限はリクエストのたびに延びる（アイドルタイムアウト）。活動中でも必ず
# 再認証させる絶対的な上限は ApplicationController::SESSION_MAX_AGE 側で見ている。
#
# key は Rails の既定（Rails::Application::Finisher の
# :setup_default_session_store が付ける "_#{railtie_name}_session"）と同じ値を
# 明示している。ここで session_store を呼ぶと既定の設定がスキップされるため、
# 違う値にすると配信時に全員のセッションが切れる。
#
# same_site / cookie_only は渡さない。ActionDispatch::Session::CookieStore 側が
# 既定を入れてくれるうえ、8.1 の same_site 既定は Proc で、OAuth のコールバックなど
# クロスサイトからの戻りを考慮した値を返すため、固定値に潰さない。
# secure は config.force_ssl（本番で有効）から自動で付く。
Rails.application.config.session_store :cookie_store,
  key: "_sanin_legacy_session",
  expire_after: 7.days
