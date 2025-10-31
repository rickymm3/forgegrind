import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    unlockAt: Number
  }

  static targets = ["button", "message"]

  connect() {
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    const now = Math.floor(Date.now() / 1000)
    const remaining = Math.max(0, this.unlockAtValue - now)

    if (remaining <= 0) {
      this.enableButton()
    } else {
      this.disableButton(remaining)
    }
  }

  disableButton(remaining) {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
    }
    if (this.hasMessageTarget) {
      this.messageTarget.textContent = `Next scout available in ${this.formatTime(remaining)}`
    }
  }

  enableButton() {
    clearInterval(this.timer)
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = false
    }
    if (this.hasMessageTarget) {
      this.messageTarget.textContent = ""
    }
  }

  formatTime(seconds) {
    const minutes = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${minutes}:${secs.toString().padStart(2, "0")}`
  }
}
