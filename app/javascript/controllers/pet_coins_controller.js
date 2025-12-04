import { Controller } from "@hotwired/stimulus"

// Drives the passive coin bar client-side so it advances between server ticks
export default class extends Controller {
  static targets = ["bar", "readyText", "collectWrapper", "collectButton", "collectedText"]
  static values = {
    perSecond: Number,
    lastTickAt: Number,
    cap: Number,
    earnedToday: Number
  }

  connect() {
    this.start()
  }

  disconnect() {
    this.stop()
  }

  start() {
    this.stop()
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  stop() {
    if (this.timer) clearInterval(this.timer)
    this.timer = null
  }

  tick() {
    const now = Date.now()
    const last = this.lastTickAtValue || now
    const elapsedMs = now - last
    const perSecond = this.perSecondValue || 0
    const cap = this.capValue || 0
    const heldStart = this.earnedTodayValue || 0
    if (perSecond <= 0 || cap <= 0) return

    const pending = Math.min(heldStart + perSecond * (elapsedMs / 1000), cap)
    const progressPct = Math.min(Math.round((pending / cap) * 100), 100)

    if (this.hasBarTarget) {
      this.barTarget.style.width = `${progressPct}%`
    }

    const ready = pending >= 200
    if (this.hasReadyTextTarget) {
      if (ready) {
        this.readyTextTarget.textContent = `Ready: +${Math.floor(pending)} coins`
      } else {
        const remainingToReady = Math.max(200 - pending, 0)
        const secondsToReady = perSecond > 0 ? Math.ceil(remainingToReady / perSecond) : 0
        const timeLabel = secondsToReady >= 3600
          ? `${Math.floor(secondsToReady / 3600)}h ${Math.floor((secondsToReady % 3600) / 60)}m`
          : `${Math.floor(secondsToReady / 60)}m ${secondsToReady % 60}s`
        this.readyTextTarget.textContent = `Building up… (~${timeLabel})`
      }
      this.readyTextTarget.classList.toggle("pet-slot__coins-ready", ready)
    }
    if (this.hasCollectWrapperTarget) {
      this.collectWrapperTarget.classList.toggle("disabled", !ready)
    }
    if (this.hasCollectButtonTarget) {
      this.collectButtonTarget.disabled = !ready
    }
    if (this.hasCollectedTextTarget) {
      this.collectedTextTarget.textContent = `Holding: ${Math.floor(pending)}/${cap}`
    }
  }
}
