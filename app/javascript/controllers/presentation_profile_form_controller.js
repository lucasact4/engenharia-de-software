import { Controller } from "@hotwired/stimulus"
import { PresentationSelection, estimateText } from "lib/presentation_selection"

// Formulário do perfil da apresentação (admin → Apresentação).
// Organiza o catálogo conforme a entrega e atualiza avisos e tempo. O envio do formulário salva a seleção.
export default class extends Controller {
  static targets = ["slide", "delivery", "estimate", "estimateBox", "group"]
  static values = { catalog: Array, limits: Object }

  connect() {
    this.refresh()
  }

  refresh() {
    const selection = new PresentationSelection(this.catalogValue, this.currentChoices())
    const delivery = this.hasDeliveryTarget ? this.deliveryTarget.value : null

    this.orderRows(selection, delivery)
    this.slideTargets.forEach((row) => {
      const id = row.dataset.slideId
      const slide = selection.slides.get(id)
      const chosen = selection.chosen(id)
      this.syncTitle(row, slide, delivery)
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
      this.estimateBoxTarget.classList.toggle("border-negative-line", over)
      this.estimateBoxTarget.classList.toggle("bg-negative-soft", over)
      this.estimateBoxTarget.classList.toggle("text-negative-ink", over)
      this.estimateBoxTarget.classList.toggle("border-line", !over)
      this.estimateBoxTarget.classList.toggle("bg-surface-muted", !over)
      this.estimateBoxTarget.classList.toggle("text-ink", !over)
    }
  }

  // Título e exigência mudam com a entrega; os textos vêm do catálogo (entrega.yml → exigencias).
  syncTitle(row, slide, delivery) {
    if (!delivery || !slide.titles) return

    row.querySelectorAll("[data-slide-title]").forEach((element) => { element.textContent = slide.titles[delivery] })
    row.querySelector("[data-slide-contents-label]")?.setAttribute("aria-label", `Conteúdos de ${slide.titles[delivery]}`)
    const label = row.querySelector("[data-slide-label]")
    if (!label) return

    const text = slide.labels[delivery]
    const extra = Boolean(text?.endsWith("omplementar"))
    label.hidden = !text
    label.textContent = text || ""
    ;[["border-positive-line", "bg-positive-soft", "text-positive-ink"], ["border-line", "bg-surface-muted", "text-muted"]]
      .forEach((classes, index) => classes.forEach((name) => label.classList.toggle(name, index === 0 ? !extra : extra)))
  }

  orderRows(selection, delivery) {
    if (!delivery) return
    const groups = new Map(this.groupTargets.map((group) => [group.dataset.profileGroup, group]))
    this.slideTargets.sort((left, right) => selection.slides.get(left.dataset.slideId).orders[delivery] - selection.slides.get(right.dataset.slideId).orders[delivery])
      .forEach((row) => {
        const slide = selection.slides.get(row.dataset.slideId)
        const academic = slide.required || !slide.labels[delivery]?.endsWith("omplementar")
        const group = slide.appendix ? "apendice" : academic ? "principal" : "complementar"
        groups.get(group)?.append(row)
      })
  }

  currentChoices() {
    const choices = {}
    this.element.querySelectorAll("input[type=checkbox][data-key]").forEach((input) => {
      choices[input.dataset.key] = input.checked
    })
    return choices
  }
}
