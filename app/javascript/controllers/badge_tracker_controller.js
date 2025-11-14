import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["row", "slider", "value"];

  toggle(event) {
    const row = event.currentTarget.closest("[data-badge-tracker-target='row']");
    if (!row) return;

    const checked = event.currentTarget.checked;
    row.classList.toggle("opacity-60", !checked);
    row.querySelectorAll("select, input[type='number'], input[type='range']").forEach((input) => {
      input.disabled = !checked;
    });
  }

  syncFromSlider(event) {
    const slider = event.currentTarget;
    const row = slider.closest("[data-badge-tracker-target='row']");
    if (!row) return;
    const input = row.querySelector("input[type='number']");
    if (input) input.value = slider.value;
  }

  syncFromInput(event) {
    const input = event.currentTarget;
    const row = input.closest("[data-badge-tracker-target='row']");
    if (!row) return;
    const slider = row.querySelector("input[type='range']");
    if (slider) slider.value = input.value;
  }
}
