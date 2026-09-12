import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Initial reset and collapse when controller is first connected
    this.resetForm()

    // Turbo 8.x の既知の挙動への対応:
    // turbo_stream.replace で同一IDのturbo-frameを置き換える際、Stimulusコントローラーの
    // connect() が新しい要素に対して再実行されないことがある。
    // そのため、置き換え前の要素に turbo:before-frame-render リスナーを登録しておき、
    // フレーム置き換え時にも resetForm() が確実に実行されるようにしている。
    //
    // turbo:before-frame-render イベントは、turbo-frameが新しいコンテンツで置き換わる直前に
    // 当該turbo-frame要素で発火する。setTimeout(..., 0) により、フレームの置き換え処理が
    // 完了した後にリセット処理が実行されるようにしている。
    //
    // disconnect() でリスナーを明示的に解除し、同一フレーム内での複数回接続による
    // イベントリスナーの重複登録およびメモリリークを防止する。
    this.handleFrameRender = () => {
      setTimeout(() => this.resetForm(), 0)
    }
    this.element.addEventListener("turbo:before-frame-render", this.handleFrameRender)
  }

  disconnect() {
    // Clean up event listener to prevent memory leaks and multiple registrations
    if (this.handleFrameRender) {
      this.element.removeEventListener("turbo:before-frame-render", this.handleFrameRender)
    }
  }

  resetForm() {
    // Find the form within the frame (this.element is the turbo-frame itself)
    const form = this.element.querySelector("form")
    if (form) {
      // Reset the form to clear all user-entered values
      form.reset()
    }

    // Hide the frame after form submission success
    this.element.style.display = "none"
  }
}
