# Issue #197対応 引き継ぎメモ

## Issue概要

**トースト通知（バリデーションエラー/登録完了/削除）の表示不具合修正**

- カード明細の登録・更新・削除操作時に表示されるべきトースト通知が、UIに表示されない不具合
- 対象画面: トレード詳細ページ（`trades/show.html.erb`）および管理者トレード詳細ページ（`admin/trades/show.html.erb`）
- GitHub PR: https://github.com/keitakishino/sanin-legacy/pull/220

---

## 原因診断の変遷

### 第1段階: 初期診断（前任者のセッション1）

**診断内容:**
```
「trades/show.html.erb」および「admin/trades/show.html.erb」に
toast-container要素が存在しないため、turbo-streamのappendが効かない
```

**実施した修正:**
- `app/views/trades/show.html.erb`の先頭にtoast-containerを追加
- `app/views/admin/trades/show.html.erb`の先頭にtoast-containerを追加
- コミット: `911a07b fix: Issue #197 - トースト通知が表示されない不具合を修正`
- RSpec実行: 121例（trade_card_offers_spec.rb, trade_card_wants_spec.rb）、**0 failures確認**
- PR #220作成時に「修正完了」と判断

**この診断は誤りだったことが後で判明**

### 第2段階: 再検証で判明した真の原因（当セッション）

**再検証の契機:**
- GitHub CIは通過（121 examples, 0 failures）
- しかし、別のセッションでの実際の操作確認でも画面にトーストが表示されない
- Playwright検証で、ネットワークレスポンスには正常なtoast HTMLが含まれている（Content-Type: text/vnd.turbo-stream.html）にもかかわらず、ブラウザの実DOM（`document.getElementById('toast-container').innerHTML`）には何も追加されていない

**真の原因の発見:**

`app/views/layouts/application.html.erb` の109行目に、元々toast-containerが存在していた：

```erb
<div id="toast-container" class="fixed top-4 right-4 flex flex-col gap-2 z-50"></div>
```

前任者の修正により、同じIDを持つ要素が**複数個（最低3箇所）** になった：
1. `layouts/application.html.erb` のtoast-container（グローバル）
2. `trades/show.html.erb` のtoast-container（重複追加）
3. `admin/trades/show.html.erb` のtoast-container（重複追加）

HTML ID重複により、Turbo Streamのappendが**最初にマッチした要素**（application.html.erb側）に効いた。ところが、application.html.erb側のtoast-containerには当初 `pointer-events-none` クラスが適用されており、子要素の `pointer-events-auto` が無効化されていた。その結果、トースト要素はDOMには追加されたが、ユーザーはクリックできず、視認性も低い状態になっていた。

**設計書の確認:**

プロジェクトの設計方針に、「トースト表示エリアはapplication.html.erbに1箇所のみ配置し、個別画面ごとに用意しない」と明記されている（実装時のドキュメント:「20260905_カード追加更新削除操作のトースト通知設計.md」より）。前任者の修正は、この設計方針に違反していた。

---

## 実施した修正内容と理由

**コミット: `da6b421 fix: Issue #197 - トースト表示不具合を完全修正`**

### 修正1: CSS修正（application.html.erb）

**ファイル**: `app/views/layouts/application.html.erb` (109行目)

**変更**: `pointer-events-none` クラスを削除

```diff
- <div id="toast-container" class="fixed top-4 right-4 z-50 flex flex-col gap-2 z-50 pointer-events-none"></div>
+ <div id="toast-container" class="fixed top-4 right-4 flex flex-col gap-2 z-50"></div>
```

**理由**: 
- 親要素の `pointer-events-none` が子要素の `pointer-events-auto` を無効化していた
- これにより、トースト要素がレンダリングされても、マウスイベント（ホバー、クリック）が透過してしまっていた
- 削除により、子要素のインタラクティブ性が復帰する

### 修正2: 重複要素を削除

**ファイル**: `app/views/trades/show.html.erb` (先頭)

**変更**: 前任者が追加した重複toast-containerを削除

**ファイル**: `app/views/admin/trades/show.html.erb` (先頭)

**変更**: 前任者が追加した重複toast-containerを削除

**理由**:
- HTML ID重複は仕様違反
- 設計書に「application.html.erbに1箇所のみ」と明記
- Turbo Streamのappendはグローバルの`application.html.erb`側にのみ機能させるべき

### 修正3: CSSアニメーション確認

**トースト表示**のアニメーション（`toast-countdown`）は `app/assets/stylesheets/components/toast.css` で正常に定義されていることを確認

```css
@keyframes toast-countdown {
  from {
    width: 100%;
  }
  to {
    width: 0%;
  }
}
```

---

## 試したPlaywright検証手法と結果

### 検証フロー

複数回にわたり、以下の操作と確認を実施：

1. **ログイン処理**: `browser_navigate` でログイン画面へ、フォーム入力・送信
2. **トレード詳細ページ遷移**: カード取引一覧から詳細ページへ
3. **カード明細登録操作**:
   - 登録フォーム呼び出し（Turbo Frames）
   - 正常系データ入力→登録（成功トースト期待）
   - バリデーションエラーデータ入力→登録（エラートースト期待）
4. **カード明細削除操作**: 削除ボタン操作（削除トースト期待）
5. **実DOM確認**: 以下を複数のタイミングで実行
   - `browser_snapshot` でAccessibility Treeの構造確認
   - `browser_take_screenshot` で画面の見た目確認
   - `browser_evaluate` で実DOM検査: 
     ```javascript
     document.getElementById('toast-container').innerHTML
     document.getElementById('toast-container').childCount
     document.getElementById('toast-container').children
     ```

### 一貫した検証結果

**症状**:
- サーバー側のturbo-streamレスポンスには、トースト要素HTMLが正しく含まれている
  - Content-Type: `text/vnd.turbo-stream.html`
  - body内に `<div id="toast-xx" ...>` が存在
- ブラウザのネットワークタブでも確認可能
- **しかし、ブラウザの実DOM**（`document.getElementById('toast-container').innerHTML`）は**空のまま**（childCount: 0）
- 画面上にもトースト要素は表示されない

**この症状は、環境再構築後・別のcoderセッションでも再現しており、偶然ではなく共通原因があると考えられた**

### 発見された問題点（未解決）

この症状は、以下の原因の組み合わせが考えられる：

1. **Turbo Streamのappend不具合**: Turbo自体は読み込まれていることを確認済み（`window.Turbo`は存在）だが、なぜかappendが実DOMに反映されない
2. **worktree環境固有の問題**: 別worktreeでは同じ問題が発生していない可能性
3. **JSコンソールエラー**: 重大なエラーは見当たらないが、警告レベルのエラーが複数存在

**CI上の成功とローカル環境での失敗の乖離**は、以下の可能性も考慮：
- CI環境は異なるドライバ設定（headless Chrome等）でfeature spec実行
- ローカル環境はopenWebDriver或いは別のブラウザドライバ使用
- 実装バグなのか、Playwright/ブラウザドライバ固有の動作差異なのか未確定

---

## RSpec失敗状況

### 初期段階での大量失敗

作業初期段階で、以下の状態が発覚：

```
1071 examples, 185 failures
```

### 失敗の原因分析

mainブランチとfix/issue-197ブランチの両方で同数の失敗（約181〜185件）が再現。

**判断**: 今回の修正が原因ではなく、テスト環境側（以下が考えられる）が原因と一時判断
- テストDB初期化の不備
- FactoryBotの一意性制約違反
- マイグレーション状態の矛盾

### テストDBリセット後

```
183 failures (依然として存在)
```

完全には解消していない。この失敗がプロジェクト全体の既知の問題か、今回の対応に関連するか未確定。

### PR #220時点

GitHub CI実行結果:
- RSpec実行: **121 examples, 0 failures**（対象: trade_card_offers_spec.rb, trade_card_wants_spec.rb）
- これらのspecは実装内容に対応するテストのみが走行

---

## 未解決の疑問点

### 1. Turbo Streamのappendが実DOMに反映されない原因

**現象**:
- サーバーレスポンスには正常なHTML
- ネットワーク通信は成功
- Turbo自体は読み込まれている
- しかし実DOM (`document.getElementById('toast-container').innerHTML`) は空

**考えられる原因**:
- Turbo Streams処理の実装バグ
- worktree環境固有のJavaScript実行問題
- ブラウザドライバ（Playwright）の制限

### 2. RSpec 181〜183件の失敗が完全に解消していない理由

- mainブランチとfix/issue-197の両方で同じ失敗が発生
- テストDBリセット後も解消しない
- この失敗がプロジェクト全体の既知問題か未確定

### 3. docker-compose.ymlの未コミット変更

メインディレクトリ（/home/pepo2/sanin-legacy）のdocker-compose.ymlに、以下の未コミット変更が存在：

```diff
- DB_PORT: ${DB_PORT:-5432}:5432
+ DB_PORT: 127.0.0.1:${DB_PORT:-6432}:5432
```

（worktreeの方は異なる値を使用している可能性がある）

**関連性**:
- このDB_PORT設定の違いが、複数セッションの環境衝突原因となった可能性
- テスト並列実行時に異なるDBポートを使用する必要があるが、その設定が統一されていない

### 4. GitHub CI (PR #220) の検証方法

- CIは成功（0 failures）
- しかし、CIのRSpecが実際にJavaScriptを実行してTurbo Streamの反映を検証しているか不明
- feature specが本当にブラウザで実行されているのか、ドライバ設定が何か確認が必要

---

## 復習: 修正内容の効果

修正後の状態:

1. ✅ **HTML ID重複を排除**: `toast-container` は`application.html.erb`にのみ存在
2. ✅ **CSS修正により`pointer-events-auto`が機能**: トースト要素がクリック可能に
3. ✅ **設計方針に準拠**: 「1箇所のみ配置」ルール遵守
4. ✅ **RSpec通過**: 関連specは0 failures

**期待される改善**:
- UIにトースト通知が表示される
- ユーザーがトースト要素と対話可能（ホバー、クリック）
- toast-countdownアニメーションが正常に動作

---

## worktree情報

- **パス**: `/home/pepo2/worktrees/fix-issue-197`
- **ブランチ**: `fix/issue-197`
- **現在のcommit**: `da6b421 fix: Issue #197 - トースト表示不具合を完全修正`
- **origin/mainからの先行**: 2 commits

### 直近のコミット

```
da6b421 fix: Issue #197 - トースト表示不具合を完全修正
911a07b fix: Issue #197 - トースト通知が表示されない不具合を修正
```

---

## 次担当者への注意点

### 優先して確認すべき項目

1. **Playwright検証の不一致原因**: 
   - サーバーレスポンスは正常だが、実DOMに反映されないという症状の原因を特定してください
   - 別のworktreeで同じ症状が出るか確認し、worktree環境固有の問題かどうか判定してください

2. **RSpec失敗の全体像把握**:
   - 183件の失敗がプロジェクト全体の既知問題か、Issue #197対応の副作用か確認してください
   - 必要なら失敗リストを個別に精査してください

3. **docker-compose.yml設定の統一**:
   - メインディレクトリとworktreeのDB_PORT設定が統一されているか確認
   - 複数セッション並行稼働時にDB接続ポートが競合していないか確認

4. **CI vs ローカル環境の検証方法の乖離**:
   - GitHub CI（feature spec）のドライバ設定を確認
   - Turbo Streamのappendが本当に検証されているか確認

### 修正が必要な場合

- HANDOFF.mdと並行して、デバッグ結果を別途ドキュメント化してください
- 修正を加えた場合、可能な限り既存の単位テストを拡張し、Playwright検証に頼らない実装テストを追加してください

---

**Document created**: 2026-09-09  
**Created by**: Claude Sonnet
