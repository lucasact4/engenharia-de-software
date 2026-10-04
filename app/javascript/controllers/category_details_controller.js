import { Controller } from "@hotwired/stimulus"

// Mostra o detalhamento apenas para categorias que o exigem. Sem JavaScript o campo fica
// sempre visível; o servidor descarta o texto quando a categoria não pede detalhes.
export default class extends Controller {
  static targets = ["select", "details"]
  static values = { ids: Array }

  connect() {
    this.toggle()
  }

  toggle() {
    if (!this.hasSelectTarget || !this.hasDetailsTarget) return

    const required = this.idsValue.map(String).includes(this.selectTarget.value)
    this.detailsTarget.hidden = !required
  }
}
