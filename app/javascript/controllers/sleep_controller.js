// app/javascript/controllers/sleep_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["timer"]
  static values = {
    until: Number  // Unix timestamp (seconds)
  }

  connect() {
    this.endTime = new Date(this.untilValue * 1000)  // convert seconds to ms
    this.updateTimer()
    this.interval = setInterval(() => this.updateTimer(), 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  updateTimer() {
    const now = new Date()
    const remainingMs = this.endTime - now

    if (remainingMs <= 0) {
      clearInterval(this.interval)
      this.timerTarget.textContent = "Now awake!"
      return
    }

    const totalSec = Math.floor(remainingMs / 1000)
    const minutes = Math.floor(totalSec / 60)
    const seconds = totalSec % 60
    this.timerTarget.textContent = `${minutes}m ${seconds.toString().padStart(2, "0")}s`
  }
}
