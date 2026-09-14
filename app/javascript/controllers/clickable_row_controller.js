import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  click(event) {
    const clickedElement = event.target.closest("a, button")

    // リンク・ボタンは通常の遷移に任せるが、
    // このtrコントローラのハンドラでは処理しない（伝播も止める）
    if (clickedElement) {
      event.stopPropagation()
      return
    }

    // 行タップで遷移する場合も、イベント伝播を止める
    event.stopPropagation()
    if (this.element.dataset.url) {
      Turbo.visit(this.element.dataset.url)
    }
  }
}
