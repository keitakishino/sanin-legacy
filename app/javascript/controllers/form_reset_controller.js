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
    // 当該turbo-frame要素で発火する。このイベントはバブリングするため、親要素のリスナーも
    // 反応する可能性がある。子要素のフレーム置き換え（例：expansion_suggestions）を
    // 誤検知しないよう、id 属性による明確なマッチングを用いる。
    // 以下の2つのケースに対応する：
    //   1. 新規フォーム: this.element = turbo-frame 自体
    //      → form_reset コントローラーが turbo-frame に直接接続されている
    //   2. 編集フォーム: this.element = TR 要素
    //      → form_reset コントローラーが TR に接続されている
    //
    // 両ケースとも、フレーム置き換え時のイベント発火元 (target) の id を確認し、
    // 初期化時に記録しておいた expectedFrameId と一致する場合のみ resetForm() を実行する。
    // これにより、入れ子の expansion_suggestions フレーム更新などを誤検知しない。
    //
    // setTimeout(..., 0) により、フレームの置き換え処理が完了した後にリセット処理が
    // 実行されるようにしている。
    //
    // disconnect() でリスナーを明示的に解除し、同一フレーム内での複数回接続による
    // イベントリスナーの重複登録およびメモリリークを防止する。

    // Determine the expected frame to listen for
    // Case 1: If this.element is itself a turbo-frame, use its id
    // Case 2: If this.element is a parent (e.g., TR), find the turbo-frame descendant
    //
    // In the edit form case, the structure is:
    //   <tr data-controller="form-reset">
    //     <td colspan="12">
    //       <turbo-frame id="...edit_form_frame">  ← this is what we need (descendant, not direct child)
    //         <form>
    //           <div data-controller="expansion-select">
    //             <turbo-frame id="expansion_suggestions">  ← nested, ignored
    //
    // querySelector('turbo-frame') finds descendants in document order,
    // so it will find the main edit_form_frame before any nested expansion_suggestions.
    let expectedFrameId = null
    if (this.element.tagName === 'TURBO-FRAME') {
      expectedFrameId = this.element.id
    } else {
      const frameElement = this.element.querySelector('turbo-frame')
      expectedFrameId = frameElement?.id
    }

    this.handleFrameRender = (event) => {
      const target = event.composedPath()[0]
      // Only reset if the event target matches our expected frame
      if (expectedFrameId && target?.id === expectedFrameId) {
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
