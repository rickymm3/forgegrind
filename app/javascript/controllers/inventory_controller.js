import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sections", "detail"]
  static values = {
    activeTab: { type: String, default: "all" }
  }

  connect() {
    this.updateTabs()
    this.updateSections()
  }

  switchTab(event) {
    event.preventDefault()
    const tab = event.currentTarget.dataset.tab
    if (!tab || tab === this.activeTabValue) return

    this.activeTabValue = tab
    this.updateTabs(event.currentTarget)
    this.updateSections()
  }

  selectEntry(event) {
    const element = event.currentTarget
    this.highlightSelection(element)
    this.renderDetail(element.dataset)
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  closeReveal(event) {
    event.preventDefault()
    const frame = document.getElementById("container-reveal")
    if (frame) frame.innerHTML = ""
  }

  updateTabs(activeButton = null) {
    const buttons = this.element.querySelectorAll('[data-action~="inventory#switchTab"]')
    buttons.forEach((button) => {
      const tab = button.dataset.tab
      const isActive = tab === this.activeTabValue
      button.classList.toggle("bg-indigo-600", isActive)
      button.classList.toggle("text-white", isActive)
      button.classList.toggle("bg-slate-800/60", !isActive)
      button.classList.toggle("text-slate-300", !isActive)
    })
  }

  updateSections() {
    if (!this.hasSectionsTarget) return
    const sections = this.sectionsTarget.querySelectorAll("[data-section]")
    sections.forEach((section) => {
      const type = section.dataset.section
      const shouldShow = this.activeTabValue === "all" || type === this.activeTabValue
      section.classList.toggle("hidden", !shouldShow)
    })
  }

  highlightSelection(element) {
    if (this.selectedElement) {
      this.selectedElement.classList.remove("ring-2", "ring-indigo-400", "ring-offset-2", "ring-offset-slate-900")
    }
    this.selectedElement = element
    this.selectedElement.classList.add("ring-2", "ring-indigo-400", "ring-offset-2", "ring-offset-slate-900")
  }

  renderDetail(data) {
    if (!this.hasDetailTarget) return

    const wrapper = document.createElement("div")
    wrapper.className = "space-y-4"

    if (data.icon) {
      const img = document.createElement("img")
      img.src = data.icon
      img.alt = data.name || "Selected entry"
      img.className = "h-20 w-20 rounded-2xl bg-slate-800/70 object-contain p-3"
      wrapper.appendChild(img)
    }

    const title = document.createElement("div")
    title.innerHTML = `
      <h3 class="text-lg font-semibold text-slate-100">${data.name || "Unknown Entry"}</h3>
      <p class="text-xs text-slate-400">${data.description || "No description available."}</p>
    `
    wrapper.appendChild(title)

    const metaList = document.createElement("div")
    metaList.className = "space-y-1 text-xs text-slate-300"
    if (data.count) metaList.insertAdjacentHTML("beforeend", `<p>Count: <span class="font-semibold text-indigo-200">${data.count}</span></p>`)
    if (data.quantity) metaList.insertAdjacentHTML("beforeend", `<p>Quantity: <span class="font-semibold text-emerald-200">${data.quantity}</span></p>`)
    if (data.itemType) metaList.insertAdjacentHTML("beforeend", `<p>Type: <span class="font-semibold text-slate-200">${data.itemType}</span></p>`)
    wrapper.appendChild(metaList)

    this.detailTarget.replaceChildren(wrapper)
  }
}
