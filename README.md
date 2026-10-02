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

## テスト

```bash
docker compose exec app bundle exec rspec
```

## コード品質チェック

```bash
docker compose exec app bundle exec rubocop
```
