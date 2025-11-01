import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "dialog", "closeButton"]

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)

    this.previousActiveElement = document.activeElement instanceof HTMLElement ? document.activeElement : null
    this.focusInitialControl()
  }

  disconnect() {
    this.removeKeydownListener()
  }

  close(event) {
    if (event) event.preventDefault()

    this.removeKeydownListener()
    this.clearFrame()
    this.restoreFocus()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    }
  }

  focusInitialControl() {
    const targets = this.hasCloseButtonTarget ? this.closeButtonTargets : []
    const firstFocusable = targets.find((element) => typeof element.focus === "function")

    if (firstFocusable) {
      firstFocusable.focus({ preventScroll: true })
      return
    }

    if (this.hasDialogTarget && typeof this.dialogTarget.focus === "function") {
      this.dialogTarget.focus({ preventScroll: true })
    }
  }

  removeKeydownListener() {
    if (this.handleKeydown) {
      document.removeEventListener("keydown", this.handleKeydown)
    }
  }

  clearFrame() {
    const frame = this.element.closest("turbo-frame")
    if (frame) {
      frame.innerHTML = ""
    } else {
      this.element.remove()
    }
  }

  restoreFocus() {
    const focusInfo = window.__containerRevealFocus
    let target = null

    if (focusInfo && focusInfo.key) {
      target = document.querySelector(
        `[data-container-open-key="${focusInfo.key}"][data-container-open-quantity="${focusInfo.quantity}"]`
      )

      if (!target) {
        const candidates = document.querySelectorAll(`[data-container-open-key="${focusInfo.key}"]`)
        target = candidates.length > 0 ? candidates[0] : null
      }
    }

    if (!target && window.__containerRevealTrigger && document.body.contains(window.__containerRevealTrigger)) {
      target = window.__containerRevealTrigger
    }

    if (!target && this.previousActiveElement && document.body.contains(this.previousActiveElement)) {
      target = this.previousActiveElement
    }

    if (!target) {
      target = document.querySelector("[data-container-open-key]")
    }

    if (target && typeof target.focus === "function") {
      requestAnimationFrame(() => target.focus({ preventScroll: true }))
    }

    window.__containerRevealTrigger = null
    window.__containerRevealFocus = null
  }
}
