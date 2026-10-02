import { Controller } from "@hotwired/stimulus"

// Apresentação em slides (/apresentacao).
// Sem JavaScript, a página continua legível no modo leitura (todos os slides em sequência).
export default class extends Controller {
  static targets = [
    "slide", "enhanced", "modeLabel", "fullscreenButton",
    "prevButton", "nextButton", "counter", "currentTitle", "progress", "announcer",
    "indexDialog", "indexLink", "lightbox", "lightboxMedia", "lightboxCaption", "actualSizeButton"
  ]

  connect() {
    this.index = 0
    this.presenting = new URLSearchParams(window.location.search).get("modo") !== "leitura"
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")

    this.enhancedTargets.forEach((element) => { element.hidden = false })
    if (this.hasFullscreenButtonTarget) this.fullscreenButtonTarget.hidden = !document.fullscreenEnabled
    this.element.classList.add("apr--js")

    this.onKeydown = this.handleKeydown.bind(this)
    this.onFullscreenChange = this.syncFullscreen.bind(this)
    this.onHashChange = this.handleHashChange.bind(this)
    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("fullscreenchange", this.onFullscreenChange)
    window.addEventListener("hashchange", this.onHashChange)

    const initial = this.indexFromHash()
    this.index = initial ?? 0
    this.applyMode({ scroll: initial !== null })
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("fullscreenchange", this.onFullscreenChange)
    window.removeEventListener("hashchange", this.onHashChange)
    document.documentElement.classList.remove("apr-lock")
    if (document.fullscreenElement) document.exitFullscreen().catch(() => {})
  }

  // Navegação

  next() {
    this.step(1)
  }

  previous() {
    this.step(-1)
  }

  step(offset) {
    const group = this.currentGroup()
    const target = group[group.indexOf(this.index) + offset]
    if (target !== undefined) this.show(target)
  }

  edge(last) {
    const group = this.currentGroup()
    this.show(last ? group[group.length - 1] : group[0])
  }

  show(index, { focus = false, updateHash = true } = {}) {
    if (index < 0 || index >= this.slideTargets.length) return

    this.element.dataset.direction = index >= this.index ? "forward" : "backward"
    this.index = index

    const leavingFocus = this.slideTargets.some((slide) => slide.contains(document.activeElement))

    this.slideTargets.forEach((slide, position) => {
      const active = position === index
      slide.classList.toggle("is-active", active)
      slide.inert = this.presenting && !active
    })

    this.updateChrome()
    if (updateHash) this.replaceUrl({ hash: this.slideTargets[index].id })
    if (this.presenting && (focus || leavingFocus)) this.slideTargets[index].focus({ preventScroll: true })
  }

  currentGroup() {
    const appendix = this.isAppendix(this.index)
    return this.slideTargets
      .map((_slide, position) => position)
      .filter((position) => this.isAppendix(position) === appendix)
  }

  isAppendix(position) {
    return this.slideTargets[position]?.dataset.appendix === "true"
  }

  updateChrome() {
    const slide = this.slideTargets[this.index]
    const group = this.currentGroup()
    const position = group.indexOf(this.index)
    const appendix = this.isAppendix(this.index)
    const title = slide.dataset.title

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = appendix
        ? `Apêndice ${slide.dataset.label} · ${position + 1}/${group.length}`
        : `${position + 1} / ${group.length}`
    }
    if (this.hasCurrentTitleTarget) this.currentTitleTarget.textContent = title
    if (this.hasProgressTarget) this.progressTarget.style.width = `${((position + 1) / group.length) * 100}%`
    if (this.hasPrevButtonTarget) this.prevButtonTarget.setAttribute("aria-disabled", String(position === 0))
    if (this.hasNextButtonTarget) this.nextButtonTarget.setAttribute("aria-disabled", String(position === group.length - 1))

    this.indexLinkTargets.forEach((link) => {
      if (link.dataset.slideId === slide.id) link.setAttribute("aria-current", "true")
      else link.removeAttribute("aria-current")
    })

    if (this.hasAnnouncerTarget && this.presenting) {
      const prefix = appendix ? `Apêndice ${slide.dataset.label}` : `Slide ${position + 1} de ${group.length}`
      this.announcerTarget.textContent = `${prefix}: ${title}`
    }
  }

  // Links internos (#s-...) e índice

  followSlideLink(event) {
    const link = event.target.closest?.('a[href^="#s-"]')
    if (!link || !this.element.contains(link)) return

    const index = this.slideTargets.findIndex((slide) => `#${slide.id}` === link.getAttribute("href"))
    if (index < 0) return

    event.preventDefault()
    if (this.indexDialogTarget.open) this.indexDialogTarget.close()
    this.goTo(index)
  }

  goTo(index) {
    this.show(index, { focus: true })
    if (!this.presenting) {
      const slide = this.slideTargets[index]
      slide.scrollIntoView({ behavior: this.reducedMotion.matches ? "auto" : "smooth", block: "start" })
      slide.focus({ preventScroll: true })
    }
  }

  handleHashChange() {
    const index = this.indexFromHash()
    if (index !== null && index !== this.index) this.show(index, { updateHash: false })
  }

  indexFromHash() {
    let id
    try {
      id = decodeURIComponent(window.location.hash.slice(1))
    } catch (error) {
      if (error instanceof URIError) return null
      throw error
    }
    if (!id) return null

    const index = this.slideTargets.findIndex((slide) => slide.id === id)
    return index < 0 ? null : index
  }

  openIndex() {
    this.indexDialogTarget.showModal()
    const current = this.indexLinkTargets.find((link) => link.getAttribute("aria-current") === "true")
    current?.focus()
  }

  closeIndex() {
    this.indexDialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) event.currentTarget.close()
  }

  // Modos: apresentação e leitura

  toggleMode() {
    if (!this.presenting) this.index = this.firstVisibleSlide()
    this.presenting = !this.presenting
    this.replaceUrl({ mode: this.presenting ? null : "leitura" })
    this.applyMode({ scroll: true })
  }

  applyMode({ scroll = false } = {}) {
    this.element.classList.toggle("apr--presenting", this.presenting)
    document.documentElement.classList.toggle("apr-lock", this.presenting)
    if (this.hasModeLabelTarget) this.modeLabelTarget.textContent = this.presenting ? "Modo leitura" : "Modo apresentação"

    this.show(this.index, { updateHash: false })

    if (this.presenting) {
      window.scrollTo(0, 0)
    } else if (scroll) {
      this.slideTargets[this.index].scrollIntoView({ block: "start" })
    }
  }

  firstVisibleSlide() {
    const offset = this.element.querySelector(".apr-bar")?.offsetHeight || 0
    const index = this.slideTargets.findIndex((slide) => slide.getBoundingClientRect().bottom > offset + 80)
    return index < 0 ? this.index : index
  }

  replaceUrl({ hash, mode } = {}) {
    const url = new URL(window.location.href)
    if (hash !== undefined) url.hash = hash
    if (mode !== undefined) {
      if (mode) url.searchParams.set("modo", mode)
      else url.searchParams.delete("modo")
    }
    window.history.replaceState(window.history.state, "", url)
  }

  // Teclado e gestos

  handleKeydown(event) {
    if (event.defaultPrevented || event.altKey || event.ctrlKey || event.metaKey) return
    if (!this.presenting || this.dialogOpen()) return

    const target = event.target instanceof Element ? event.target : null
    if (target?.closest("input, textarea, select, [contenteditable]:not([contenteditable='false'])")) return

    // Links e botões dentro dos slides mantêm o comportamento nativo do teclado.
    // Nos controles da própria apresentação, as setas continuam navegando.
    const interactive = target?.closest("a[href], button, summary, [role='button']")
    const inControls = target?.closest(".apr-nav, .apr-bar")
    if (interactive && !inControls) return

    switch (event.key) {
      case "ArrowRight":
      case "PageDown":
        this.next()
        break
      case "ArrowLeft":
      case "PageUp":
        this.previous()
        break
      case "Home":
        this.edge(false)
        break
      case "End":
        this.edge(true)
        break
      case " ":
        if (interactive) return
        event.shiftKey ? this.previous() : this.next()
        break
      case "f":
      case "F":
        if (!document.fullscreenEnabled) return
        this.toggleFullscreen()
        break
      default:
        return
    }

    event.preventDefault()
  }

  touchStart(event) {
    const touch = event.changedTouches[0]
    const scrollsSideways = event.target.closest?.(".apr-table-wrap, .apr-lightbox")
    this.touchOrigin = scrollsSideways ? null : { x: touch.clientX, y: touch.clientY }
  }

  touchEnd(event) {
    if (!this.presenting || !this.touchOrigin) return

    const touch = event.changedTouches[0]
    const dx = touch.clientX - this.touchOrigin.x
    const dy = touch.clientY - this.touchOrigin.y
    this.touchOrigin = null

    if (Math.abs(dx) > 60 && Math.abs(dy) < 40) dx < 0 ? this.next() : this.previous()
  }

  dialogOpen() {
    return this.indexDialogTarget.open || this.lightboxTarget.open
  }

  // Tela cheia e impressão

  toggleFullscreen() {
    if (document.fullscreenElement) {
      document.exitFullscreen().catch(() => {})
    } else {
      document.documentElement.requestFullscreen().catch(() => {})
    }
  }

  syncFullscreen() {
    if (!this.hasFullscreenButtonTarget) return

    const active = Boolean(document.fullscreenElement)
    this.fullscreenButtonTarget.setAttribute("aria-pressed", String(active))
    this.fullscreenButtonTarget.querySelector("span").textContent = active ? "Sair da tela cheia" : "Tela cheia"
  }

  print() {
    window.print()
  }

  // Ampliação de imagens e diagramas

  zoom(event) {
    event.preventDefault()

    const trigger = event.currentTarget
    const figure = trigger.closest("figure")
    let media

    if (trigger.dataset.zoomSrc) {
      media = document.createElement("img")
      media.src = trigger.dataset.zoomSrc
      media.alt = trigger.querySelector("img")?.alt || ""
    } else {
      media = trigger.querySelector("svg").cloneNode(true)
      const label = media.querySelector("title")?.textContent || ""
      media.querySelectorAll("title[id], desc[id]").forEach((node) => node.removeAttribute("id"))
      media.removeAttribute("aria-labelledby")
      media.setAttribute("aria-label", label)
    }

    this.lightboxMediaTarget.replaceChildren(media)
    this.lightboxCaptionTarget.textContent =
      figure?.querySelector(".apr-figure__title")?.textContent.trim() || trigger.getAttribute("aria-label")
    this.setActualSize(false)
    this.lightboxTarget.showModal()
  }

  closeLightbox() {
    this.lightboxTarget.close()
  }

  clearLightbox() {
    this.lightboxMediaTarget.replaceChildren()
  }

  toggleActualSize() {
    this.setActualSize(!this.actualSize)
  }

  setActualSize(enabled) {
    this.actualSize = enabled
    this.lightboxTarget.classList.toggle("is-actual-size", enabled)
    if (this.hasActualSizeButtonTarget) this.actualSizeButtonTarget.setAttribute("aria-pressed", String(enabled))
  }
}
