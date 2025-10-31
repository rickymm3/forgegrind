import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  close(event) {
    event.preventDefault()
    this.dispatch("close", { bubbles: true })
  }
}
