import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["initial", "final", "title", "subtitle"]
  static values = {
    delay: { type: Number, default: 2400 },
    finalTitle: String,
    finalSubtitle: String
  }

  connect() {
    this.start()
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  start() {
    this.showInitial()
    this.timeout = setTimeout(() => this.reveal(), this.delayValue)
  }

  showInitial() {
    if (this.hasInitialTarget) {
      this.initialTarget.classList.remove("opacity-0", "scale-90", "hidden")
      this.initialTarget.classList.add("opacity-100", "scale-100")
    }
    if (this.hasFinalTarget) {
      this.finalTarget.classList.add("hidden", "opacity-0", "scale-90")
    }
  }

  reveal() {
    if (this.hasInitialTarget) {
      this.initialTarget.classList.add("opacity-0", "scale-90")
      this.initialTarget.classList.remove("opacity-100", "scale-100")
      setTimeout(() => {
        this.initialTarget.classList.add("hidden")
      }, 220)
    }

    if (this.hasFinalTarget) {
      this.finalTarget.classList.remove("hidden")
      requestAnimationFrame(() => {
        this.finalTarget.classList.remove("opacity-0", "scale-90")
        this.finalTarget.classList.add("opacity-100", "scale-100")
      })
    }

    if (this.hasTitleTarget && this.finalTitleValue) {
      this.titleTarget.textContent = this.finalTitleValue
    }

    if (this.hasSubtitleTarget) {
      if (this.finalSubtitleValue) {
        this.subtitleTarget.textContent = this.finalSubtitleValue
        this.subtitleTarget.classList.remove("hidden")
      } else {
        this.subtitleTarget.classList.add("hidden")
      }
    }
  }
}
