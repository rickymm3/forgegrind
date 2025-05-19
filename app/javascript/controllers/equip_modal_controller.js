import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["petName", "petStats", "equipButton", "slotField", "container"]
  static values = {
    slot: Number,
    equippedPetId: Number
  }

  connect() {
    this.selectedPetId = null
  }

  open(event) {
    this.slotValue = parseInt(event.currentTarget.dataset.equipModalSlotValue, 10)
    this.equippedPetIdValue = parseInt(event.currentTarget.dataset.equipModalEquippedPetIdValue || "0", 10)

    this.element.querySelector("#equip-modal").classList.remove("hidden")
    this.selectedPetId = null

    this.slotFieldTargets.forEach(input => {
      input.value = this.slotValue
    })
  }

  close() {
    this.element.querySelector("#equip-modal").classList.add("hidden")
    this.selectedPetId = null
  }

  selectPet(event) {
    this.selectedPetId = event.currentTarget.dataset.petId

    this.petNameTarget.textContent = "Fluffy"
    this.petStatsTarget.textContent = "Rarity: Common | Power: 5"
    this.detailSectionTarget.classList.remove("hidden")

    this.equipButtonTarget.closest("form").action = `/user_pets/${this.selectedPetId}/equip`
  }

  backgroundClose(event) {
    if (!this.containerTarget.contains(event.target)) {
      this.close()
    }
  }
}
