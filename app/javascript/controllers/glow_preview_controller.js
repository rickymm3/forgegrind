import { Controller } from "@hotwired/stimulus"

// Controls the glow essence toggle in the care interaction preview and updates
// displayed need deltas to reflect the boosted values.
export default class extends Controller {
  static targets = ["checkbox", "delta", "diff"]
  static values = {
    multiplier: Number
  }

  connect() {
    this.update()
  }

  toggle() {
    this.update()
  }

  update() {
    const useGlow = this.hasCheckboxTarget ? this.checkboxTarget.checked : false
    const multiplier = this.multiplierValue || 1.0

    this.deltaTargets.forEach((target, index) => {
      const baseValueAttr = target.dataset.baseValue ?? target.dataset.glowPreviewBaseValue
      const baseValue = parseFloat(baseValueAttr ?? "0")
      const diffTarget = this.diffTargets[index]

      let displayValue = baseValue
      let diff = 0

      if (useGlow && baseValue > 0) {
        const boosted = Math.round(baseValue * multiplier)
        diff = boosted - baseValue
        displayValue = boosted
      }

      target.textContent = this.formatDelta(displayValue)
      this.applyColor(target, displayValue)

      if (diffTarget) {
        if (diff > 0) {
          diffTarget.textContent = ` (+${diff})`
          diffTarget.classList.remove("hidden")
        } else {
          diffTarget.textContent = ""
          diffTarget.classList.add("hidden")
        }
      }
    })
  }

  formatDelta(value) {
    if (value > 0) {
      return `+${value}`
    }
    return `${value}`
  }

  applyColor(element, value) {
    element.classList.remove("text-emerald-600", "text-red-600", "text-slate-600")

    if (value > 0) {
      element.classList.add("text-emerald-600")
    } else if (value < 0) {
      element.classList.add("text-red-600")
    } else {
      element.classList.add("text-slate-600")
    }
  }
}
