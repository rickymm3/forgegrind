import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["eggImage", "petImage", "title"]
  static values  = { delay: Number }

  // Called on turbo:frame-load (or manual click, see HAML)
  start(event) {
    // show egg, hide pet, set title
    this.eggImageTarget.classList.remove("hidden")
    this.petImageTarget.classList.add("hidden")
    this.titleTarget.textContent = "Hatching..."

    // swap after `delayValue` ms
    setTimeout(() => this.reveal(), this.delayValue || 3000)
  }

  reveal() {
    this.eggImageTarget.classList.add("hidden")
    this.petImageTarget.classList.remove("hidden")
    // use the alt text of pet image for name, or default
    const name = this.petImageTarget.getAttribute("alt") || "your pet"
    this.titleTarget.textContent = `You hatched ${name}!`
  }
}
