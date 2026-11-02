import { Controller } from "@hotwired/stimulus"

// 入力を変えたらその場で保存する。代理通販の明細編集で使う。
// change は input の値が確定したとき（チェックボックスは即時、テキストは blur 時）に発火する
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
