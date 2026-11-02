import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "frame", "select"]

  connect() {
    this.debounceTimer = null
    this.hideDropdownTimer = null
    this.handleMouseDown = this.handleMouseDown.bind(this)
    this.frameTarget.addEventListener("mousedown", this.handleMouseDown)
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    if (this.hideDropdownTimer) {
      clearTimeout(this.hideDropdownTimer)
    }
    this.frameTarget.removeEventListener("mousedown", this.handleMouseDown)
  }

  handleMouseDown(event) {
    event.preventDefault()
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
      this.frameTarget.style.display = "none"
      return
    }

    // Debounce API request by 300ms
    this.debounceTimer = setTimeout(() => {
      this.frameTarget.src = `/expansions?q=${encodeURIComponent(query)}&frame=${encodeURIComponent(this.frameTarget.id)}`
      this.frameTarget.style.display = "block"
    }, 300)
  }

  selectExpansion(event) {
    event.stopPropagation()
    const item = event.currentTarget
    const expansionId = item.dataset.expansionId
    const expansionCode = item.dataset.expansionCode

    this.selectTarget.value = expansionId
    this.inputTarget.value = expansionCode
    this.frameTarget.src = ""
    this.frameTarget.style.display = "none"
    this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  stopChange(event) {
    event.stopPropagation()
  }

  hideDropdown() {
    // 遅延実行により、click イベント（selectExpansion）の完了を保証
    // blur イベント発火前に selectExpansion が実行されるようにする
    if (this.hideDropdownTimer) {
      clearTimeout(this.hideDropdownTimer)
    }

    this.hideDropdownTimer = setTimeout(() => {
      this.frameTarget.src = ""
      this.frameTarget.style.display = "none"
    }, 100)
  }
}
