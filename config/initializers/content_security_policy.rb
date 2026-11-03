# Content Security Policy。
# XSS が 1 件混入したときに、外部へのスクリプト読み込みやデータ送信を止めるための緩和層。
#
# レイアウトには以前から csp_meta_tag があったが、ポリシー本体がコメントアウトされて
# いたため CSP ヘッダは一切出ていなかった。
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    policy.object_src  :none
    policy.frame_ancestors :self
    policy.form_action :self
    policy.connect_src :self
    policy.img_src     :self, :data
    policy.manifest_src :self

    # Google Fonts（レイアウトの link と、そこから読まれる woff2）。
    policy.style_src :self, "https://fonts.googleapis.com"
    policy.font_src  :self, :data, "https://fonts.gstatic.com"

    # style="display: none;" のようなインラインの style 属性がビューに多数あるため、
    # 属性だけは許可する。style-src（<style> と <link>）側は self のままなので、
    # 外部スタイルシートの差し込みは止まる。
    policy.style_src_attr :unsafe_inline

    # script-src は self と nonce のみ。
    # - importmap / Turbo / Stimulus は importmap-rails が nonce を付けてくれる
    # - ビューのインライン <script> には明示的に nonce を付けている
    # - script-src-attr は指定しない（script-src にフォールバックし、
    #   onclick= のようなインラインのイベントハンドラは実行されない）
    policy.script_src :self
  end

  # nonce はセッション単位にする（Rails が生成するテンプレートと同じやり方）。
  #
  # リクエストごとの使い捨てにすると Turbo で壊れる。Turbo の画面遷移は新しい
  # ドキュメントを作らず body を差し替えるだけなので、CSP は最初に読み込んだ
  # ドキュメントのものが効き続ける。一方、差し替えで挿し直されるインライン
  # <script> には新しいレスポンスの nonce が付くため、両者が食い違って弾かれる。
  # （実際、ソートのリンクを踏んだあとに明細の追加ボタンが動かなくなった）
  #
  # インライン <script> をすべて Stimulus に移せばリクエストごとの nonce に
  # できるが、それは別途。
  #
  # session.id をそのまま使わないのは、セッションを作って最初の 1 リクエストでは
  # まだ id が無く（commit 時に採番される）、その画面だけ別の値になってしまうため。
  # 自分でセッションに値を持たせれば 1 リクエスト目から一定になる。
  # セッション middleware は CSP middleware の外側にあるので、ここでの書き込みも
  # ちゃんとクッキーに乗る。
  config.content_security_policy_nonce_generator = lambda do |request|
    request.session[:csp_nonce] ||= SecureRandom.base64(16)
  end

  # Turbo はプログレスバーの CSS を <style> で挿すので、style-src にも nonce が要る。
  # nonce を足しても 'self' が無効になるわけではないので、Tailwind の <link> はそのまま通る。
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
