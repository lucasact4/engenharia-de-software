import { Controller } from "@hotwired/stimulus"

// Exibe blocos conforme o valor escolhido (ex.: campos de encerramento quando o destino é "closed").
// Sem JavaScript todos os blocos ficam visíveis, com textos explicando quando se aplicam.
export default class extends Controller {
  static targets = ["input", "block"]

  connect() {
    this.update()
  }

  update() {
    const value = this.currentValue()
    this.blockTargets.forEach((block) => {
      const values = (block.dataset.revealWhen || "").split(" ")
      block.hidden = !values.includes(value)
    })
  }

  currentValue() {
    const input = this.inputTargets.find((element) => element.type !== "radio" || element.checked)
    return input ? input.value : ""
  }
}
