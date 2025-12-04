import { Controller } from "@hotwired/stimulus"

// Handles closing the pet action panel via overlay clicks or keyboard shortcuts
// and broadcasts preview data so other controllers can react.
export default class extends Controller {
  static targets = ["cancelForm"]
  static values = {
    preview: String,
    state: String,
    autoclose: Boolean
  }

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
    this.dispatchPreview()

    if (this.shouldAutoclose()) {
      this.startAutoclose()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
    this.dispatch("preview", { detail: { preview: [], state: "idle" }, bubbles: true })
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.submitCancel()
    }
  }

  submitCancel(event) {
    if (event) {
      event.preventDefault()
    }
    if (this.hasCancelFormTarget) {
      this.cancelFormTarget.requestSubmit()
    }
  }

  dispatchPreview() {
    const state = this.hasStateValue ? this.stateValue : this.element.dataset.state || "idle"
    let preview = []

    const raw = this.hasPreviewValue ? this.previewValue : this.element.dataset.preview
    if (raw && raw.length > 0) {
      try {
        preview = JSON.parse(raw)
      } catch (error) {
        preview = []
      }
    }

    const energyBefore = this.readNumber(this.element.dataset.actionPanelEnergyBeforeValue)
    const energyAfter = this.readNumber(this.element.dataset.actionPanelEnergyAfterValue)
    const xpBefore = this.readNumber(this.element.dataset.actionPanelXpBeforeValue)
    const xpAfter = this.readNumber(this.element.dataset.actionPanelXpAfterValue)
    const xpGain = this.readNumber(this.element.dataset.actionPanelXpGainValue)

    let needsAfter = []
    const needsRaw = this.element.dataset.actionPanelNeedsAfterValue
    if (needsRaw && needsRaw.length > 0) {
      try {
        needsAfter = JSON.parse(needsRaw)
      } catch (error) {
        needsAfter = []
      }
    }

    this.dispatch("preview", {
      detail: {
        preview,
        state,
        energy: { before: energyBefore, after: energyAfter },
        xp: { before: xpBefore, after: xpAfter, gain: xpGain },
        needsAfter
      },
      bubbles: true
    })
  }

  shouldAutoclose() {
    const state = this.hasStateValue ? this.stateValue : this.element.dataset.state
    return state === "success" && this.autocloseValue === true
  }

  startAutoclose() {
    clearTimeout(this.autocloseTimer)
    this.autocloseTimer = setTimeout(() => {
      this.element.classList.add("is-fading")
      this.element.style.transition = "opacity 0.4s ease"
      this.element.style.opacity = "0"
      setTimeout(() => {
        this.element.innerHTML = ""
      }, 450)
    }, 1800)
  }

  readNumber(value) {
    const num = Number(value)
    return Number.isFinite(num) ? num : 0
  }
}
