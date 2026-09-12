import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { frameId: String }

  // This connect() hook is automatically called by Stimulus when the controller element
  // is inserted into the DOM via turbo_stream.replace
  // This happens AFTER the turbo-stream processing is complete
  connect() {
    if (!this.frameIdValue) return

    const frame = document.getElementById(this.frameIdValue)
    if (!frame) return

    // Find the form within the frame
    const form = frame.querySelector("form")
    if (form) {
      // Reset the form to clear all user-entered values
      form.reset()
    }

    // Hide the frame after form submission success
    frame.style.display = "none"
  }
}
