# Worktree Setup Guide

このドキュメントでは、SaninLegacyプロジェクトでの複数worktree並列稼働時のセットアップ方法を説明します。

## 概要

複数のgit worktreeを並列稼働させる場合、各worktreeはDockerコンテナを起動する際にDBポート（デフォルト: 5432）とアプリケーションポート（デフォルト: 3000）を使用します。複数のworktreeが同時に起動されると、これらのポートが競合し、エラーが発生します。

このスクリプトシステムは、新しいworktree作成時に自動的に利用可能なポート番号を採番し、各worktreeの`.env`ファイルに設定することで、このポート競合を自動的に解決します。

## 自動セットアップ（推奨）

### 新しいworktreeを作成する

```bash
./scripts/create_worktree.sh --branch <branch-name>
```

**オプション:**
- `--branch <branch-name>` （必須）: 作成するブランチ名
- `--issue <number>` （オプション）: Issue番号（ドキュメント用）

**例:**
```bash
# Issue #216 に基づいてブランチを作成
./scripts/create_worktree.sh --issue 216 --branch fix/docker-db-port-isolation

# または Issue番号なしで作成
./scripts/create_worktree.sh --branch feature/new-feature
```

このスクリプトが実行する処理：
1. git worktreeを指定ブランチで作成
2. `.env.example` をコピーして `.env` を生成
3. スクリプトによって自動採番されたDB_PORT・APP_PORTを `.env` に追記
4. 初期セットアップ完了メッセージを表示

### ポート割り当ての確認

スクリプト実行後、以下のように割り当てられたポート情報が表示されます：

```
==========================================
Worktree setup completed successfully!
==========================================
Worktree path:     /home/pepo2/worktrees/fix-docker-db-port-isolation
Branch name:       fix/docker-db-port-isolation
DB port:           5433
APP port:          3001

Next steps:
  1. cd /home/pepo2/worktrees/fix-docker-db-port-isolation
  2. docker compose up -d
  3. docker compose exec web bundle exec rails server

Issue #216
==========================================
```

## 手動ポート割り当て（既存worktreeの場合など）

既存のworktreeに対して手動でポートを設定する場合：

### 1. 使用中のポートを確認

```bash
for dir in /home/pepo2/worktrees/*/; do 
  if [ -f "$dir/.env" ]; then
    worktree=$(basename "$dir")
    db_port=$(grep "^DB_PORT=" "$dir/.env" | cut -d= -f2)
    app_port=$(grep "^APP_PORT=" "$dir/.env" | cut -d= -f2)
    [ -n "$db_port" ] && echo "$worktree: DB=$db_port, APP=$app_port"
  fi
done | sort
```

### 2. .envファイルを編集

worktreeのディレクトリにある `.env` ファイルを編集し、使用中でないポート番号を設定します：

```bash
# worktreeのディレクトリに移動
cd /home/pepo2/worktrees/<worktree-name>

# .envを編集
# ポート番号が既に使用中でないか確認してから設定してください
echo "DB_PORT=5433" >> .env
echo "APP_PORT=3001" >> .env
```

**ポート割り当てのガイドライン:**
- DB_PORT: 5430 ～ 5470の範囲から未使用のポートを選択
- APP_PORT: 3001 ～ 3050の範囲から未使用のポートを選択
- デフォルトのDB_PORT=5432、APP_PORT=3000は使用しないこと（mainブランチで使用中）

## ポート採番スクリプト（scripts/setup_worktree.rb）

ポート採番ロジックは `scripts/setup_worktree.rb` に実装されています。

### 動作

このRubyスクリプトは以下の処理を行います：

1. `/home/pepo2/worktrees/*/` 配下のすべてのworktreeをスキャン
2. 各worktreeの `.env` ファイルから既に使用中のDB_PORT・APP_PORTを抽出
3. デフォルト値（DB: 5432, App: 3000）と既使用ポートを避けて、次の利用可能なポート番号を採番
4. JSON形式で結果を出力: `{"DB_PORT": XXXX, "APP_PORT": YYYY}`

### 冪等性

スクリプトは冪等設計です。同じworktree名で複数回実行しても、既に `.env` に設定されているポート番号が返されます。

### 直接実行

```bash
ruby scripts/setup_worktree.rb <worktree-name>

# 例
ruby scripts/setup_worktree.rb fix-docker-db-port-isolation
# 出力: {"DB_PORT":5433,"APP_PORT":3001}

# 2回目以降、既に.envが存在する場合は同じポート番号が返される
ruby scripts/setup_worktree.rb fix-docker-db-port-isolation
# 出力: {"DB_PORT":5433,"APP_PORT":3001}
```

## docker-compose.yml での設定

`docker-compose.yml` では環境変数によるポートのオーバーライドに対応しています：

```yaml
services:
  db:
    ports:
      - "${DB_PORT:-5432}:5432"  # 環境変数DB_PORTで上書き可能、デフォルト5432
  
  app:
    ports:
      - "${APP_PORT:-3000}:3000" # 環境変数APP_PORTで上書き可能、デフォルト3000
```

`.env` ファイルに `DB_PORT` および `APP_PORT` を設定することで、`docker compose up` コマンド実行時に自動的にこれらの値が読み込まれます。

## トラブルシューティング

### ポート競合エラーが発生する

```
Error response from daemon: Ports are not available: exposing port TCP 0.0.0.0:5432 -> 0.0.0.0:0: listen tcp 0.0.0.0:5432: bind: address already in use
```

**解決策:**
1. 既存のworktreeで起動中のDockerコンテナを確認: `docker ps`
2. 使用中のポートを確認: `for dir in /home/pepo2/worktrees/*/; do [ -f "$dir/.env" ] && grep "PORT" "$dir/.env"; done`
3. worktreeの `.env` ファイルにDB_PORT・APP_PORTが正しく設定されているか確認
4. 必要に応じて、別のポート番号を手動で割り当てる

### worktreeの作成に失敗する

スクリプト実行時にエラーが表示される場合は、以下を確認してください：

1. ブランチ名が有効か確認
2. worktreeディレクトリが既に存在していないか確認: `ls -la /home/pepo2/worktrees/`
3. git が正常に動作しているか確認: `git status`

### 既存worktreeの.envがない場合

worktreeディレクトリに `.env` ファイルがない場合は、以下のコマンドで手動作成できます：

```bash
cd /home/pepo2/worktrees/<worktree-name>
cp /path/to/project/.env.example .env
echo "DB_PORT=XXXX" >> .env
echo "APP_PORT=YYYY" >> .env
```

## まとめ

- **新しいworktree作成時**: `./scripts/create_worktree.sh --branch <branch-name>` を実行（ポート自動採番）
- **既存worktree**: 手動で `.env` に DB_PORT・APP_PORT を設定
- **ポート確認**: `grep "PORT" /home/pepo2/worktrees/*/.env` でスキャン可能
- **デフォルト値**: 変更されない（後方互換性維持）
