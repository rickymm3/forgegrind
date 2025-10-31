import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["requestUuid", "submit"]

  handleSubmit(event) {
    this.setRequestUuid()
    this.toggleButtons(true)
  }

  handleSubmitEnd() {
    this.toggleButtons(false)
  }

  setRequestUuid() {
    if (!this.hasRequestUuidTarget) return
    const uuid = generateUuid()
    this.requestUuidTarget.value = uuid
  }

  toggleButtons(disabled) {
    if (!this.hasSubmitTarget) return
    this.submitTargets.forEach((button) => {
      button.disabled = disabled
      button.classList.toggle("opacity-50", disabled)
      button.classList.toggle("cursor-not-allowed", disabled)
    })
  }
}

function generateUuid() {
  if (window.crypto && typeof window.crypto.randomUUID === "function") {
    return window.crypto.randomUUID()
  }
  // Fallback RFC4122 v4-ish UUID
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (c) {
    const r = (Math.random() * 16) | 0
    const v = c === "x" ? r : (r & 0x3) | 0x8
    return v.toString(16)
  })
}
