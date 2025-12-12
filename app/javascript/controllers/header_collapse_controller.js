import { Controller } from "@hotwired/stimulus"

// Collapses the app header on scroll and trims secondary header content.
export default class extends Controller {
  static values = {
    threshold: { type: Number, default: 48 }
  }

  connect() {
    this.onScroll = this.onScroll.bind(this)
    this.collapsed = false
    this.collapseThreshold = this.thresholdValue
    this.hysteresis = 20 // pixels to prevent jitter
    this.lastToggleAt = 0
    this.toggleCooldown = 200 // ms
    this.pageHeaders = Array.from(this.element.querySelectorAll(".page-header"))
    this.updateState(window.scrollY > this.collapseThreshold)
    window.addEventListener("scroll", this.onScroll, { passive: true })
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  onScroll() {
    const y = window.scrollY
    const collapseAt = this.collapseThreshold
    const expandAt = Math.max(0, collapseAt - this.hysteresis)

    const now = performance.now()
    if (now - this.lastToggleAt < this.toggleCooldown) return

    if (!this.collapsed && y > collapseAt) {
      this.updateState(true)
      this.lastToggleAt = now
    } else if (this.collapsed && y < expandAt) {
      this.updateState(false)
      this.lastToggleAt = now
    }
  }

  updateState(state) {
    this.collapsed = state
    this.element.classList.toggle("app-shell__header--collapsed", state)
    this.pageHeaders.forEach((header) => {
      header.classList.toggle("page-header--condensed", state)
      header.classList.toggle("page-header--compact", state)
    })
  }
}
