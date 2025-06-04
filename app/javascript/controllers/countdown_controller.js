import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Expose Turbo globally so renderStreamMessage works
window.Turbo = Turbo

export default class extends Controller {
  static values = { seconds: Number }
  static targets = ["container", "output"]

  connect() {
    this.endTime = Date.now() + this.secondsValue * 1000

    this.userEggId = this.element.dataset.userEggId
    this.userExplorationId = this.element.dataset.userExplorationId

    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
    console.log(this.secondsValue)
    console.log(this.endTime)
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
    if (this.userEggId) {
      this.markEggReady()
    } else if (this.userExplorationId) {
      this.completeExploration()
    } else {
      console.warn("Countdown finished but no ID found to handle completion.")
    }
  }

  markEggReady() {
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
      .catch(err => console.error("mark_ready failed:", err))
  }

  completeExploration() {
    fetch(`/user_explorations/${this.userExplorationId}/complete`, {
      method: "POST",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      credentials: "same-origin"
    })
      .then(response => response.text())
      .then(html => Turbo.renderStreamMessage(html))
      .catch(err => console.error("complete_exploration failed:", err))
  }

  formatTime(seconds) {
    const m = Math.floor(seconds / 60)
    const s = seconds % 60
    return `${m}:${s.toString().padStart(2, "0")}`
  }
}
