import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

const PLACEHOLDER_EMOJI = "+"

export default class extends Controller {
  static values = {
    max: { type: Number, default: 3 },
    previewUrl: String,
    filters: Object
  }

  static targets = [
    "card",
    "checkbox",
    "selectedField",
    "orderField",
    "primaryField",
    "slot",
    "startButton",
    "selectionHint"
  ]

  connect() {
    this.petDataById = new Map()
    this.cardTargets.forEach((card) => {
      const id = this.cardId(card)
      if (!id) return
      this.petDataById.set(id, this.extractCardData(card))
    })

    this.selections = []
    this.primaryId = null
    this.initializeSelectionsFromHidden()
    this.refreshAll()
  }

  toggleCard(event) {
    event.preventDefault()
    const card = event.currentTarget.closest("[data-party-selector-target='card']")
    if (!card || this.cardDisabled(card)) return

    const id = this.cardId(card)
    if (!id) return

    if (this.isSelected(id)) {
      this.removeSelection(id)
    } else {
      this.addSelection(id)
    }
  }

  removeFromSlot(event) {
    event.preventDefault()
    const id = event.currentTarget.dataset.userPetId
    if (id) this.removeSelection(id)
  }

  setPrimaryFromSlot(event) {
    const id = event.currentTarget.dataset.userPetId
    if (!id || !this.isSelected(id)) return
    this.primaryId = id
    this.updateHiddenFields()
    this.refreshSlots()
    this.refreshCards()
    this.submitPreview()
  }

  addSelection(id) {
    if (this.isSelected(id)) return
    if (this.selections.length >= this.maxValue) {
      this.flashLimit()
      return
    }
    this.selections.push(id)
    if (!this.primaryId) {
      this.primaryId = id
    }
    this.setCheckboxState(id, true)
    this.refreshAll()
    this.submitPreview()
  }

  removeSelection(id) {
    const index = this.selections.indexOf(id)
    if (index === -1) return

    this.selections.splice(index, 1)
    this.setCheckboxState(id, false)
    if (this.primaryId === id) {
      this.primaryId = this.selections[0] || null
    }
    this.refreshAll()
    this.submitPreview()
  }

  initializeSelectionsFromHidden() {
    const selected = this.collectValues(this.selectedFields)
    selected.forEach((id) => {
      if (this.petDataById.has(id) && !this.isSelected(id)) {
        this.selections.push(id)
      }
    })

    const primary = this.hiddenValue(this.primaryFields[0])
    if (primary && this.selections.includes(primary)) {
      this.primaryId = primary
    } else {
      this.primaryId = this.selections[0] || null
    }
  }

  refreshAll() {
    this.refreshSlots()
    this.refreshCards()
    this.updateHiddenFields()
    this.refreshStartButton()
    this.refreshSelectionHint()
  }

  refreshSlots() {
    const data = this.selections.map((id) => this.petDataById.get(id)).filter(Boolean)

    this.slotTargets.forEach((slot, index) => {
      const entry = data[index]
      const mainButton = slot.querySelector("[data-slot-element='main']")
      const image = slot.querySelector("[data-slot-element='image']")
      const placeholder = slot.querySelector("[data-slot-element='placeholder']")
      const nameLabel = slot.querySelector("[data-slot-element='name']")
      const abilityLabel = slot.querySelector("[data-slot-element='ability']")
      const removeButton = slot.querySelector("[data-slot-element='remove']")
      const primaryBadge = slot.querySelector("[data-slot-element='primary']")

      if (entry) {
        const { userPetId, displayName, abilityName, abilityTagline, imageUrl } = entry

        if (mainButton) {
          mainButton.dataset.userPetId = userPetId
          mainButton.disabled = false
          mainButton.classList.remove("cursor-not-allowed", "opacity-60")
        }
        if (removeButton) {
          removeButton.dataset.userPetId = userPetId
          removeButton.classList.remove("hidden")
        }
        if (image) {
          if (imageUrl) {
            image.src = imageUrl
            image.classList.remove("hidden")
          } else {
            image.classList.add("hidden")
          }
        }
        if (placeholder) {
          placeholder.classList.add("hidden")
        }
        if (nameLabel) {
          nameLabel.textContent = displayName
          nameLabel.classList.remove("text-slate-400")
        }
        if (abilityLabel) {
          abilityLabel.textContent = abilityName || abilityTagline || "Specialist"
          abilityLabel.classList.remove("text-slate-400")
        }
        if (primaryBadge) {
          primaryBadge.classList.toggle("hidden", this.primaryId !== userPetId)
        }
      } else {
        if (mainButton) {
          delete mainButton.dataset.userPetId
          mainButton.disabled = true
          mainButton.classList.add("cursor-not-allowed", "opacity-60")
        }
        if (removeButton) {
          delete removeButton.dataset.userPetId
          removeButton.classList.add("hidden")
        }
        if (image) {
          image.classList.add("hidden")
        }
        if (placeholder) {
          placeholder.textContent = PLACEHOLDER_EMOJI
          placeholder.classList.remove("hidden")
        }
        if (nameLabel) {
          nameLabel.textContent = "Empty slot"
          nameLabel.classList.add("text-slate-400")
        }
        if (abilityLabel) {
          abilityLabel.textContent = "Select a companion"
          abilityLabel.classList.add("text-slate-400")
        }
        if (primaryBadge) {
          primaryBadge.classList.add("hidden")
        }
      }
    })
  }

  refreshCards() {
    const selectedSet = new Set(this.selections)
    this.cardTargets.forEach((card) => {
      const id = this.cardId(card)
      const isSelected = selectedSet.has(id)
      card.classList.toggle("party-selected", isSelected)
      const button = card.querySelector("button")
      if (button) {
        button.classList.toggle("border-indigo-500", isSelected)
        button.classList.toggle("bg-indigo-50", isSelected)
        button.classList.toggle("shadow-md", isSelected)
      }
      const primaryBadge = card.querySelector("[data-card-element='primary']")
      if (primaryBadge) {
        primaryBadge.classList.toggle("hidden", this.primaryId !== id)
      }
    })
  }

  refreshStartButton() {
    if (!this.hasStartButtonTarget) return
    const disabled = this.selections.length === 0
    this.startButtonTarget.disabled = disabled
    this.startButtonTarget.classList.toggle("opacity-60", disabled)
    this.startButtonTarget.classList.toggle("cursor-not-allowed", disabled)
  }

  refreshSelectionHint() {
    if (!this.hasSelectionHintTarget) return
    this.selectionHintTarget.textContent = `${this.selections.length} of ${this.maxValue} selected`
  }

  updateHiddenFields() {
    const joined = this.selections.join(",")
    this.assignHiddenValue(this.selectedFields, joined)
    this.assignHiddenValue(this.orderFields, joined)
    this.assignHiddenValue(this.primaryFields, this.primaryId || "")
  }

  submitPreview() {
    if (!this.hasPreviewUrlValue) return

    const formData = new FormData()
    formData.append("selected_pet_ids", this.selections.join(","))
    formData.append("party_order", this.selections.join(","))
    if (this.primaryId) {
      formData.append("primary_user_pet_id", this.primaryId)
    }

    const filters = this.filtersValue || {}
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== "") {
        formData.append(key, value)
      }
    })

    fetch(this.previewUrlValue, {
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

  flashLimit() {
    this.element.classList.add("party-selector-limit")
    clearTimeout(this.limitTimeout)
    this.limitTimeout = setTimeout(() => {
      this.element.classList.remove("party-selector-limit")
    }, 500)
  }

  assignHiddenValue(field, value) {
    this.normalizeFields(field).forEach((element) => {
      if (element) element.value = value
    })
  }

  hiddenValues(field) {
    if (!field || !field.value) return []
    return field.value.split(",").map((value) => value.trim()).filter((value) => value.length > 0)
  }

  hiddenValue(field) {
    if (!field || !field.value) return null
    return field.value.toString().trim() || null
  }

  setCheckboxState(id, state) {
    const checkbox = this.checkboxTargets.find((target) => this.cardId(target.closest("[data-party-selector-target='card']")) === id)
    if (checkbox) {
      checkbox.checked = state
    }
  }

  extractCardData(card) {
    return {
      userPetId: this.cardId(card),
      displayName: card.dataset.displayName || card.dataset.petName || "Companion",
      abilityName: card.dataset.abilityName,
      abilityTagline: card.dataset.abilityTagline,
      imageUrl: card.dataset.imageUrl,
      abilityTags: (card.dataset.abilityTags || "").split(",").filter((tag) => tag.length > 0)
    }
  }

  cardId(card) {
    return card?.dataset?.userPetId || null
  }

  cardDisabled(card) {
    return card.dataset.disabled === "true"
  }

  isSelected(id) {
    return this.selections.includes(id)
  }

  get csrfToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    return meta ? meta.content : ""
  }

  get selectedFields() {
    return this.hasSelectedFieldTarget ? this.selectedFieldTargets : []
  }

  get orderFields() {
    return this.hasOrderFieldTarget ? this.orderFieldTargets : []
  }

  get primaryFields() {
    return this.hasPrimaryFieldTarget ? this.primaryFieldTargets : []
  }

  collectValues(fields) {
    const values = new Set()
    this.normalizeFields(fields).forEach((field) => {
      this.hiddenValues(field).forEach((value) => values.add(value))
    })
    return Array.from(values)
  }

  normalizeFields(fieldOrCollection) {
    if (!fieldOrCollection) return []
    if (fieldOrCollection instanceof Element) return [fieldOrCollection]
    return Array.from(fieldOrCollection).filter(Boolean)
  }
}
