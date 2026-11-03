import { Controller } from "@hotwired/stimulus"

// サインアップ画面の「メール＆パスワード」フォームの開閉。
export default class extends Controller {
  static targets = ["form"]

  show() {
    this.formTarget.classList.remove("hidden")
  }

  hide() {
    this.formTarget.classList.add("hidden")
  }
}
