import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text", "toggle"]
  static values = { full: Boolean }

  connect() {
    this.expanded = this.fullValue
    this.width = 0
    this.observer = new ResizeObserver(([entry]) => {
      if (entry.contentRect.width === this.width) return
      this.width = entry.contentRect.width
      this.measure()
    })
    this.observer.observe(this.element)
    document.fonts?.ready.then(() => { if (this.element.isConnected) this.measure() })
    this.measure()
  }

  disconnect() { this.observer.disconnect() }

  measure() {
    if (this.fullValue) return
    this.textTarget.classList.add("is-collapsed")
    const overflowing = this.textTarget.scrollHeight > this.textTarget.clientHeight + 1
    this.toggleTarget.hidden = !overflowing
    this.textTarget.classList.toggle("is-collapsed", overflowing && !this.expanded)
    this.updateLabel()
  }

  toggle() {
    this.expanded = !this.expanded
    this.textTarget.classList.toggle("is-collapsed", !this.expanded)
    this.updateLabel()
  }

  updateLabel() {
    this.toggleTarget.textContent = this.expanded ? "Ver menos" : "Ver mais"
    this.toggleTarget.setAttribute("aria-expanded", String(this.expanded))
  }
}
