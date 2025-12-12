import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Polls the pet needs badge every 30s to refresh the badge state.
export default class extends Controller {
  static values = { url: String, interval: Number }

  connect() {
    this.interval = this.intervalValue || 30000
    this.tick = this.tick.bind(this)
    this.tick()
    this.timer = setInterval(this.tick, this.interval)
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  tick() {
    if (!this.hasUrlValue) return
    fetch(this.urlValue, {
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })
      .then((resp) => resp.text())
      .then((html) => {
        if (html && html.trim().length > 0) {
          Turbo.renderStreamMessage(html)
        }
      })
      .catch(() => {
        // swallow errors
      })
  }
}
