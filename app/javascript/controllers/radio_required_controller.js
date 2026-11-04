import { Controller } from "@hotwired/stimulus"

// ラジオが 1 つも選ばれていない間は送信ボタンを押せなくする。
// もとはフォームの onchange に直接書いていたが、インラインのイベントハンドラは
// CSP（script-src-attr）で実行できないため Stimulus に寄せている。
//
//   <form data-controller="radio-required"
//         data-action="change->radio-required#refresh"
//         data-radio-required-name-value="guest_name_key">
//     <input type="radio" name="guest_name_key" ...>
//     <input type="submit" data-radio-required-target="submit" disabled>
export default class extends Controller {
  static targets = ["submit"]
  static values = { name: String }

  connect() {
    this.refresh()
  }

  refresh() {
    if (!this.hasSubmitTarget) return

    const checked = this.element.querySelector(`input[name="${this.nameValue}"]:checked`)
    this.submitTarget.disabled = !checked
  }
}
