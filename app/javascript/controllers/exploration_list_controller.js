import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.activateInitial()
  }

  select(event) {
    this.activate(event.currentTarget)
  }

  activateInitial() {
    const initiallySelected = this.itemTargets.find(
      (item) => item.dataset.selected === "true"
    )
    if (initiallySelected) {
      this.activate(initiallySelected)
    }
  }

  activate(element) {
    this.itemTargets.forEach((item) => {
      item.classList.remove(
        "border-indigo-500",
        "bg-indigo-50",
        "shadow-sm"
      )
      item.classList.add("border-transparent")
      item.dataset.selected = "false"
    })

    if (element) {
      element.classList.add("border-indigo-500", "bg-indigo-50", "shadow-sm")
      element.classList.remove("border-transparent")
      element.dataset.selected = "true"
    }
  }
}
