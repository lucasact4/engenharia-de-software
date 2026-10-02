import { Controller } from "@hotwired/stimulus"
import { PresentationSelection, estimateText } from "lib/presentation_selection"

// Formulário do perfil da apresentação (admin → Apresentação).
// Só atualiza avisos e a estimativa de tempo; quem salva é o envio normal do formulário.
export default class extends Controller {
  static targets = ["slide", "delivery", "estimate", "estimateBox"]
  static values = { catalog: Array, limits: Object }

  connect() {
    this.refresh()
  }

  refresh() {
    const selection = new PresentationSelection(this.catalogValue, this.currentChoices())

    this.slideTargets.forEach((row) => {
      const id = row.dataset.slideId
      const slide = selection.slides.get(id)
      const chosen = selection.chosen(id)
      const hint = row.querySelector("[data-hint]")
      const items = row.querySelector("[data-items]")
      const count = row.querySelector("[data-count]")

      items?.classList.toggle("opacity-60", !chosen)
      if (count) count.textContent = slide.items.filter((item) => selection.chosen(item.key)).length
      if (!hint) return

      if (slide.required) hint.textContent = "Sempre exibido; não pode ser ocultado."
      else if (selection.withoutContent(id)) hint.textContent = "Nenhum conteúdo marcado: o slide será omitido."
      else if (!chosen && slide.items.length > 0) hint.textContent = "Slide oculto. As escolhas dos conteúdos ficam guardadas para quando ele voltar."
      else hint.textContent = ""
    })

    const limit = this.hasDeliveryTarget ? this.limitsValue[this.deliveryTarget.value] || null : null
    const total = selection.totalSeconds()
    const over = Boolean(limit && total > limit)
    if (this.hasEstimateTarget) this.estimateTarget.textContent = estimateText(total, selection.mainSlides().length, limit)
    if (this.hasEstimateBoxTarget) {
      this.estimateBoxTarget.classList.toggle("border-red-200", over)
      this.estimateBoxTarget.classList.toggle("bg-red-50", over)
      this.estimateBoxTarget.classList.toggle("text-red-800", over)
      this.estimateBoxTarget.classList.toggle("border-slate-200", !over)
      this.estimateBoxTarget.classList.toggle("bg-slate-50", !over)
      this.estimateBoxTarget.classList.toggle("text-slate-700", !over)
    }
  }

  currentChoices() {
    const choices = {}
    this.element.querySelectorAll("input[type=checkbox][data-key]").forEach((input) => {
      choices[input.dataset.key] = input.checked
    })
    return choices
  }
}
