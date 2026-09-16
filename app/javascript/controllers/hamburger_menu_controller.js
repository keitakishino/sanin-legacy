import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon", "drawer"]

  connect() {
    this.isOpen = false
    this.element.setAttribute("aria-expanded", "false")

    // Event listener for closing the menu when clicking outside
    this.handleOutsideClick = (e) => this.handleClickOutside(e)
    document.addEventListener("click", this.handleOutsideClick)

    // Event listener for keyboard (Escape key)
    this.handleKeyDown = (e) => this.handleEscapeKey(e)
    document.addEventListener("keydown", this.handleKeyDown)

    // Reset menu state when page is navigated (turbo:before-frame-render)
    this.handleBeforeFrameRender = () => {
      // Use setTimeout to ensure the close happens after frame render completes
      setTimeout(() => this.close(), 0)
    }
    document.addEventListener("turbo:before-frame-render", this.handleBeforeFrameRender)
  }

  disconnect() {
    // Clean up all event listeners to prevent memory leaks
    if (this.handleOutsideClick) {
      document.removeEventListener("click", this.handleOutsideClick)
    }
    if (this.handleKeyDown) {
      document.removeEventListener("keydown", this.handleKeyDown)
    }
    if (this.handleBeforeFrameRender) {
      document.removeEventListener("turbo:before-frame-render", this.handleBeforeFrameRender)
    }
  }

  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.isOpen = true
    this.drawerTarget.classList.remove("hidden")
    this.drawerTarget.setAttribute("aria-hidden", "false")
    this.element.setAttribute("aria-expanded", "true")
    this.iconTarget.setAttribute("aria-label", "メニューを閉じる")
  }

  close() {
    this.isOpen = false
    this.drawerTarget.classList.add("hidden")
    this.drawerTarget.setAttribute("aria-hidden", "true")
    this.element.setAttribute("aria-expanded", "false")
    this.iconTarget.setAttribute("aria-label", "メニューを開く")
  }

  handleClickOutside(event) {
    // Close menu if click is outside the header
    if (!this.element.contains(event.target) && this.isOpen) {
      this.close()
    }
  }

  handleEscapeKey(event) {
    if (event.key === "Escape" && this.isOpen) {
      this.close()
    }
  }
}
