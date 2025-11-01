import { Controller } from "@hotwired/stimulus"

const FOCUSABLE_SELECTORS = [
  "a[href]",
  "button:not([disabled])",
  "input:not([disabled]):not([type='hidden'])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  "[tabindex]:not([tabindex='-1'])"
].join(",")

export default class extends Controller {
  static targets = ["trigger", "container", "panel"]

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    this.handleTransitionEnd = this.handleTransitionEnd.bind(this)
    this.isOpen = false
  }

  disconnect() {
    this.removeListeners()
  }

  open(event) {
    event.preventDefault()
    if (this.isOpen) return

    this.previouslyFocused = document.activeElement instanceof HTMLElement ? document.activeElement : null

    this.containerTarget.classList.remove("hidden")
    requestAnimationFrame(() => {
      this.panelTarget.classList.remove("translate-y-full")
      this.panelTarget.classList.add("translate-y-0")
    })

    this.triggerTarget.setAttribute("aria-expanded", "true")
    document.body.classList.add("overflow-hidden")
    document.addEventListener("keydown", this.handleKeydown)
    this.panelTarget.addEventListener("transitionend", this.handleTransitionEnd)
    this.isOpen = true
    this.focusFirstElement()
  }

  close(event) {
    if (event) event.preventDefault()
    if (!this.isOpen) return

    this.panelTarget.classList.add("translate-y-full")
    this.panelTarget.classList.remove("translate-y-0")
    this.panelTarget.addEventListener("transitionend", this.handleTransitionEnd)

    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.isOpen = false

    this.restoreFocus()
  }

  handleTransitionEnd(event) {
    if (event.target !== this.panelTarget) return
    this.panelTarget.removeEventListener("transitionend", this.handleTransitionEnd)

    if (!this.isOpen) {
      this.containerTarget.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
      this.removeListeners()
    }
  }

  handleKeydown(event) {
    if (!this.isOpen) return

    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      return
    }

    if (event.key === "Tab") {
      this.handleFocusTrap(event)
    }
  }

  handleFocusTrap(event) {
    const focusables = this.focusableElements()
    if (focusables.length === 0) {
      event.preventDefault()
      return
    }

    const first = focusables[0]
    const last = focusables[focusables.length - 1]
    const current = document.activeElement

    if (event.shiftKey) {
      if (current === first || !this.panelTarget.contains(current)) {
        event.preventDefault()
        last.focus()
      }
    } else {
      if (current === last) {
        event.preventDefault()
        first.focus()
      }
    }
  }

  focusFirstElement() {
    const focusables = this.focusableElements()
    if (focusables.length > 0) {
      focusables[0].focus({ preventScroll: true })
    } else {
      this.panelTarget.focus({ preventScroll: true })
    }
  }

  focusableElements() {
    return Array.from(this.panelTarget.querySelectorAll(FOCUSABLE_SELECTORS)).filter(
      (el) => el.offsetParent !== null || el === document.activeElement
    )
  }

  restoreFocus() {
    if (this.previouslyFocused && document.body.contains(this.previouslyFocused)) {
      this.previouslyFocused.focus({ preventScroll: true })
    } else if (this.triggerTarget) {
      this.triggerTarget.focus({ preventScroll: true })
    }
    this.previouslyFocused = null
  }

  removeListeners() {
    document.removeEventListener("keydown", this.handleKeydown)
  }
}
