import { Controller } from "@hotwired/stimulus"

// Navega pelas capturas originais; a ampliação usa o lightbox da apresentação.
export default class extends Controller {
  static targets = ["featured", "thumbnail", "strip", "control", "position"]
  static values = { index: Number }

  connect() {
    this.controlTargets.forEach((button) => {
      button.hidden = false
      button.disabled = this.thumbnailTargets.length < 2
    })
    this.show(this.indexValue)
  }

  previous() { this.show(this.indexValue - 1) }
  next() { this.show(this.indexValue + 1) }

  select(event) {
    event.preventDefault()
    this.show(Number(event.currentTarget.dataset.galleryIndex))
  }

  keydown(event) {
    if (event.altKey || event.ctrlKey || event.metaKey) return
    const keys = ["ArrowLeft", "ArrowRight", "Home", "End"]
    if (!keys.includes(event.key)) return
    event.preventDefault()
    event.stopPropagation()
    const count = this.thumbnailTargets.length
    const index = event.key === "Home" ? 0 : event.key === "End" ? count - 1 : this.indexValue + (event.key === "ArrowLeft" ? -1 : 1)
    this.show(index)
    this.thumbnailTargets[this.indexValue].focus({ preventScroll: true })
  }

  show(index) {
    const count = this.thumbnailTargets.length
    if (!count) return
    this.indexValue = ((index % count) + count) % count
    const selected = this.thumbnailTargets[this.indexValue]
    const source = selected.querySelector("img")
    const image = this.featuredTarget.querySelector("img")
    const trigger = this.featuredTarget.querySelector(".apr-figure__zoom")
    const caption = selected.dataset.caption
    image.src = source.src
    image.alt = source.alt
    image.dataset.zoomSrc = selected.dataset.zoomSrc
    trigger.dataset.zoomSrc = selected.dataset.zoomSrc
    trigger.setAttribute("aria-label", `Ampliar imagem: ${caption}`)
    this.featuredTarget.querySelector(".apr-figure__title").textContent = caption
    this.featuredTarget.querySelector(".apr-figure__open").href = selected.dataset.zoomSrc
    this.thumbnailTargets.forEach((thumbnail, position) => {
      const active = position === this.indexValue
      thumbnail.classList.toggle("is-selected", active)
      thumbnail.setAttribute("aria-current", String(active))
    })
    this.positionTarget.textContent = `${this.indexValue + 1} / ${count}`
    // Rola somente a faixa de miniaturas, sem mover a página ou o slide.
    const frame = this.stripTarget.getBoundingClientRect()
    const item = selected.getBoundingClientRect()
    if (item.left < frame.left) this.stripTarget.scrollLeft -= frame.left - item.left
    if (item.right > frame.right) this.stripTarget.scrollLeft += item.right - frame.right
  }
}
