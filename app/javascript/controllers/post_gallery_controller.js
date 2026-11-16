import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "slide", "count", "dot", "previous", "next"]

  connect() {
    this.index = 0
    this.width = this.trackTarget.clientWidth
    this.observer = new ResizeObserver(() => this.resize())
    this.observer.observe(this.trackTarget)
    const image = this.slideTargets[0]?.querySelector("img")
    if (image) {
      this.onImageLoad = () => {
        if (!image.naturalWidth || !image.naturalHeight) return
        const ratio = image.naturalWidth / image.naturalHeight
        this.element.style.setProperty("--post-gallery-ratio", String(ratio))
      }
      image.addEventListener("load", this.onImageLoad)
      this.image = image
      this.onImageLoad()
    }
    this.update()
  }

  disconnect() {
    this.observer.disconnect()
    this.image?.removeEventListener("load", this.onImageLoad)
  }

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
    this.dotTargets.forEach((dot, index) => dot.setAttribute("aria-current", String(index === this.index)))
    if (this.hasPreviousTarget) this.previousTarget.hidden = this.index === 0
    if (this.hasNextTarget) this.nextTarget.hidden = this.index === this.slideTargets.length - 1
  }

  previous() { this.move(-1) }
  next() { this.move(1) }
  go(event) { this.move(Number(event.currentTarget.dataset.index) - this.index) }

  move(direction) {
    const index = Math.max(0, Math.min(this.slideTargets.length - 1, this.index + direction))
    this.trackTarget.scrollTo({ left: index * this.trackTarget.clientWidth, behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth" })
  }
}
