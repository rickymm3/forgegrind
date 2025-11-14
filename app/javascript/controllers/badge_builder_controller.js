import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["category", "careSection", "metaSection", "metaList", "template", "metaRow"]

  connect() {
    this.changeCategory()
  }

  changeCategory() {
    const category = this.categoryTarget.value || "care"
    const careVisible = category === "care"

    this.toggleSection(this.careSectionTarget, careVisible)
    this.toggleSection(this.metaSectionTarget, !careVisible)
  }

  toggleSection(element, show) {
    if (!element) return
    element.classList.toggle("hidden", !show)
  }

  addCondition(event) {
    event.preventDefault()
    if (!this.templateTarget || !this.metaListTarget) return

    this.conditionIndex = (this.conditionIndex || this.metaRowTargets.length)
    const html = this.templateTarget.innerHTML.replace(/__INDEX__/g, this.conditionIndex)
    this.conditionIndex += 1

    this.metaListTarget.insertAdjacentHTML("beforeend", html)
  }

  removeCondition(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-badge-builder-target='metaRow']")
    if (row) row.remove()
  }
}
