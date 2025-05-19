// app/javascript/controllers/energy_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    interval:   Number,
    base:       Number,
    energy:     Number,
    multiplier: Number
  }
  static targets = ["value"]

  connect() {
    // Initialize the displayed energy
    this.currentEnergy = this.energyValue
    this.valueTarget.textContent = Math.floor(this.currentEnergy)

    // Start client-side tick using the base interval (in seconds)
    this.timer = setInterval(() => this.tick(), this.intervalValue * 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    // Calculate gain = base value * multiplier
    const gain = this.baseValue * this.multiplierValue

    console.log(
      `Energy Tick → base: ${this.baseValue}, multiplier: ${this.multiplierValue.toFixed(2)}, gain: ${gain.toFixed(2)}`
    )

    // Increment and update display
    this.currentEnergy += gain
    this.valueTarget.textContent = Math.floor(this.currentEnergy)
  }
}