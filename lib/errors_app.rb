class ErrorsApp
  def self.call(env)
    new(env).call
  end

  def initialize(env)
    @env = env
    @request = ActionDispatch::Request.new(env)
    @public_exceptions = ActionDispatch::PublicExceptions.new(Rails.public_path)
  end

  def call
    status = extract_status_from_path_info

    return public_exceptions_response unless status == 404

    case request_format
    when :json
      # JSON 要求は PublicExceptions に委譲
      # PublicExceptions が { "status": 404, "error": "Not Found" } の JSON を返す
      public_exceptions_response
    when :head
      # HEAD リクエストは本文なし
      head_response
    else
      # HTML・turbo_stream・その他は ErrorsController で描画
      render_with_fallback { ErrorsController.action(:not_found).call(@env) }
    end
  end

  private

  attr_reader :env, :request, :public_exceptions

  def extract_status_from_path_info
    # ShowExceptions が PATH_INFO を "/404" などに書き換えて呼ぶ
    request.path_info.delete_prefix("/").to_i
  end

  def request_format
    # 元のリクエストメソッドを確認
    original_method = env["action_dispatch.original_request_method"] || env["REQUEST_METHOD"]
    return :head if original_method == "HEAD"

    # JSON 判定
    begin
      return :json if request.formats.first == Mime[:json]
    rescue ActionDispatch::Http::MimeNegotiation::InvalidType
      # フォーマット解析に失敗した場合は HTML 扱い
    end

    :html
  end

  def head_response
    [ 404, { "content-type" => "text/html; charset=utf-8" }, [] ]
  end

  def public_exceptions_response
    public_exceptions.call(env)
  end

  def render_with_fallback
    yield
  rescue StandardError => e
    Rails.logger.error("[ErrorsApp] failed to render error page: #{e.class}: #{e.message}")
    # 描画失敗時は 500 の静的ページにフォールバック
    fallback_env = env.dup
    fallback_env["PATH_INFO"] = "/500"
    public_exceptions.call(fallback_env)
  end
end
