require "rails_helper"

RSpec.describe "Content Security Policy", type: :request do
  let(:user) { create(:user, email: "csp@example.com", password: "password123") }

  def csp
    response.headers["content-security-policy"].to_s
  end

  describe "サインイン画面（未認証）" do
    before { get signin_path }

    it "CSP ヘッダが出ている" do
      expect(csp).to be_present
    end

    it "既定を self に閉じ、object / frame-ancestors / base-uri / form-action を絞っている" do
      expect(csp).to include("default-src 'self'")
      expect(csp).to include("object-src 'none'")
      expect(csp).to include("frame-ancestors 'self'")
      expect(csp).to include("base-uri 'self'")
      expect(csp).to include("form-action 'self'")
    end

    it "script-src は self と nonce だけで、unsafe-inline / unsafe-eval を許していない" do
      expect(csp).to match(/script-src 'self' 'nonce-[^']+'/)
      expect(csp).not_to include("script-src 'self' 'unsafe-inline'")
      expect(csp).not_to include("'unsafe-eval'")
    end

    it "インラインのイベントハンドラ（onclick= など）は許可しない" do
      # script-src-attr を指定していないので script-src にフォールバックする。
      # script-src に 'unsafe-inline' が無い＝インラインハンドラは実行されない。
      expect(csp).not_to include("script-src-attr")
    end

    it "style 属性だけ許可し、スタイルシートは self と Google Fonts に限る" do
      expect(csp).to include("style-src-attr 'unsafe-inline'")
      expect(csp).to match(/style-src 'self' https:\/\/fonts\.googleapis\.com 'nonce-[^']+'/)
      expect(csp).to include("font-src 'self' data: https://fonts.gstatic.com")
      expect(csp).not_to include("style-src 'self' https://fonts.googleapis.com 'unsafe-inline'")
    end

    it "meta タグの nonce とヘッダの nonce が一致する" do
      nonce = response.body[/<meta name="csp-nonce" content="([^"]+)"/, 1]

      expect(nonce).to be_present
      expect(csp).to include("'nonce-#{nonce}'")
    end
  end

  describe "nonce" do
    # Turbo は body を差し替えるだけで新しいドキュメントを作らないため、
    # 最初に読み込んだドキュメントの CSP が効き続ける。差し替えで挿し直される
    # インライン <script> が弾かれないよう、nonce はセッション単位にしている。
    it "同じセッションの間は変わらない" do
      get signin_path
      first = csp[/'nonce-([^']+)'/, 1]

      get signin_path
      second = csp[/'nonce-([^']+)'/, 1]

      expect(first).to be_present
      expect(second).to eq(first)
    end

    it "セッションが変わると変わる" do
      get signin_path
      first = csp[/'nonce-([^']+)'/, 1]

      post signin_path, params: { email: user.email, password: "password123" }
      get root_path
      second = csp[/'nonce-([^']+)'/, 1]

      expect(second).to be_present
      expect(second).not_to eq(first)
    end
  end

  describe "インライン script を持つ画面" do
    before do
      post signin_path, params: { email: user.email, password: "password123" }
    end

    it "トレード履歴のインライン script に nonce が付く" do
      get histories_path

      nonce = csp[/'nonce-([^']+)'/, 1]
      expect(response.body).to include(%(<script nonce="#{nonce}">))
    end

    it "importmap の script にも nonce が付く" do
      get root_path

      nonce = csp[/'nonce-([^']+)'/, 1]
      expect(response.body).to include(%(type="importmap"))
      expect(response.body.scan(%(nonce="#{nonce}")).size).to be >= 2
    end
  end

  describe "ビューにインラインのイベントハンドラが残っていないこと" do
    # script-src-attr を指定していないため、onclick= などは CSP で実行されない。
    # HTML に直接書いた形（onclick="..."）と、ERB のヘルパーに渡す形（onchange: "..."）の
    # 両方を見る。後者は画面を開くまで気づけないので、ここで止める。
    INLINE_HANDLER = /\bon(?:click|change|submit|input|load|error|keyup|keydown|focus|blur|select)\s*[:=]/

    it "app/views にインラインのイベントハンドラがない" do
      offenders = Dir.glob(Rails.root.join("app/views/**/*.erb")).select do |path|
        File.read(path).match?(INLINE_HANDLER)
      end

      expect(offenders).to be_empty
    end

    it "app/helpers にもインラインのイベントハンドラがない" do
      offenders = Dir.glob(Rails.root.join("app/helpers/**/*.rb")).select do |path|
        File.read(path).match?(INLINE_HANDLER)
      end

      expect(offenders).to be_empty
    end
  end
end
