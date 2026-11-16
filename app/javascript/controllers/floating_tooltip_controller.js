import { Controller } from "@hotwired/stimulus"

// Tooltip instantâneo para itens com data-tooltip dentro de áreas com rolagem (que cortariam
// um ::after). Um único balão fixo acompanha o item em foco ou sob o ponteiro.
export default class extends Controller {
  connect() {
    this.bubble = document.createElement("div")
    this.bubble.className = "floating-tooltip"
    this.bubble.setAttribute("role", "presentation")
    this.bubble.hidden = true
    document.body.append(this.bubble)
    this.hide = this.hide.bind(this)
    this.element.addEventListener("scroll", this.hide, { passive: true })
  }

  disconnect() {
    this.element.removeEventListener("scroll", this.hide)
    this.bubble?.remove()
  }

  show(event) {
    const item = event.target.closest("[data-tooltip]")
    if (!item || !this.element.contains(item)) return

    this.bubble.textContent = item.dataset.tooltip
    this.bubble.hidden = false
    const box = item.getBoundingClientRect()
    const width = this.bubble.offsetWidth
    const left = Math.min(Math.max(8, box.left + box.width / 2 - width / 2), window.innerWidth - width - 8)
    this.bubble.style.left = `${left}px`
    this.bubble.style.top = `${box.bottom + 6}px`
  }

  hide(event) {
    if (event?.relatedTarget && event.target.closest?.("[data-tooltip]")?.contains(event.relatedTarget)) return
    if (this.bubble) this.bubble.hidden = true
  }
}
