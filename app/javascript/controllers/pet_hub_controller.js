import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "forgegrind:pets:view"

export default class extends Controller {
  static targets = ["toggle", "panel"]
  static values = {
    active: { type: String, default: "pets" }
  }

  connect() {
    const stored = window.localStorage.getItem(STORAGE_KEY)
    if (stored && ["pets", "eggs"].includes(stored)) {
      this.activeValue = stored
    } else {
      this.updateView()
    }
  }

  activeValueChanged() {
    this.updateView()
    window.localStorage.setItem(STORAGE_KEY, this.activeValue)
  }

  select(event) {
    event.preventDefault()
    const collection = event.currentTarget.dataset.collection
    if (!collection || collection === this.activeValue) return
    this.activeValue = collection
  }

  updateView() {
    this.toggleTargets.forEach((button) => {
      const isActive = button.dataset.collection === this.activeValue
      button.setAttribute("aria-pressed", isActive ? "true" : "false")
      button.classList.toggle("bg-indigo-500/20", isActive)
      button.classList.toggle("border-indigo-400/60", isActive)
      button.classList.toggle("text-indigo-200", isActive)
      button.classList.toggle("text-slate-300", !isActive)
      button.classList.toggle("bg-slate-900/60", !isActive)
      button.classList.toggle("border-slate-700/60", !isActive)
    })

    this.panelTargets.forEach((panel) => {
      const shouldShow = panel.dataset.collection === this.activeValue
      panel.classList.toggle("hidden", !shouldShow)
    })
  }
}
