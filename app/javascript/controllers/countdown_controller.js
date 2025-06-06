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
    this.userEggId = this.element.dataset.userEggId
    this.userPetId = this.element.dataset.userPetId

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
        },
        credentials: "same-origin"
      })
        .then(response => response.text())
        .then(html => Turbo.renderStreamMessage(html))
        .catch(err => console.error("ready_exploration failed:", err))
    } else if (this.userEggId) {
      fetch(`/user_eggs/${this.userEggId}/mark_ready`, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        credentials: "same-origin"
      })
        .then(response => response.text())
        .then(html => Turbo.renderStreamMessage(html))
        .catch(err => console.error("ready_egg failed:", err))
    } else if (this.userPetId) {
      fetch(`/user_pets/${this.userPetId}/energy_tick`, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        credentials: "same-origin"
      })
        .then(response => response.text())
        .then(html => {
          Turbo.renderStreamMessage(html)
          // restart timer
          this.endTime = Date.now() + this.secondsValue * 1000
          this.timer = setInterval(() => this.tick(), 1000)
        })
        .catch(err => console.error("energy_tick failed:", err))
    } else {
      console.warn("Countdown finished but no target ID found.")
    }
  }

  formatTime(seconds) {
    const m = Math.floor(seconds / 60)
    const s = seconds % 60
    return `${m}:${s.toString().padStart(2, "0")}`
  }
}
