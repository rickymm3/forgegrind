import { Controller } from "@hotwired/stimulus"

// Controls the portrait/stats toggle on the pet detail page and projects care previews.
export default class extends Controller {
  static targets = [
    "imagePanel",
    "statsPanel",
    "need",
    "needValue",
    "needBar",
    "needDelta",
    "xpBar",
    "xpValue",
    "energyBar",
    "energyValue",
    "xpText"
  ]

  static values = {
    state: { type: String, default: "image" }
  }

  connect() {
    this.showImage()
  }

  toggle(event) {
    if (event) event.preventDefault()
    this.stateValue === "image" ? this.showStats() : this.showImage()
  }

  showImage() {
    this.stateValue = "image"
    this.updatePanels()
  }

  showStats() {
    this.stateValue = "stats"
    this.updatePanels()
  }

  updatePanels() {
    if (!this.hasImagePanelTarget || !this.hasStatsPanelTarget) return

    if (this.stateValue === "stats") {
      this.imagePanelTarget.classList.add("opacity-0", "pointer-events-none")
      this.imagePanelTarget.classList.remove("opacity-100")
      this.statsPanelTarget.classList.remove("opacity-0", "pointer-events-none")
      this.statsPanelTarget.classList.add("opacity-100", "pointer-events-auto")
    } else {
      this.imagePanelTarget.classList.remove("opacity-0", "pointer-events-none")
      this.imagePanelTarget.classList.add("opacity-100")
      this.statsPanelTarget.classList.add("opacity-0", "pointer-events-none")
      this.statsPanelTarget.classList.remove("opacity-100", "pointer-events-auto")
    }
  }

  handlePreview(event) {
    const detail = event?.detail || {}
    const previewEntries = Array.isArray(detail.preview) ? detail.preview : []
    const activePreview = detail.state === "confirm"

    this.resetNeeds()
    this.resetEnergyXp()

    if (!activePreview) return

    previewEntries.forEach((entry) => {
      const key = (entry.key || entry[:key]).toString()
      const after = this.safeNumber(entry.after ?? entry[:after])
      const afterPercent = this.safeNumber(entry.after_percent ?? entry[:after_percent] ?? after)
      const delta = this.safeNumber(entry.delta ?? entry[:delta] ?? (after - this.safeNumber(entry.before ?? entry[:before])))
      this.updateNeedDisplay(key, after, afterPercent, delta)
    })

    const energyDetail = detail.energy || {}
    const xpDetail = detail.xp || {}

    const energyBefore = this.safeNumber(
      energyDetail.before ?? (this.hasEnergyValueTarget ? this.energyValueTarget.dataset.baseValue : undefined)
    )
    const energyAfter = this.safeNumber(energyDetail.after ?? energyDetail.before ?? energyBefore)
    this.updateEnergyDisplay(energyAfter)

    const xpBaseBefore = this.hasXpTextTarget ? this.safeNumber(this.xpTextTarget.dataset.baseBefore) : 0
    const xpBefore = this.safeNumber(xpDetail.before ?? xpBaseBefore)
    const xpAfter = this.safeNumber(xpDetail.after ?? (xpDetail.gain != null ? xpBefore + this.safeNumber(xpDetail.gain) : xpBefore))
    const xpGain = this.safeNumber(xpDetail.gain ?? (xpAfter - xpBefore))
    this.updateXpDisplay(xpBefore, xpAfter, xpGain)
  }

  resetNeeds() {
    this.needTargets.forEach((container) => {
      const key = container.dataset.key
      const baseValue = this.safeNumber(container.dataset.baseValue)
      const basePercent = this.safeNumber(container.dataset.basePercent || baseValue)
      this.updateNeedDisplay(key, baseValue, basePercent, null)
    })
  }

  resetEnergyXp() {
    if (this.hasEnergyValueTarget) {
      const baseEnergy = this.safeNumber(this.energyValueTarget.dataset.baseValue)
      this.updateEnergyDisplay(baseEnergy)
    }

    if (this.hasXpTextTarget || this.hasXpValueTarget || this.hasXpBarTarget) {
      const baseXp = this.hasXpTextTarget
        ? this.safeNumber(this.xpTextTarget.dataset.baseBefore)
        : 0
      this.updateXpDisplay(baseXp, baseXp, 0)
    }
  }

  updateNeedDisplay(key, value, percent, delta) {
    if (!key) return

    const valueElement = this.needValueTargets.find((target) => target.dataset.key === key)
    const barElement = this.needBarTargets.find((target) => target.dataset.key === key)
    const deltaElement = this.needDeltaTargets.find((target) => target.dataset.key === key)

    if (valueElement) {
      valueElement.textContent = this.formatNumber(value)
    }

    if (barElement) {
      const clamped = Math.max(0, Math.min(100, percent))
      barElement.style.width = `${clamped}%`
    }

    if (deltaElement) {
      if (delta === null || delta === undefined || Math.abs(delta) < 0.05) {
        deltaElement.classList.add("hidden")
        deltaElement.textContent = ""
      } else {
        const formattedDelta = `${delta > 0 ? "+" : ""}${this.formatNumber(delta)}`
        deltaElement.textContent = `→ ${this.formatNumber(value)} (${formattedDelta})`
        deltaElement.classList.remove("hidden")
        deltaElement.classList.toggle("text-emerald-300", delta >= 0)
        deltaElement.classList.toggle("text-rose-300", delta < 0)
      }
    }
  }

  safeNumber(value) {
    const num = Number(value)
    return Number.isFinite(num) ? num : 0
  }

  clamp(value, min, max) {
    return Math.min(Math.max(value, min), max)
  }

  updateEnergyDisplay(value) {
    if (!this.hasEnergyValueTarget) return

    const max = this.safeNumber(this.energyValueTarget.dataset.maxValue || 100)
    const clamped = this.clamp(this.safeNumber(value), 0, max)
    const span = this.energyValueTarget.querySelector("span")
    if (span) {
      span.textContent = `${Math.round(clamped)} / ${Math.round(max)}`
    }

    if (this.hasEnergyBarTarget) {
      const bar = this.energyBarTargets[0]
      const percent = max > 0 ? (clamped / max) * 100 : 0
      bar.style.width = `${percent}%`
    }
  }

  updateXpDisplay(before, after, gain = 0) {
    const max =
      (this.hasXpTextTarget && this.safeNumber(this.xpTextTarget.dataset.maxValue)) ||
      (this.hasXpBarTarget && this.safeNumber(this.xpBarTargets[0].dataset.maxValue)) ||
      100

    const clampedBefore = this.clamp(this.safeNumber(before), 0, max)
    const clampedAfter = this.clamp(this.safeNumber(after), 0, max)
    const appliedGain = this.safeNumber(gain)

    if (this.hasXpTextTarget) {
      const baseText = this.xpTextTarget.dataset.baseText
      if (appliedGain > 0) {
        this.xpTextTarget.textContent = `${Math.round(clampedBefore)} → ${Math.round(clampedAfter)} / ${Math.round(max)} XP (+${appliedGain})`
      } else if (baseText) {
        this.xpTextTarget.textContent = baseText
      } else {
        this.xpTextTarget.textContent = `${Math.round(clampedAfter)} / ${Math.round(max)} XP`
      }
    }

    if (this.hasXpBarTarget) {
      const percent = max > 0 ? (clampedAfter / max) * 100 : 0
      this.xpBarTargets[0].style.width = `${percent}%`
    }

    if (this.hasXpValueTarget) {
      const xpValueTarget = this.xpValueTargets[0]
      const baseText = xpValueTarget.dataset.baseText
      if (appliedGain > 0) {
        xpValueTarget.textContent = `${(max > 0 ? (clampedAfter / max) * 100 : 0).toFixed(1)}% (+${appliedGain} XP)`
      } else if (baseText) {
        xpValueTarget.textContent = baseText
      } else {
        xpValueTarget.textContent = `${(max > 0 ? (clampedAfter / max) * 100 : 0).toFixed(1)}%`
      }
    }
  }

  formatNumber(value) {
    const num = this.safeNumber(value)
    return Number.isInteger(num) ? num.toString() : num.toFixed(1)
  }
}
