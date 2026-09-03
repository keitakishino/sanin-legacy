import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "frame", "select"]

  connect() {
    this.debounceTimer = null
    this.frameTarget.addEventListener("turbo:load", () => this.attachDropdownHandlers())
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  search(event) {
    const query = event.target.value.trim()

    // Clear previous debounce timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    // If input is empty, clear frame src and hide dropdown
    if (query.length === 0) {
      this.frameTarget.src = ""
      return
    }

    // Debounce API request by 300ms
    this.debounceTimer = setTimeout(() => {
      this.frameTarget.src = `/expansions?q=${encodeURIComponent(query)}`
    }, 300)
  }

  attachDropdownHandlers() {
    this.frameTarget.querySelectorAll("[data-expansion-code]").forEach(item => {
      item.addEventListener("click", (e) => this.selectExpansion(e))
    })
  }

  selectExpansion(event) {
    const item = event.currentTarget
    const expansionId = item.dataset.expansionId
    const expansionCode = item.dataset.expansionCode

    this.selectTarget.value = expansionId
    this.inputTarget.value = expansionCode
    this.frameTarget.src = ""
  }

  hideDropdown() {
    this.frameTarget.src = ""
  }
}
