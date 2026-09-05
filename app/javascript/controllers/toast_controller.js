import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    let duration = parseInt(this.element.dataset.toastDuration || 4000)
    // Clamp duration to valid range (100ms to 60 seconds)
    duration = Math.max(100, Math.min(duration, 60000))
    this.timeoutId = setTimeout(() => this.remove(), duration)
  }

  close(event) {
    event.preventDefault()
    this.remove()
  }

  remove() {
    if (this.timeoutId) clearTimeout(this.timeoutId)
    // Fade out with opacity transition, then remove DOM element
    this.element.style.opacity = "0"
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }

  disconnect() {
    if (this.timeoutId) clearTimeout(this.timeoutId)
  }
}
