import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["initial", "final", "title", "subtitle"]
  static values = {
    delay: { type: Number, default: 2400 },
    finalTitle: String,
    finalSubtitle: String,
    redirectUrl: String,
    redirectDelay: { type: Number, default: 1200 }
  }

  connect() {
    this.start()
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
    if (this.redirectTimeout) clearTimeout(this.redirectTimeout)
    if (this.initialAnimation) {
      this.initialAnimation.cancel()
      this.initialAnimation = null
    }
  }

  start() {
    if (this.redirectTimeout) {
      clearTimeout(this.redirectTimeout)
      this.redirectTimeout = null
    }
    this.showInitial()
    this.timeout = setTimeout(() => this.reveal(), this.delayValue)
  }

  showInitial() {
    if (this.hasInitialTarget) {
      this.initialTarget.classList.remove("opacity-0", "scale-90", "hidden")
      this.initialTarget.classList.add("opacity-100", "scale-100")
      this.startInitialAnimation()
    }
    if (this.hasFinalTarget) {
      this.finalTarget.classList.add("hidden", "opacity-0", "scale-90")
    }
  }

  startInitialAnimation() {
    if (!this.hasInitialTarget) return

    if (this.initialAnimation) {
      this.initialAnimation.cancel()
    }

    try {
      this.initialAnimation = this.initialTarget.animate([
        { transform: "rotate(0deg)" },
        { transform: "rotate(6deg)" },
        { transform: "rotate(-6deg)" },
        { transform: "rotate(0deg)" }
      ], {
        duration: 900,
        iterations: Infinity,
        easing: "ease-in-out"
      })
    } catch (error) {
      console.warn("pet-reveal animation failed", error)
    }
  }

  reveal() {
    if (this.initialAnimation) {
      this.initialAnimation.cancel()
      this.initialAnimation = null
    }

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

    if (this.hasRedirectUrlValue && this.redirectUrlValue) {
      this.redirectTimeout = setTimeout(() => {
        Turbo.visit(this.redirectUrlValue)
      }, this.redirectDelayValue)
    }
  }
}
