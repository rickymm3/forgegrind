import { Controller } from "@hotwired/stimulus"

// Handles closing the pet action panel via overlay clicks or keyboard shortcuts.
export default class extends Controller {
  static targets = ["cancelForm"]

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.submitCancel()
    }
  }

  submitCancel(event) {
    if (event) {
      event.preventDefault()
    }
    if (this.hasCancelFormTarget) {
      this.cancelFormTarget.requestSubmit()
    }
  }
}
