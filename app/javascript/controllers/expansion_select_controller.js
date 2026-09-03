import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropdown", "select"]

  connect() {
    this.expansions = []
    this.fetchExpansions()
  }

  async fetchExpansions() {
    try {
      const response = await fetch("/api/expansions")
      this.expansions = await response.json()
    } catch (error) {
      console.error("Failed to fetch expansions:", error)
    }
  }

  search(event) {
    const query = event.target.value.trim().toUpperCase()

    if (query.length === 0) {
      this.dropdownTarget.innerHTML = ""
      this.dropdownTarget.style.display = "none"
      return
    }

    // Filter expansions by prefix match on scryfall_set_code
    const matches = this.expansions.filter(exp =>
      exp.scryfall_set_code.toUpperCase().startsWith(query)
    ).slice(0, 10) // Limit to 10 results

    if (matches.length === 0) {
      this.dropdownTarget.innerHTML = ""
      this.dropdownTarget.style.display = "none"
      return
    }

    // Build dropdown HTML with highlighted matching part
    const html = matches.map(exp => {
      const highlighted = exp.scryfall_set_code.substring(0, query.length)
      const rest = exp.scryfall_set_code.substring(query.length)
      const display = `<span class="font-bold text-accent">${highlighted}</span>${rest}`
      const label = exp.name_ja ? `${display} — ${exp.name_ja}` : `${display} — ${exp.name}`

      return `
        <div class="px-4 py-2 cursor-pointer hover:bg-neutral-soft border-b border-stone-200 last:border-b-0"
             data-expansion-id="${exp.id}"
             data-expansion-code="${exp.scryfall_set_code}">
          ${label}
        </div>
      `
    }).join("")

    this.dropdownTarget.classList.add("shadow-lg")
    this.dropdownTarget.innerHTML = html
    this.dropdownTarget.style.display = "block"

    // Add click handlers to dropdown items
    this.dropdownTarget.querySelectorAll("[data-expansion-id]").forEach(item => {
      item.addEventListener("click", (e) => this.selectExpansion(e))
    })
  }

  selectExpansion(event) {
    const item = event.currentTarget
    const expansionId = item.dataset.expansionId
    const expansionCode = item.dataset.expansionCode

    this.selectTarget.value = expansionId
    this.inputTarget.value = expansionCode
    this.dropdownTarget.style.display = "none"
  }

  hideDropdown() {
    // Hide dropdown when clicking outside (after a short delay to allow selection)
    setTimeout(() => {
      this.dropdownTarget.style.display = "none"
    }, 100)
  }
}
