import { Controller } from "@hotwired/stimulus"

// Destaca relações sem alterar o desenho; o diagrama permanece legível sem JavaScript.
export default class extends Controller {
  static targets = ["status"]

  connect() {
    this.selected = null
    this.describeSelection()
  }

  preview(event) {
    this.highlight(event.currentTarget.dataset.node)
  }

  clearPreview(event) {
    if (event.currentTarget.contains(event.relatedTarget)) return
    this.highlight(this.selected)
  }

  select(event) {
    const node = event.currentTarget.closest("[data-node]").dataset.node
    this.selected = this.selected === node ? null : node
    this.highlight(this.selected)
    this.element.querySelectorAll(".apr-data-node__select").forEach((button) => {
      button.setAttribute("aria-pressed", String(button.closest("[data-node]").dataset.node === this.selected))
    })
    this.describeSelection()
  }

  reset() {
    this.selected = null
    this.element.querySelectorAll("[aria-pressed]").forEach((button) => button.setAttribute("aria-pressed", "false"))
    this.highlight(null)
    this.describeSelection()
  }

  describeSelection() {
    if (!this.hasStatusTarget) return
    this.statusTarget.hidden = !this.selected
    this.statusTarget.replaceChildren()
    if (!this.selected) return

    const edges = [...this.element.querySelectorAll("[data-relation]")].filter((edge) =>
      edge.dataset.source === this.selected || edge.dataset.target === this.selected)
    const heading = document.createElement("strong")
    const card = this.element.querySelector(`[data-node="${this.selected}"]`)
    heading.textContent = `${card.querySelector(".apr-data-node__select span").textContent} · ${edges.length} conexões`
    this.statusTarget.append(heading)
    edges.forEach((edge) => {
      const item = document.createElement("span")
      const cardinality = [edge.dataset.sourceCardinality, edge.dataset.targetCardinality].filter(Boolean).join(" : ")
      item.textContent = `${edge.dataset.label} → ${edge.dataset.targetTitle}${cardinality ? ` · ${cardinality}` : ""}`
      this.statusTarget.append(item)
    })
  }

  highlight(node) {
    const connected = new Set(node ? [node] : [])
    this.element.classList.toggle("has-selection", Boolean(node))
    this.element.querySelectorAll("[data-relation]").forEach((edge) => {
      const active = Boolean(node) && (edge.dataset.source === node || edge.dataset.target === node)
      edge.classList.toggle("is-linked", active)
      if (active) {
        connected.add(edge.dataset.source)
        connected.add(edge.dataset.target)
      }
    })
    this.element.querySelectorAll("[data-node]").forEach((card) => {
      card.classList.toggle("is-linked", connected.has(card.dataset.node))
      card.classList.toggle("is-selected", card.dataset.node === node)
      card.querySelectorAll("[data-field]").forEach((field) => {
        const active = [...this.element.querySelectorAll("[data-relation].is-linked")].some((edge) =>
          edge.dataset.source === card.dataset.node && edge.dataset.column === field.dataset.field)
        field.classList.toggle("is-linked", active)
      })
    })
  }
}
