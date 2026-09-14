import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  click(event) {
    const clickedElement = event.target.closest("a, button")

    // リンク・ボタンのクリックは通常の遷移に任せ、行タップ処理は行わない
    if (clickedElement) {
      return
    }

    if (this.element.dataset.url) {
      Turbo.visit(this.element.dataset.url)
    }
  }
}
