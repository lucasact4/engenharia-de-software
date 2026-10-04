import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "slide", "count"]

  connect() {
    this.index = 0
    this.width = this.trackTarget.clientWidth
    this.observer = new ResizeObserver(() => this.resize())
    this.observer.observe(this.trackTarget)
    this.update()
  }

  disconnect() { this.observer.disconnect() }

  resize() {
    const width = this.trackTarget.clientWidth
    if (!width || width === this.width) return
    this.width = width
    this.trackTarget.scrollTo({ left: this.index * width, behavior: "instant" })
  }

  update() {
    this.resize()
    if (!this.width) return
    this.index = Math.max(0, Math.min(this.slideTargets.length - 1, Math.round(this.trackTarget.scrollLeft / this.width)))
    if (this.hasCountTarget) this.countTarget.textContent = `${this.index + 1} / ${this.slideTargets.length}`
  }

  previous() { this.move(-1) }
  next() { this.move(1) }

  move(direction) {
    const index = Math.max(0, Math.min(this.slideTargets.length - 1, this.index + direction))
    this.trackTarget.scrollTo({ left: index * this.trackTarget.clientWidth, behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth" })
  }
}
