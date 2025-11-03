import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["output"]
  static values = {
    seconds: Number,
    refreshUrl: String
  }

  connect() {
    this.remaining = Math.max(0, Number(this.secondsValue || 0))
    this.outputElement = this.hasOutputTarget ? this.outputTarget : this.element

    if (this.remaining <= 0) {
      this.complete()
      return
    }

    this.endTime = Date.now() + this.remaining * 1000
    this.updateOutput()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    this.clearTimer()
  }

  tick() {
    const now = Date.now()
    this.remaining = Math.max(0, Math.ceil((this.endTime - now) / 1000))
    this.updateOutput()

    if (this.remaining <= 0) {
      this.complete()
    }
  }

  updateOutput() {
    if (!this.outputElement) return

    const minutes = Math.floor(this.remaining / 60)
    const seconds = this.remaining % 60
    this.outputElement.textContent = `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`
  }

  complete() {
    this.clearTimer()

    if (this.hasRefreshUrlValue && this.refreshUrlValue) {
      this.requestRefresh(this.refreshUrlValue)
    } else {
      Turbo.visit(window.location.href, { action: "replace" })
    }
  }

  clearTimer() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  requestRefresh(url) {
    fetch(url, {
      headers: {
        Accept: "text/vnd.turbo-stream.html"
      },
      credentials: "same-origin"
    })
      .then((response) => {
        if (!response.ok) throw new Error(`Request failed with ${response.status}`)
        return response.text()
      })
      .then((html) => Turbo.renderStreamMessage(html))
      .catch(() => {
        Turbo.visit(window.location.href, { action: "replace" })
      })
  }
}
