import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const duration = parseInt(this.element.dataset.toastDuration || 4000)
    this.timeoutId = setTimeout(() => this.remove(), duration)
  }

  close(event) {
    event.preventDefault()
    this.remove()
  }

  remove() {
    if (this.timeoutId) clearTimeout(this.timeoutId)
    this.element.remove()
  }

  disconnect() {
    if (this.timeoutId) clearTimeout(this.timeoutId)
  }
}
