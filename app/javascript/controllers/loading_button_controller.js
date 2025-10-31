import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.originalHTML = null
  }

  start() {
    if (!this.hasButtonTarget || this.buttonTarget.disabled) return
    this.originalHTML = this.buttonTarget.innerHTML
    this.buttonTarget.disabled = true
    this.buttonTarget.classList.add("opacity-80")
    this.buttonTarget.innerHTML = '<span class="h-4 w-4 animate-spin rounded-full border-2 border-white/60 border-t-transparent"></span><span>Processing…</span>'
  }

  stop(event) {
    if (!this.hasButtonTarget) return
    if (event.detail.success) {
      // Successful requests will replace the button via Turbo stream
      return
    }
    this.reset()
  }

  reset() {
    if (!this.hasButtonTarget) return
    this.buttonTarget.disabled = false
    this.buttonTarget.classList.remove("opacity-80")
    if (this.originalHTML) {
      this.buttonTarget.innerHTML = this.originalHTML
    }
  }
}
