import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Initial reset and collapse when controller is first connected
    this.resetForm()

    // Listen for turbo-frame replacements
    // turbo:before-frame-render fires before the frame is replaced
    // We use setTimeout(..., 0) to ensure resetForm runs AFTER the replacement is complete
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
