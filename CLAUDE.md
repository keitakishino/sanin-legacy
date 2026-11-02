# sanin-legacy

## CSS（最重要）

**Tailwind CSS v4 だけを使う。daisyUI も Bootstrap も入っていない。**

`card` / `card-body` / `card-title` / `btn` / `btn-primary` / `btn-sm` / `input` / `input-bordered` /
`select-bordered` / `alert` / `alert-error` / `alert-info` / `divider` / `form-control` / `badge` /
`table` / `table-compact` / `link-primary` / `checkbox` / `label-text` / `bg-base-100` / `bg-base-200` /
`border-base-300` / `bg-primary` / `text-primary-content` / `text-error` は **daisyUI のクラスで、何も描画されない**。
これらを書くと、余白だけ効いて枠線もボタンの見た目も出ない画面ができる（2026-11-02 に代理通販の 7 画面で実際に起きた）。

新しい画面を書くときは、**既存のビューから class 属性をコピーする**こと。
色は `app/assets/tailwind/application.css` の `@theme` にあるトークン
（`accent` / `accent-hover` / `accent-soft` / `border` / `surface` / `danger` / `success` / `warning` …）と、
Tailwind 既定の `stone` / `indigo` / `red` / `amber` を使う。
`primary` / `secondary` / `base-100` / `error` / `info` は**定義されていない**。

管理画面でよく使う形:

| 用途 | class |
|---|---|
| ページ背景 | `bg-stone-50 py-8` |
| 見出し | `text-3xl font-bold text-stone-800` |
| パネル | `bg-white border border-stone-200 rounded-lg`（中身は `p-6`） |
| パネル内の小ブロック | `bg-stone-50 border border-stone-200 rounded-md p-4` |
| ラベル | `block text-xs font-bold text-stone-500 mb-1` |
| 入力欄・select | `w-full px-3 py-2 border border-stone-300 rounded-md text-xs focus:outline-none focus:ring-2 focus:ring-accent` |
| 主ボタン | `bg-indigo-700 text-white px-4 py-2 rounded hover:bg-indigo-800 font-medium text-sm` |
| 副ボタン | `px-3 py-1.5 bg-white text-stone-800 border border-stone-300 rounded-md hover:bg-stone-50 font-bold text-xs` |
| 破壊的ボタン | `px-3 py-1.5 bg-white text-red-700 border border-red-300 rounded-md hover:bg-red-50 font-bold text-xs` |
| エラー枠 | `bg-red-50 border border-red-200 rounded-lg p-4 mb-4`（中の `ul` は `list-disc list-inside space-y-1 text-red-700 text-sm`） |
| テーブル | `table` は `w-full`、`thead` は `bg-stone-100 border-b border-stone-200`、`th` は `px-6 py-3 text-left text-xs font-bold text-stone-500` |

ビルド結果 `app/assets/builds/tailwind.css` は gitignore されている。クラスを足したら
`docker compose exec -T -e RAILS_ENV=test app bin/rails tailwindcss:build` を実行する。

トースト（フラッシュ）は自分で div を書かない。`#toast-container` はレイアウトにあるので画面側では作らず、
`turbo_stream.append "toast-container"` の中で共通パーシャルを使う:

```erb
<%= render(partial: "shared/toast", locals: { message: "保存しました", variant: :danger }, formats: [:html]) %>
```

## i18n

ユーザーに見える文言は i18n に置く。属性名は `config/locales/{ja,en}.yml` の
**`activerecord.attributes.<モデル名>`** に書く（`activerecord.enums` の下ではない）。
ja 側に無いと en にフォールバックし、`t()` は日本語のまま `f.label` と `errors.full_messages` だけ英語になる。
「画面の一部だけ英語」になったら locale 設定ではなく YAML の階層を疑う。

## テスト

- system spec では `click_button` の直後に必ず `have_current_path` か成功フラッシュの `have_text` を置く。
  Capybara は遷移や Turbo の完了を待たないので、すぐ `reload` や `Capybara.reset_sessions!` をすると不安定になる。
- `dom_id(record, prefix)` は `prefix_モデル名_id` の順（先頭にアンダースコアは付かない）。
  CSS セレクタは推測せず、ビューの `dom_id` を読んで確かめる。
- コンテナで rspec を回すときは必ずテスト用 DB を明示する。省くと開発用 DB のデータが消える:

```
docker compose exec -T -e RAILS_ENV=test \
  -e DATABASE_URL=postgresql://sanin_legacy:development_password@db:5432/sanin_legacy_test \
  app bundle exec rspec <パス>
```
