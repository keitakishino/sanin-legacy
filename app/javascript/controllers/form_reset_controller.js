import { Controller } from "@hotwired/stimulus"

// Used both for "new record" turbo-frames and for existing-record edit rows.
// On a successful create/update, the server replaces the whole element this
// controller is attached to (the frame, or the row group's <tbody>) with
// freshly rendered markup that is already closed (display: none) by default,
// so no JS is needed to close the form after a submission. This controller
// only needs to handle the client-side-only "cancel" action.
export default class extends Controller {
  connect() {
    this.resetForm()
  }

  resetForm() {
    const form = this.element.querySelector("form")
    if (form) {
      form.reset()
    }

    this.element.style.display = "none"
  }
}
