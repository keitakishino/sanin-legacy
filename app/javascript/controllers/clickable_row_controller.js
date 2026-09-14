import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  click(event) {
    // セル内のリンク要素のクリックは行遷移を無視
    if (event.target.closest("a, button")) {
      return
    }

    if (this.element.dataset.url) {
      Turbo.visit(this.element.dataset.url)
    }
  }
}
