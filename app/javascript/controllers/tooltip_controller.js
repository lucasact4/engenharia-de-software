import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "trigger"]

  connect() {
    this.outside = event => { if (!this.element.contains(event.target)) this.hide() }
    this.reposition = event => {
      if (this.element.dataset.visible === "true" && event.target !== this.contentTarget) this.show()
    }
    this.escape = event => { if (event.key === "Escape") this.hide() }
    document.addEventListener("pointerdown", this.outside)
    document.addEventListener("keydown", this.escape)
    window.addEventListener("resize", this.reposition)
    document.addEventListener("scroll", this.reposition, true)
  }

  disconnect() {
    document.removeEventListener("pointerdown", this.outside)
    document.removeEventListener("keydown", this.escape)
    window.removeEventListener("resize", this.reposition)
    document.removeEventListener("scroll", this.reposition, true)
    clearTimeout(this.leaveTimeout)
  }

  show() {
    clearTimeout(this.leaveTimeout)
    this.element.dataset.visible = "true"
    this.triggerTarget.setAttribute("aria-expanded", "true")
    const rect = this.triggerTarget.getBoundingClientRect()
    if (rect.bottom < 0 || rect.top > window.innerHeight) return this.hide()
    const box = this.contentTarget
    box.style.width = `${Math.min(420, window.innerWidth - 32)}px`
    const width = box.getBoundingClientRect().width
    const left = Math.max(16, Math.min(rect.right - width, window.innerWidth - width - 16))
    box.style.left = `${left}px`
    const below = window.innerHeight - rect.bottom - 26
    const above = rect.top - 26
    const placeAbove = below < Math.min(box.scrollHeight, 320) && above > below
    box.style.maxHeight = `${Math.max(80, Math.min(480, placeAbove ? above : below))}px`
    box.style.top = `${placeAbove ? Math.max(16, rect.top - box.getBoundingClientRect().height - 10) : rect.bottom + 10}px`
  }

  hide() {
    clearTimeout(this.leaveTimeout)
    this.pinned = false
    this.element.dataset.visible = "false"
    this.triggerTarget.setAttribute("aria-expanded", "false")
  }

  navigate(event) {
    if (this.element.dataset.visible !== "true" || !["ArrowDown", "ArrowUp"].includes(event.key)) return
    this.contentTarget.scrollBy({ top: event.key === "ArrowDown" ? 80 : -80 })
    event.preventDefault()
  }

  toggle() { this.pinned = !this.pinned; this.pinned ? this.show() : this.hide() }
  leave() {
    this.leaveTimeout = setTimeout(() => {
      if (!this.pinned && !this.element.matches(":hover") && document.activeElement !== this.triggerTarget) this.hide()
    }, 180)
  }
  blur() { if (!this.pinned) this.hide() }
  dismiss(event) { this.hide(); event.stopPropagation() }
}
