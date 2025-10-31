import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = {
    url: String,
    filters: Object
  }

  static targets = ["checkbox", "selectedField"]

  refresh(event) {
    if (event?.target?.disabled) return

    this.updateSelectedField()
    this.submitPreview()
  }

  updateSelectedField() {
    if (!this.hasSelectedFieldTarget) return

    this.selectedFieldTarget.value = this.selectedIds().join(",")
  }

  selectedIds() {
    return this.checkboxTargets.filter((checkbox) => checkbox.checked).map((checkbox) => checkbox.value)
  }

  submitPreview() {
    if (!this.hasUrlValue) return

    const formData = new FormData()
    formData.append("selected_pet_ids", this.selectedIds().join(","))

    const filters = this.filtersValue || {}
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== "") {
        formData.append(key, value)
      }
    })

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": this.csrfToken
      },
      body: formData
    })
      .then((response) => response.text())
      .then((html) => {
        if (html.trim().length > 0) {
          Turbo.renderStreamMessage(html)
        }
      })
      .catch((error) => {
        if (console && console.error) {
          console.error("Failed to refresh exploration preview", error)
        }
      })
  }

  get csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.content : ""
  }
}
