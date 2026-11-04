import { Controller } from "@hotwired/stimulus"

// turbo-frame に載せたモーダルを閉じる（フレームの中身を空にする）。
// もとはボタンの onclick に直接書かれていたが、インラインのイベントハンドラは
// CSP（script-src-attr）で実行できないため Stimulus に寄せている。
//
//   <button type="button"
//           data-controller="modal"
//           data-modal-frame-value="event_modal"
//           data-action="click->modal#close">
export default class extends Controller {
  static values = { frame: String }

  close() {
    const frame = document.getElementById(this.frameValue)
    if (frame) frame.innerHTML = ""
  }
}
