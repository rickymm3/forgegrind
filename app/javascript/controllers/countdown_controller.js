// app/javascript/controllers/countdown_controller.js

import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Expose Turbo globally so renderStreamMessage works
window.Turbo = Turbo

export default class extends Controller {
  static values = { seconds: Number }
  static targets = ["container", "output"]

  connect() {
    this.endTime = Date.now() + this.secondsValue * 1000
    this.userExplorationId = this.element.dataset.userExplorationId

    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    const remaining = Math.max(0, Math.floor((this.endTime - Date.now()) / 1000))
    this.outputTarget.textContent = this.formatTime(remaining)

    if (remaining <= 0) {
      clearInterval(this.timer)
      this.handleCompletion()
    }
  }

  handleCompletion() {
    if (this.userExplorationId) {
      // Instead of auto‐completing, request “ready” partial
      fetch(`/user_explorations/${this.userExplorationId}/ready`, {
        method: "GET",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        }
      })
        .then(response => response.text())
        .then(html => Turbo.renderStreamMessage(html))
        .catch(err => console.error("ready_exploration failed:", err))
    } else {
      console.warn("Countdown finished but no exploration ID found.")
    }
  }

  formatTime(seconds) {
    const m = Math.floor(seconds / 60)
    const s = seconds % 60
    return `${m}:${s.toString().padStart(2, "0")}`
  }
}
