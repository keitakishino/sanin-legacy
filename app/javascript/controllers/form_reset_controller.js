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
    // turbo:before-frame-render イベント仕様（Turbo 8.x確認）:
    // - Turboのソースコード: @hotwired/turbo/src/elements/frame_element.ts
    // - ディスパッチ箇所: FrameElement.prototype.render() メソッド内（フレーム置き換え前）
    // - event.target: 実際のフレーム置き換えを行うturbo-frame要素そのもの
    // - bubbles: true（親要素へのバブリング対応）
    // - イベント伝播：nested turbo-frameが更新された場合、そのフレーム要素で発火し、
    //   親要素のリスナーにもバブリングして到達する
    //
    // Issue #259: 入れ子フレーム（expansion_suggestions）の更新時に親フォーム
    // （new_trade_card_offer/new_trade_card_want）が誤ってリセットされる問題への対策
    // - event.target === this.element の判定でフィルタリング
    // - この判定により、実際に置き換え対象のフレーム（自フレーム）でのみリセット処理を実行
    // - 親フレームに到達したバブリングイベントは、event.targetが子フレームのため無視される
    //
    // setTimeout(..., 0) により、フレームの置き換え処理が完了した後にリセット処理が
    // 実行されるようにしている。
    //
    // disconnect() でリスナーを明示的に解除し、同一フレーム内での複数回接続による
    // イベントリスナーの重複登録およびメモリリークを防止する。
    this.handleFrameRender = (event) => {
      // Issue #259対応: 自分自身の要素での turbo:before-frame-render のみを処理
      // event.target === this.element により、実際にこのコントローラーがアタッチされた
      // フレーム要素での置き換えだけを検出し、入れ子フレーム（例: expansion_suggestions）
      // でのイベント発火を無視する。これにより、入れ子フレーム更新時に親フォームが
      // 誤ってリセットされるのを防止する。
      if (event.target === this.element) {
        setTimeout(() => this.resetForm(), 0)
      }
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
    // Find the form within the element and reset it
    const form = this.element.querySelector("form")
    if (form) {
      // Reset the form to clear all user-entered values
      form.reset()
    }

    // Hide the element regardless of its type (TR, turbo-frame, or similar inline element)
    this.element.style.display = "none"
  }
}
