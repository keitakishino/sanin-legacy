# SaninLegacy

マジック:ザ・ギャザリングのカードトレード管理を行う Rails 8 アプリケーション（MVP）。

## セットアップ

### 前提条件
- Docker & Docker Compose
- Ruby 3.3.12（ローカル開発の場合）
- PostgreSQL 17

### 開発環境のセットアップ

#### 初回セットアップ

初回は、development ステージを含む Docker イメージをビルドし、全サービスを起動します。

```bash
docker compose up --build
```

このコマンドは以下を行います。
- development・test 依存関係を含む全gemをインストールした Docker イメージのビルド
- PostgreSQL データベースサービスの起動
- データベースの準備（`db:prepare`）の実行
- Rails アプリケーションサーバーを http://localhost:3000 で起動

#### 2回目以降の起動

Docker イメージがビルド済みの場合、2回目以降は以下のみで起動できます。

```bash
docker compose up
```

#### サービスの停止

全サービスを停止するには以下を実行します。

```bash
docker compose down
```

#### よく使う開発コマンド

アプリケーションログの確認:

```bash
docker compose logs -f app
```

Rails コンソールへの接続:

```bash
docker compose exec app bundle exec rails console
```

データベースマイグレーションの実行:

```bash
docker compose exec app bundle exec rails db:migrate
```

データベースへのシード投入:

```bash
docker compose exec app bundle exec rails db:seed
```

テストの実行:

```bash
docker compose exec app bundle exec rspec
```

コード品質チェックの実行:

```bash
docker compose exec app bundle exec rubocop
```

アプリケーションは `http://localhost:3000` でアクセスできます。

### 環境設定

`.env.example` を `.env` にコピーし、必要に応じて編集してください。

```bash
cp .env.example .env
```

## Google Sheets API 設定

### Phase 7.1: サービスアカウント認証

本アプリケーションはトレードデータのエクスポートに Google Sheets API を使用します。サービスアカウント認証は Rails credentials（暗号化された `config/credentials.yml.enc`）経由で設定します。

#### Google Sheets サービスアカウント認証情報のセットアップ

1. **GCP サービスアカウントキーの取得**
   - Google Cloud Project を作成し、Google Sheets API / Google Drive API を有効化する
   - サービスアカウントを作成し、JSON キーファイルをダウンロードする

2. **Rails credentials への追加**

   ```bash
   bin/rails credentials:edit
   ```

   `google_sheets:` 以下に次の構造を追加します（プレースホルダーの値は実際のサービスアカウント JSON の内容に置き換えてください）。

   ```yaml
   google_sheets:
     type: "service_account"
     project_id: "your-gcp-project-id"
     private_key_id: "your-private-key-id"
     private_key: "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA...\n-----END RSA PRIVATE KEY-----\n"
     client_email: "your-service-account@your-project.iam.gserviceaccount.com"
     client_id: "1234567890"
     auth_uri: "https://accounts.google.com/o/oauth2/auth"
     token_uri: "https://oauth2.googleapis.com/token"
     auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs"
     client_x509_cert_url: "https://www.googleapis.com/certificates/..."
   ```

   **重要**: `private_key` フィールドの改行は、実際の改行文字ではなく `\n` として保持してください。

3. **本番環境（Kamal デプロイ）の場合**
   - `RAILS_MASTER_KEY` は `.kamal/secrets` → `config/deploy.yml` 経由で自動的に注入されます
   - 追加の設定は不要で、既存のシークレット管理の仕組みが認証情報の復号を行います

### クライアントの使い方

本アプリケーションは、認証済み API クライアントにアクセスするための `GoogleSheetsConfig` モジュールを提供します。

```ruby
# Sheets API
sheets_client = GoogleSheetsConfig.sheets_client

# Drive API
drive_client = GoogleSheetsConfig.drive_client
```

両クライアントには、以下の用途に適した OAuth スコープがあらかじめ設定されています。

- Google Sheets の読み書き
- Google Drive ファイルの管理

認証情報が設定されていない場合、両メソッドとも `GoogleSheetsConfig::CredentialsNotConfiguredError` を発生させます。

## テスト

```bash
docker compose exec app bundle exec rspec
```

## コード品質チェック

```bash
docker compose exec app bundle exec rubocop
```
