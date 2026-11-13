// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// 明細一覧を morph で並べ替え・絞り込みするとき、利用者が開いている明細（<details open>）を閉じない。
// サーバーは編集した明細しか開いた状態で描けないため、open の付け外しはブラウザ側の状態を優先する
document.addEventListener("turbo:before-morph-attribute", (event) => {
  if (event.target instanceof HTMLDetailsElement && event.detail.attributeName === "open") event.preventDefault()
})
