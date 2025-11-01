import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section"]
  static values = {
    activeTab: { type: String, default: "all" }
  }

  connect() {
    this.updateTabs()
    this.updateSections()
  }

  switchTab(event) {
    event.preventDefault()
    const tab = event.currentTarget.dataset.tab
    if (!tab || tab === this.activeTabValue) return

    this.activeTabValue = tab
    this.updateTabs()
    this.updateSections()
  }

  rememberRevealTrigger(event) {
    const button = event.currentTarget
    window.__containerRevealTrigger = button

    const { containerOpenKey: key, containerOpenQuantity: quantity } = button.dataset
    if (key) {
      window.__containerRevealFocus = { key, quantity }
    } else {
      window.__containerRevealFocus = null
    }
  }

  updateTabs() {
    const buttons = this.element.querySelectorAll('[data-action~="inventory#switchTab"]')
    buttons.forEach((button) => {
      const tab = button.dataset.tab
      const isActive = tab === this.activeTabValue || (tab === "all" && this.activeTabValue === "all")
      button.classList.toggle("bg-indigo-600", isActive)
      button.classList.toggle("text-white", isActive)
      button.classList.toggle("bg-slate-900/60", !isActive)
      button.classList.toggle("text-slate-300", !isActive)
    })
  }

  updateSections() {
    this.sectionTargets.forEach((section) => {
      const type = section.dataset.section
      const shouldShow = this.activeTabValue === "all" || type === this.activeTabValue
      section.classList.toggle("hidden", !shouldShow)
    })
  }
}
