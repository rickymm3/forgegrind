// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "container"]
  static values = { name: String }

  connect() {
    console.log("modal connected—name:", this.nameValue)
    console.log("x:", document.getElementById(this.nameValue))
  }

  open(event) {
    const hatchModalElement = document.querySelector('.hatch-modal');

    if (hatchModalElement) {
      // 2. Check if the 'hidden' class exists
      if (hatchModalElement.classList.contains('hidden')) {
        // 3. Remove the 'hidden' class
        hatchModalElement.classList.remove('hidden');
        console.log("Removed 'hidden' class from the hatch-modal element. It should now be visible.");
      } else {
        console.log("The hatch-modal element does not have the 'hidden' class (or it's already visible).");
      }
    } else {
      console.log("Element with class 'hatch-modal' not found.");
    }
  }

  close() {
    // HIDE the overlay again
    this.overlayTarget.classList.add("hidden")
  }

  backgroundClose(event) {
    // click outside the container? then close
    if (!this.containerTarget.contains(event.target)) {
      this.close()
    }
  }
}
