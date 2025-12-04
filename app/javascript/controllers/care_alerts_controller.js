import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bubble", "panel", "itemToggle", "actionButton"]

  connect() {
    this.syncAllButtons()
  }

  toggle(event) {
    const key = event.currentTarget.dataset.alertKey
    if (!key) return

    if (this.activeKey === key) {
      this.clear()
      return
    }

    this.showBubble(key)
  }

  showBubble(key) {
    this.activeKey = key
    this.bubbleTargets.forEach((bubble) => {
      bubble.classList.toggle("is-active", bubble.dataset.alertKey === key)
    })
    this.element.classList.toggle("has-active", Boolean(key))
  }

  clear() {
    this.activeKey = null
    this.bubbleTargets.forEach((bubble) => bubble.classList.remove("is-active"))
    this.element.classList.remove("has-active")
  }

  syncButtons(event) {
    const toggle = event.currentTarget
    const bubble = toggle.closest("[data-care-alerts-target='bubble']")
    const button = bubble?.querySelector("[data-care-alerts-target='actionButton']")
    if (!button) return

    const qty = parseInt(toggle.dataset.itemQuantity || "0", 10)
    const wantsItem = toggle.checked
    button.disabled = wantsItem && qty <= 0
  }

  syncAllButtons() {
    this.itemToggleTargets.forEach((toggle) => {
      this.syncButtons({ currentTarget: toggle })
    })
  }
}
