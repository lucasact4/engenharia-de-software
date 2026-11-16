import { Controller } from "@hotwired/stimulus"

// Troca o balão nativo do atributo title (lento e fora do tema) por um tooltip instantâneo.
// Enquanto o tooltip aparece, o title vai para data-native-title e volta ao sair; ícones sem
// texto recebem o mesmo texto como aria-label, para não perderem o nome acessível.
export default class extends Controller {
  connect() {
    this.bubble = document.createElement("div")
    this.bubble.className = "floating-tooltip"
    this.bubble.setAttribute("role", "presentation")
    this.bubble.hidden = true
    document.body.append(this.bubble)

    this.show = this.show.bind(this)
    this.hide = this.hide.bind(this)
    this.element.addEventListener("mouseover", this.show)
    this.element.addEventListener("focusin", this.show)
    this.element.addEventListener("mouseout", this.hide)
    this.element.addEventListener("focusout", this.hide)
    window.addEventListener("scroll", this.hide, { capture: true, passive: true })
  }

  disconnect() {
    this.restore()
    this.element.removeEventListener("mouseover", this.show)
    this.element.removeEventListener("focusin", this.show)
    this.element.removeEventListener("mouseout", this.hide)
    this.element.removeEventListener("focusout", this.hide)
    window.removeEventListener("scroll", this.hide, { capture: true })
    this.bubble?.remove()
  }

  show(event) {
    const target = this.targetFor(event.target)
    if (!target || target === this.current) return
    if (event.type === "mouseover" && window.matchMedia("(hover: none)").matches) return

    this.restore()
    const text = (target.getAttribute("title") || target.dataset.nativeTitle || target.getAttribute("aria-label") || "").trim()
    if (!text) return

    this.current = target
    this.hadTitle = target.hasAttribute("title") || "nativeTitle" in target.dataset
    if (this.hadTitle) {
      target.dataset.nativeTitle = text
      target.removeAttribute("title")
    }
    if (!target.hasAttribute("aria-label") && !target.hasAttribute("aria-labelledby") && !target.textContent.trim()) {
      target.setAttribute("aria-label", text)
      target.dataset.tooltipLabel = "true"
    }

    this.bubble.textContent = text
    this.bubble.hidden = false
    const box = target.getBoundingClientRect()
    const width = this.bubble.offsetWidth
    const height = this.bubble.offsetHeight
    const left = Math.min(Math.max(8, box.left + box.width / 2 - width / 2), window.innerWidth - width - 8)
    const below = box.bottom + 6 + height <= window.innerHeight - 8
    this.bubble.style.left = `${left}px`
    this.bubble.style.top = `${below ? box.bottom + 6 : box.top - height - 6}px`
  }

  // Elementos com title; e botões só de ícone (ou ícone + contador) que têm apenas aria-label.
  targetFor(node) {
    const titled = node.closest?.("[title], [data-native-title]")
    if (titled && this.element.contains(titled)) return titled

    const iconOnly = node.closest?.("a[aria-label], button[aria-label], summary[aria-label]")
    if (!iconOnly || iconOnly.hasAttribute("data-tooltip") || !this.element.contains(iconOnly)) return null
    return /^[\d\s.,]*$/.test(iconOnly.textContent) ? iconOnly : null
  }

  hide(event) {
    if (event?.type === "mouseout" && this.current?.contains(event.relatedTarget)) return
    this.restore()
  }

  restore() {
    if (this.bubble) this.bubble.hidden = true
    const target = this.current
    this.current = null
    if (!target) return

    if (this.hadTitle && target.dataset.nativeTitle) target.setAttribute("title", target.dataset.nativeTitle)
    delete target.dataset.nativeTitle
    if (target.dataset.tooltipLabel) {
      target.removeAttribute("aria-label")
      delete target.dataset.tooltipLabel
    }
  }
}
