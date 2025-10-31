import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "panel", "grid", "sort", "filter", "empty", "count"]
  static values = {
    active: Number,
    defaultSort: String
  }

  initialize() {
    this.emptyFrameHTML = null
  }

  connect() {
    this.cacheEmptyFrameHTML()
    this.applySortFilter()

    if (this.hasActiveValue && this.activeValue > 0) {
      this.activateById(this.activeValue)
    } else {
      this.hidePanel()
    }
  }

  get defaultSortSetting() {
    return this.hasDefaultSortValue ? this.defaultSortValue : "level-desc"
  }

  sortChanged() {
    this.applySortFilter()
  }

  filterChanged() {
    this.applySortFilter()
  }

  select(event) {
    const card = event.currentTarget
    const petId = parseInt(card.dataset.petId, 10)
    this.activate(card)
    this.activeValue = petId
  }

  activateById(id) {
    const card = this.cardTargets.find((target) => parseInt(target.dataset.petId, 10) === id)
    if (card) {
      this.activate(card)
      this.activeValue = id
    }
  }

  activate(card) {
    this.cardTargets.forEach((target) => {
      this.removeSelectedClasses(target)
    })
    this.addSelectedClasses(card)
    this.showPanel()
  }

  frameLoaded(event) {
    if (event.target.id !== "pet_detail") return

    const selectedId = parseInt(event.target.dataset.selectedPetId || "0", 10)
    if (selectedId > 0) {
      this.activateById(selectedId)
      this.showPanel()
    } else {
      this.cacheEmptyFrameHTML(true)
      if (this.activeValue === 0) {
        this.cardTargets.forEach((target) => this.removeSelectedClasses(target))
        this.hidePanel()
      }
    }
  }

  addSelectedClasses(element) {
    this.selectedClasses(element).forEach((cls) => element.classList.add(cls))
    this.toggleImageAccent(element, true)
  }

  removeSelectedClasses(element) {
    this.selectedClasses(element).forEach((cls) => element.classList.remove(cls))
    this.toggleImageAccent(element, false)
  }

  selectedClasses(element) {
    return (element.dataset.selectedClasses || "").split(" ").filter(Boolean)
  }

  toggleImageAccent(element, active) {
    const image = element.querySelector(".pet-card-image")
    if (!image) return

    if (active) {
      image.classList.add("opacity-100", "drop-shadow-[0_0_12px_rgba(99,102,241,0.45)]")
      image.classList.remove("opacity-95")
    } else {
      image.classList.remove("opacity-100", "drop-shadow-[0_0_12px_rgba(99,102,241,0.45)]")
      image.classList.add("opacity-95")
    }
  }

  applySortFilter() {
    if (!this.hasGridTarget) return

    const cards = Array.from(this.cardTargets)
    if (cards.length === 0) return

    const sortValue = this.hasSortTarget ? this.sortTarget.value : this.defaultSortSetting
    if (this.hasSortTarget) {
      this.sortTarget.value = sortValue || this.defaultSortSetting
    }

    const comparator = this.sortComparator(sortValue || this.defaultSortSetting)
    cards.sort(comparator)
    cards.forEach((card) => this.gridTarget.appendChild(card))

    const filterValue = this.hasFilterTarget ? this.filterTarget.value : "all"
    const normalizedFilter = (filterValue || "all").toLowerCase()

    let visibleCount = 0
    let activeStillVisible = false

    cards.forEach((card) => {
      const types = (card.dataset.types || "").split("|").filter(Boolean)
      const matchesType = normalizedFilter === "all" || types.includes(normalizedFilter)
      card.classList.toggle("hidden", !matchesType)

      if (matchesType) {
        visibleCount += 1
        if (parseInt(card.dataset.petId, 10) === this.activeValue) {
          activeStillVisible = true
        }
      }
    })

    if (!activeStillVisible && this.activeValue > 0) {
      this.clearSelection()
    }

    this.updateCount(visibleCount, cards.length)
    this.toggleEmptyState(visibleCount === 0)
  }

  sortComparator(sortValue) {
    switch (sortValue) {
      case "level-asc":
        return (a, b) => parseInt(a.dataset.level || "0", 10) - parseInt(b.dataset.level || "0", 10)
      case "level-desc":
        return (a, b) => parseInt(b.dataset.level || "0", 10) - parseInt(a.dataset.level || "0", 10)
      case "name-desc":
        return (a, b) => (b.dataset.name || "").localeCompare(a.dataset.name || "")
      case "type-asc":
        return (a, b) => {
          const typeA = (a.dataset.types || "").split("|")[0] || ""
          const typeB = (b.dataset.types || "").split("|")[0] || ""
          return typeA.localeCompare(typeB)
        }
      case "name-asc":
      default:
        return (a, b) => (a.dataset.name || "").localeCompare(b.dataset.name || "")
    }
  }

  updateCount(visible, total) {
    if (!this.hasCountTarget) return
    this.countTarget.textContent = `Showing ${visible} / ${total} pets`
  }

  toggleEmptyState(isEmpty) {
    if (!this.hasEmptyTarget) return
    this.emptyTarget.classList.toggle("hidden", !isEmpty)
  }

  clearSelection() {
    this.cardTargets.forEach((target) => this.removeSelectedClasses(target))
    this.activeValue = 0
    this.hidePanel()
    const frame = document.getElementById("pet_detail")
    if (frame) {
      frame.dataset.selectedPetId = "0"
      if (this.emptyFrameHTML) {
        frame.innerHTML = this.emptyFrameHTML
        this.cacheEmptyFrameHTML(true)
      }
    }
  }

  showPanel() {
    if (!this.hasPanelTarget) return

    if (window.matchMedia("(min-width: 1024px)").matches) {
      this.panelTarget.classList.remove("hidden")
      this.panelTarget.classList.add("block")
    } else {
      this.panelTarget.classList.remove("hidden")
      this.panelTarget.classList.add("block")
    }
  }

  hidePanel() {
    if (!this.hasPanelTarget) return

    if (window.matchMedia("(min-width: 1024px)").matches) {
      // Keep panel visible on larger screens with placeholder content
      this.panelTarget.classList.remove("hidden")
      this.panelTarget.classList.add("block")
    } else {
      this.panelTarget.classList.add("hidden")
      this.panelTarget.classList.remove("block")
    }
  }

  cacheEmptyFrameHTML(force = false) {
    if (!force && this.emptyFrameHTML) return
    const frame = document.getElementById("pet_detail")
    if (frame) {
      this.emptyFrameHTML = frame.innerHTML
    }
  }
}
