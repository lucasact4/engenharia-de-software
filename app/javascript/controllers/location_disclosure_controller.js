import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel"]

  toggle() {
    const expanded = this.buttonTarget.getAttribute("aria-expanded") === "true"
    this.panelTarget.hidden = expanded
    this.buttonTarget.setAttribute("aria-expanded", String(!expanded))
    this.buttonTarget.textContent = expanded ? "Mostrar Localização" : "Ocultar Localização"

    if (!expanded) {
      this.panelTarget.querySelector("[data-controller~='location-preview']")
        ?.dispatchEvent(new Event("location-preview:shown"))
    }
  }
}
