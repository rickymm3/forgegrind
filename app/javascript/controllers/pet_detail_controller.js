import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  toggleOverlay(event) {
    event.stopPropagation()
    if (this.overlayTarget.classList.contains("is-hidden")) {
      this.showOverlay()
    } else {
      this.overlayTarget.classList.add("is-hidden")
    }
  }

  showOverlay(event) {
    if (event) event.stopPropagation()
    this.overlayTarget.classList.remove("is-hidden")
  }
}
