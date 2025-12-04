import { Controller } from "@hotwired/stimulus"

// Controls the portrait/stats toggle on the pet detail page and projects care previews.
export default class extends Controller {
  static targets = [
    "imagePanel",
    "statsPanel",
    "need",
    "needValue",
    "needBar",
    "needPreview",
    "needDelta",
    "xpBar",
    "xpValue",
    "energyBar",
    "energyValue",
    "energyDelta",
    "energyDeltaBefore",
    "energyDeltaAfter",
    "energyDeltaChange",
    "energySleepAlert",
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
    const successSnapshot = Array.isArray(detail.needsAfter) ? detail.needsAfter : []
    const activePreview = detail.state === "confirm"

    this.resetNeeds()
    this.resetEnergyXp()

    if (detail.state === "success" && successSnapshot.length > 0) {
      successSnapshot.forEach((entry) => {
        const key = this.fetchEntryValue(entry, "key")
        const value = this.safeNumber(this.fetchEntryValue(entry, "value"))
        const percent = this.safeNumber(this.fetchEntryValue(entry, "percent") ?? value)
        const normalizedKey = key == null ? null : key.toString()
        this.updateNeedDisplay(normalizedKey, value, percent, null, percent, { updateBase: true })
      })
    }

    if (!activePreview) return

    previewEntries.forEach((entry) => {
      const key = this.fetchEntryValue(entry, "key")
      const after = this.safeNumber(this.fetchEntryValue(entry, "after"))
      const afterPercent = this.safeNumber(this.fetchEntryValue(entry, "after_percent") ?? after)
      const before = this.safeNumber(this.fetchEntryValue(entry, "before"))
      const computedDelta = after - before
      const delta = this.safeNumber(this.fetchEntryValue(entry, "delta") ?? computedDelta)
      const beforePercent = this.safeNumber(this.fetchEntryValue(entry, "before_percent") ?? before)
      const normalizedKey = key == null ? null : key.toString()
      this.updateNeedDisplay(normalizedKey, after, afterPercent, delta, beforePercent)
    })

    const energyDetail = detail.energy || {}
    const xpDetail = detail.xp || {}

    const energyBefore = this.safeNumber(
      energyDetail.before ?? (this.hasEnergyValueTarget ? this.energyValueTarget.dataset.baseValue : undefined)
    )
    const energyAfter = this.safeNumber(energyDetail.after ?? energyDetail.before ?? energyBefore)
    this.updateEnergyDisplay(energyAfter, {
      preview: activePreview,
      before: energyBefore,
      after: energyAfter
    })

    const xpBaseBefore = this.hasXpTextTarget ? this.safeNumber(this.xpTextTarget.dataset.baseBefore) : 0
    const xpBefore = this.safeNumber(xpDetail.before ?? xpBaseBefore)
    const xpAfter = this.safeNumber(xpDetail.after ?? (xpDetail.gain != null ? xpBefore + this.safeNumber(xpDetail.gain) : xpBefore))
    const xpGain = this.safeNumber(xpDetail.gain ?? (xpAfter - xpBefore))
    this.updateXpDisplay(xpBefore, xpAfter, xpGain)

    if (detail.state === "success") {
      if (this.hasEnergyValueTarget) {
        this.energyValueTarget.dataset.baseValue = energyAfter
      }
      if (this.hasXpTextTarget) {
        this.xpTextTarget.dataset.baseBefore = xpAfter
      }
    }
  }

  resetNeeds() {
    this.needTargets.forEach((container) => {
      const key = container.dataset.key
      const baseValue = this.safeNumber(container.dataset.baseValue)
      const basePercent = this.safeNumber(container.dataset.basePercent || baseValue)
      this.updateNeedDisplay(key, baseValue, basePercent, null, basePercent)
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

  updateNeedDisplay(key, value, percent, delta, beforePercent = null, options = {}) {
    if (!key) return

    const valueElement = this.needValueTargets.find((target) => target.dataset.key === key)
    const barElement = this.needBarTargets.find((target) => target.dataset.key === key)
    const deltaElement = this.needDeltaTargets.find((target) => target.dataset.key === key)
    const previewElement = this.needPreviewTargets.find((target) => target.dataset.key === key)
    const container = this.needTargets.find((target) => target.dataset.key === key)
    const updateBase = options.updateBase === true
    const hasDelta = delta !== null && delta !== undefined && Math.abs(delta) >= 0.05

    if (valueElement) {
      valueElement.textContent = this.formatNumber(value)
    }

    if (barElement) {
      const clamped = this.clamp(percent, 0, 100)
      barElement.style.width = `${clamped}%`
      barElement.dataset.percent = clamped
    }

    if (deltaElement) {
      if (!hasDelta) {
        deltaElement.classList.add("hidden")
        deltaElement.textContent = ""
        deltaElement.classList.remove("pet-stat__delta--positive", "pet-stat__delta--negative")
      } else {
        const formattedDelta = `${delta > 0 ? "+" : ""}${this.formatNumber(delta)}`
        deltaElement.textContent = formattedDelta
        deltaElement.classList.remove("hidden")
        deltaElement.classList.toggle("pet-stat__delta--positive", delta > 0)
        deltaElement.classList.toggle("pet-stat__delta--negative", delta < 0)
      }
    }

    if (previewElement) {
      if (!hasDelta) {
        previewElement.style.opacity = "0"
        previewElement.style.width = "0%"
        previewElement.style.left = "0%"
        previewElement.classList.remove("pet-stat__preview--positive", "pet-stat__preview--negative")
      } else {
        const afterPercent = this.clamp(percent, 0, 100)
        const basePercent = this.clamp(
          beforePercent !== null && beforePercent !== undefined
            ? beforePercent
            : this.safeNumber(previewElement.dataset.basePercent || afterPercent),
          0,
          100
        )
        const start = Math.min(basePercent, afterPercent)
        const width = Math.abs(afterPercent - basePercent)
        previewElement.style.left = `${start}%`
        previewElement.style.width = `${width}%`
        previewElement.style.opacity = width > 0 ? "0.95" : "0"
        previewElement.classList.toggle("pet-stat__preview--positive", delta > 0)
        previewElement.classList.toggle("pet-stat__preview--negative", delta < 0)
      }
    }

    if (container && updateBase) {
      container.dataset.baseValue = value
      container.dataset.basePercent = percent
    }

    if (previewElement && updateBase) {
      previewElement.dataset.basePercent = percent
    }
  }

  safeNumber(value) {
    const num = Number(value)
    return Number.isFinite(num) ? num : 0
  }

  fetchEntryValue(entry, key) {
    if (!entry || !key) return undefined
    if (Object.prototype.hasOwnProperty.call(entry, key)) {
      return entry[key]
    }

    const camelKey = key.replace(/_([a-z])/g, (_, char) => char.toUpperCase())
    if (Object.prototype.hasOwnProperty.call(entry, camelKey)) {
      return entry[camelKey]
    }

    return undefined
  }

  clamp(value, min, max) {
    return Math.min(Math.max(value, min), max)
  }

  updateEnergyDisplay(value, options = {}) {
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

    const previewActive = options.preview === true && options.before != null
    const beforeValue = this.safeNumber(options.before)
    const afterValue = this.safeNumber(options.after ?? clamped)
    const delta = afterValue - beforeValue

    if (this.hasEnergyDeltaTarget && this.energyDeltaTarget) {
      if (previewActive) {
        this.energyDeltaTarget.classList.remove("hidden")
        if (this.hasEnergyDeltaBeforeTarget) {
          this.energyDeltaBeforeTarget.textContent = Math.round(beforeValue)
        }
        if (this.hasEnergyDeltaAfterTarget) {
          this.energyDeltaAfterTarget.textContent = Math.round(afterValue)
        }
        if (this.hasEnergyDeltaChangeTarget) {
          const rounded = Math.round(delta)
          const prefix = rounded > 0 ? "+" : ""
          this.energyDeltaChangeTarget.textContent = `${prefix}${rounded} EN`
          this.energyDeltaChangeTarget.classList.toggle("pet-energy__delta-change--negative", rounded < 0)
          this.energyDeltaChangeTarget.classList.toggle("pet-energy__delta-change--positive", rounded > 0)
        }
      } else {
        this.energyDeltaTarget.classList.add("hidden")
      }
    }

    if (this.hasEnergySleepAlertTarget) {
      const threshold = this.energyValueTarget.dataset.sleepThreshold
      const sleepThreshold = threshold ? this.safeNumber(threshold) : null
      if (previewActive && sleepThreshold !== null && afterValue < sleepThreshold) {
        this.energySleepAlertTarget.classList.remove("hidden")
      } else {
        this.energySleepAlertTarget.classList.add("hidden")
      }
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
