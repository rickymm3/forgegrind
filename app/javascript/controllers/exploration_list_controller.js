import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["item"]
  static highlightClasses = ["ring-2", "ring-indigo-400/80", "shadow-2xl", "scale-[1.01]"]

  connect() {
    this.activateInitial()
  }

  handleClick(event) {
    const tile = event.currentTarget
    if (tile.dataset.disabled === "true") {
      this.activate(tile)
      return
    }
    const interactiveTarget = event.target.closest("a, button, form, input, label, textarea, select")
    if (interactiveTarget) {
      this.activate(tile)
      return
    }

    this.activate(tile)
    const url = tile.dataset.url
    if (url) {
      Turbo.visit(url)
    }
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
      this.constructor.highlightClasses.forEach((klass) => item.classList.remove(klass))
      item.dataset.selected = "false"
    })

    if (element) {
      this.constructor.highlightClasses.forEach((klass) => element.classList.add(klass))
      element.dataset.selected = "true"
    }
  }
}
