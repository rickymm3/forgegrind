import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "toggle", "icon"]
  static values = {
    state: { type: String, default: "visible" }
  }

  connect() {
    this.appShell = this.element.closest(".app-shell")
    this.applyState()
  }

  toggle(event) {
    event?.preventDefault()
    this.stateValue = this.stateValue === "visible" ? "hidden" : "visible"
    this.applyState()
  }

  applyState() {
    const hidden = this.stateValue === "hidden"

    if (this.appShell) {
      this.appShell.classList.toggle("app-shell--tabbar-hidden", hidden)
    }

    if (this.hasPanelTarget) {
      this.panelTarget.setAttribute("aria-hidden", hidden)
    }

    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-pressed", hidden)
      this.toggleTarget.setAttribute("aria-label", hidden ? "Show navigation" : "Hide navigation")
    }

    if (this.hasIconTarget) {
      this.iconTarget.textContent = hidden ? "↑" : "↓"
    }
  }
}
