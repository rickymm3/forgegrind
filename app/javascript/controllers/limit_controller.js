import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { max: Number }
  static targets = ["checkbox", "indicator"]

  connect() {
    this.update()
  }

  toggle() {
    this.update()
  }

  update() {
    const checked = this.checkboxTargets.filter(cb => cb.checked).length
    const disableOthers = checked >= this.maxValue

    this.checkboxTargets.forEach(cb => {
      if (cb.dataset.permanentDisabled === "true") return
      if (!cb.checked) {
        cb.disabled = disableOthers
      }
    })

    this.updateIndicators(checked)
  }

  updateIndicators(checked) {
    if (!this.hasIndicatorTarget) return

    this.indicatorTargets.forEach(target => {
      target.textContent = `${checked}/${this.maxValue} selected`
    })
  }
}
