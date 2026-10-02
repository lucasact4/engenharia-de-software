// Regras de visibilidade da apresentação, compartilhadas pela página pública
// (controllers/presentation_controller.js) e pelo formulário do admin.
// Espelha app/models/presentation/selection.rb: mantenha os dois em sincronia.
//
// catalog: [{ id, title, appendix, required, seconds, default, items: [{ key, title, default, parent }] }]
// choices: { "<slide>": true, "<slide>.<conteúdo>": false, ... }
export class PresentationSelection {
  constructor(catalog, choices = {}) {
    this.catalog = catalog
    this.choices = { ...choices }
    this.slides = new Map(catalog.map((slide) => [slide.id, slide]))
    this.items = new Map(catalog.flatMap((slide) => slide.items.map((item) => [item.key, item])))
  }

  set(key, value) {
    if (this.slides.get(key)?.required) return
    if (this.slides.has(key) || this.items.has(key)) this.choices[key] = Boolean(value)
  }

  chosen(key) {
    const slide = this.slides.get(key)
    if (slide?.required) return true
    if (key in this.choices) return this.choices[key]
    return Boolean((slide || this.items.get(key))?.default)
  }

  itemVisible(key) {
    const item = this.items.get(key)
    if (!item) return false
    return this.chosen(key) && (!item.parent || this.itemVisible(item.parent))
  }

  slideVisible(id) {
    const slide = this.slides.get(id)
    if (!slide) return false
    if (slide.required) return true
    if (!this.chosen(id)) return false
    return slide.items.length === 0 || slide.items.some((item) => this.itemVisible(item.key))
  }

  // Marcado, mas sem nenhum conteúdo visível: será omitido.
  withoutContent(id) {
    const slide = this.slides.get(id)
    return Boolean(slide && !slide.required && this.chosen(id) && slide.items.length > 0 && !this.slideVisible(id))
  }

  visibleSlides() {
    return this.catalog.filter((slide) => this.slideVisible(slide.id))
  }

  labels() {
    const labels = {}
    let number = 0
    let letter = "A".charCodeAt(0)
    this.visibleSlides().forEach((slide) => {
      if (slide.appendix) {
        labels[slide.id] = String.fromCharCode(letter++)
      } else {
        number += 1
        labels[slide.id] = String(number).padStart(2, "0")
      }
    })
    return labels
  }

  mainSlides() {
    return this.visibleSlides().filter((slide) => !slide.appendix)
  }

  totalSeconds() {
    return this.mainSlides().reduce((sum, slide) => sum + slide.seconds, 0)
  }

  equals(choices) {
    return [...this.slides.keys(), ...this.items.keys()].every((key) => this.chosen(key) === Boolean(choices[key]))
  }
}

// Mesmo formato de PresentationsHelper#presentation_duration.
export function formatDuration(seconds) {
  const minutes = Math.floor(seconds / 60)
  const rest = seconds % 60
  if (minutes === 0) return `${rest}s`
  return rest === 0 ? `${minutes}min` : `${minutes}min${String(rest).padStart(2, "0")}s`
}

// Mesmo texto de PresentationsHelper#presentation_estimate_text.
export function estimateText(total, count, limit) {
  const base = `Estimativa: ${formatDuration(total)} em ${count} ${count === 1 ? "slide principal" : "slides principais"}`
  if (!limit) return `${base} · sem limite de tempo definido para esta entrega.`
  if (total > limit) return `${base} · acima do limite de ${formatDuration(limit)}.`
  return `${base} · limite de ${formatDuration(limit)}.`
}
