import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "input",
    "combobox",
    "list",
    "tag",
    "tagLabel",
    "tagKind",
    "hiddenParticipantId",
    "hiddenUserId",
    "hiddenGuestName",
    "submit"
  ]
  static values = { candidates: Array, itemId: Number, labels: Object, conflicts: Object }

  connect() {
    this.options = []
    this.activeIndex = -1
    this.hideTimer = null
  }

  disconnect() {
    if (this.hideTimer) {
      clearTimeout(this.hideTimer)
    }
  }

  // ProxyOrderParticipant.normalize_name（NFKC → strip → downcase）と同じ規則。変えるときは両方そろえる
  normalize(s) {
    return String(s ?? "").normalize("NFKC").trim().toLowerCase()
  }

  guestConflictReason(rawValue) {
    const q = this.normalize(rawValue)
    const usernames = this.conflictsValue.usernames || []
    const guestNames = this.conflictsValue.guest_names || []

    // ユーザー名との衝突を確認
    const conflictingUsername = usernames.find(u => this.normalize(u) === q)
    if (conflictingUsername) {
      return this.labelsValue.conflictWithUsername.replace("%{name}", conflictingUsername)
    }

    // ゲスト名との衝突を確認
    if (guestNames.some(g => this.normalize(g) === q)) {
      return this.labelsValue.conflictWithGuest
    }

    return null
  }

  filter(event) {
    const input = this.normalize(event.target.value)

    if (input.length === 0) {
      this.closeList()
      return
    }

    const q = input
    const participants = this.candidatesValue.filter(
      (c) => c.kind === "participant" && this.normalize(c.label).includes(q)
    )
    const users = this.candidatesValue.filter(
      (c) => c.kind === "user" && this.normalize(c.label).includes(q)
    )

    this.listTarget.innerHTML = ""
    this.options = []
    this.activeIndex = -1

    // 参加者セクション
    if (participants.length > 0) {
      const header = document.createElement("li")
      header.setAttribute("role", "presentation")
      header.className = "px-3 pt-2 pb-1 text-[11px] font-bold text-stone-400"
      header.textContent = this.labelsValue.sectionParticipants
      this.listTarget.appendChild(header)

      participants.forEach((candidate, idx) => {
        this.appendOption(candidate, idx, participants.length + users.length + 1)
      })
    }

    // ユーザーセクション
    if (users.length > 0) {
      const header = document.createElement("li")
      header.setAttribute("role", "presentation")
      header.className = "px-3 pt-2 pb-1 text-[11px] font-bold text-stone-400"
      header.textContent = this.labelsValue.sectionUsers
      this.listTarget.appendChild(header)

      users.forEach((candidate, idx) => {
        this.appendOption(candidate, participants.length + idx, participants.length + users.length + 1)
      })
    }

    // 一致なしメッセージ
    if (participants.length === 0 && users.length === 0) {
      const noMatch = document.createElement("li")
      noMatch.setAttribute("role", "presentation")
      noMatch.setAttribute("data-role", "no-match")
      noMatch.className = "px-3 py-2 text-stone-500"
      noMatch.textContent = this.labelsValue.noMatch
      this.listTarget.appendChild(noMatch)
    }

    // ゲスト行（常に最後）
    const guestLabel = event.target.value.trim()
    const guestCandidate = {
      kind: "guest",
      label: guestLabel,
      disabled_reason: this.guestConflictReason(event.target.value)
    }
    this.appendOption(guestCandidate, this.options.length, this.options.length + 1)

    this.listTarget.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  appendOption(candidate, idx, total) {
    const li = document.createElement("li")
    li.setAttribute("role", "option")
    li.id = `${this.listTarget.id}-opt-${idx}`
    li.className = "flex items-center justify-between gap-2 min-h-11 px-3 py-2 cursor-pointer hover:bg-stone-50"

    let disabledReason = null
    if (candidate.kind === "participant" && candidate.assigned_item_ids.includes(this.itemIdValue)) {
      disabledReason = this.labelsValue.alreadyInItem
    } else if (candidate.kind === "guest" && candidate.disabled_reason) {
      disabledReason = candidate.disabled_reason
    }

    const isDisabled = disabledReason !== null

    if (isDisabled) {
      li.setAttribute("aria-disabled", "true")
      li.className = "flex items-center justify-between gap-2 min-h-11 px-3 py-2 text-stone-400 cursor-not-allowed"
    }

    // 左側：名前
    const label = document.createElement("span")
    let displayText
    if (candidate.kind === "guest") {
      displayText = this.labelsValue.addAsGuest.replace("%{name}", candidate.label)
    } else {
      displayText = candidate.label
    }
    label.textContent = displayText
    li.appendChild(label)

    // 右側：種別ラベルと理由
    const rightContainer = document.createElement("span")
    rightContainer.className = "flex items-center gap-2"

    if (disabledReason) {
      const reason = document.createElement("span")
      reason.setAttribute("data-role", "disabled-reason")
      reason.className = "text-[10px] text-stone-400"
      reason.textContent = disabledReason
      rightContainer.appendChild(reason)
    }

    const kindLabel = document.createElement("span")
    kindLabel.className = "flex-none text-[11px] font-bold rounded px-1.5 py-0.5 bg-white text-accent"
    if (candidate.kind === "participant") {
      kindLabel.textContent = candidate.user_id ? this.labelsValue.kindRegistered : this.labelsValue.kindGuest
    } else if (candidate.kind === "user") {
      kindLabel.textContent = this.labelsValue.kindRegistered
    } else if (candidate.kind === "guest") {
      kindLabel.textContent = this.labelsValue.kindGuest
    }
    rightContainer.appendChild(kindLabel)

    li.appendChild(rightContainer)

    if (!isDisabled) {
      li.addEventListener("mousedown", (e) => e.preventDefault())
      li.addEventListener("click", () => this.select(candidate))
    }

    this.listTarget.appendChild(li)
    this.options.push({ el: li, candidate, disabled: isDisabled })
  }

  keydown(event) {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      if (this.listTarget.hidden) return

      event.preventDefault()
      const direction = event.key === "ArrowDown" ? 1 : -1
      let nextIndex = this.activeIndex + direction

      // 最初か最後に到達したら止める
      if (nextIndex < 0) nextIndex = 0
      if (nextIndex >= this.options.length) nextIndex = this.options.length - 1

      // disabled な要素をスキップ
      while (nextIndex >= 0 && nextIndex < this.options.length && this.options[nextIndex].disabled) {
        nextIndex += direction
      }

      // 範囲内なら更新
      if (nextIndex >= 0 && nextIndex < this.options.length) {
        this.setActive(nextIndex)
      }
    } else if (event.key === "Enter") {
      event.preventDefault()
      if (!this.listTarget.hidden && this.activeIndex >= 0) {
        const option = this.options[this.activeIndex]
        if (!option.disabled) {
          this.select(option.candidate)
        }
      }
    } else if (event.key === "Escape") {
      this.closeList()
    }
  }

  setActive(idx) {
    this.options.forEach((opt, i) => {
      if (i === idx) {
        opt.el.classList.add("bg-accent-soft")
        opt.el.setAttribute("aria-selected", "true")
      } else {
        opt.el.classList.remove("bg-accent-soft")
        opt.el.removeAttribute("aria-selected")
      }
    })
    this.activeIndex = idx
    const activeEl = this.options[idx]?.el
    if (activeEl) {
      this.inputTarget.setAttribute("aria-activedescendant", activeEl.id)
      activeEl.scrollIntoView({ block: "nearest" })
    }
  }

  hideList() {
    if (this.hideTimer) {
      clearTimeout(this.hideTimer)
    }
    this.hideTimer = setTimeout(() => {
      this.closeList()
    }, 100)
  }

  closeList() {
    this.listTarget.hidden = true
    this.listTarget.innerHTML = ""
    this.options = []
    this.activeIndex = -1
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
  }

  select(candidate) {
    // hidden フィールドをリセット
    this.hiddenParticipantIdTarget.value = ""
    this.hiddenUserIdTarget.value = ""
    this.hiddenGuestNameTarget.value = ""

    // 候補の種別に応じて hidden フィールドを設定
    if (candidate.kind === "participant") {
      this.hiddenParticipantIdTarget.value = candidate.participant_id
    } else if (candidate.kind === "user") {
      this.hiddenUserIdTarget.value = candidate.user_id
    } else if (candidate.kind === "guest") {
      this.hiddenGuestNameTarget.value = candidate.label
    }

    // タグに候補情報を表示
    this.tagLabelTarget.textContent = candidate.label
    let kindText
    if (candidate.kind === "participant") {
      kindText = candidate.user_id ? this.labelsValue.kindRegistered : this.labelsValue.kindGuest
    } else if (candidate.kind === "user") {
      kindText = this.labelsValue.kindRegistered
    } else if (candidate.kind === "guest") {
      kindText = this.labelsValue.kindGuest
    }
    this.tagKindTarget.textContent = kindText

    // コンボボックス入力欄を非表示、タグを表示
    this.comboboxTarget.hidden = true
    this.tagTarget.hidden = false

    // 送信ボタンを有効化
    this.submitTarget.disabled = false

    this.closeList()
  }

  pick(event) {
    let button = event.currentTarget || event.target

    // If click event happened on a child element, find the button
    while (button && button.tagName !== "BUTTON") {
      button = button.parentElement
    }

    if (!button || !button.dataset.participantId) {
      return
    }

    const participantId = parseInt(button.dataset.participantId, 10)
    const candidate = this.candidatesValue.find(
      (c) => c.kind === "participant" && c.participant_id === participantId
    )

    if (candidate) {
      this.select(candidate)
    }
  }

  clear() {
    this.hiddenParticipantIdTarget.value = ""
    this.hiddenUserIdTarget.value = ""
    this.hiddenGuestNameTarget.value = ""
    this.inputTarget.value = ""
    this.tagTarget.hidden = true
    this.comboboxTarget.hidden = false
    this.submitTarget.disabled = true
    this.inputTarget.focus()
  }
}
