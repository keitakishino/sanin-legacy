import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // This connect() hook is automatically called by Stimulus when the controller element
  // is inserted into the DOM via turbo_stream.replace
  // This happens AFTER the turbo-stream processing is complete
  connect() {
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
