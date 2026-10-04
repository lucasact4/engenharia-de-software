import { Controller } from "@hotwired/stimulus"
import { PresentationSelection, estimateText, formatDuration } from "lib/presentation_selection"

// Apresentação em slides (/apresentacao).
// Sem JavaScript, a página continua legível no modo leitura (slides do perfil em sequência).
//
// O servidor envia todos os slides e conteúdos; o que o perfil desmarca vem com hidden.
// "Personalizar apresentação" altera essa seleção só nesta página, em memória: nada é salvo
// nem enviado ao servidor, e recarregar volta ao perfil.
export default class extends Controller {
  static targets = [
    "slide", "enhanced", "modeLabel", "fullscreenButton",
    "prevButton", "nextButton", "counter", "currentTitle", "progress", "announcer",
    "indexDialog", "indexLink", "lightbox", "lightboxMedia", "lightboxCaption", "actualSizeButton",
    "customDialog", "customHeading", "customButton", "customStatus", "estimate"
  ]

  static values = { catalog: Array, choices: Object, limit: Number }

  connect() {
    this.index = 0
    this.presenting = new URLSearchParams(window.location.search).get("modo") !== "leitura"
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.selection = new PresentationSelection(this.catalogValue, this.choicesValue)

    this.enhancedTargets.forEach((element) => { element.hidden = false })
    if (this.hasFullscreenButtonTarget) this.fullscreenButtonTarget.hidden = !document.fullscreenEnabled
    this.element.classList.add("apr--js")

    this.onKeydown = this.handleKeydown.bind(this)
    this.onFullscreenChange = this.syncFullscreen.bind(this)
    this.onHashChange = this.handleHashChange.bind(this)
    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("fullscreenchange", this.onFullscreenChange)
    window.addEventListener("hashchange", this.onHashChange)

    this.applyVisibility()
    const initial = this.indexFromHash()
    this.index = initial ?? this.firstAvailable()
    this.applyMode({ scroll: initial !== null })
    if (initial !== null && `#${this.slideTargets[this.index].id}` !== window.location.hash) {
      this.replaceUrl({ hash: this.slideTargets[this.index].id })
    }
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
    if (!this.isVisible(index)) index = this.nearestVisible(index)

    this.element.dataset.direction = index >= this.index ? "forward" : "backward"
    this.index = index

    const leavingFocus = this.slideTargets.some((slide) => slide.contains(document.activeElement))

    this.slideTargets.forEach((slide, position) => {
      const active = position === index
      slide.classList.toggle("is-active", active)
      slide.inert = this.presenting && !active
    })

    this.closePopovers()
    this.updateChrome()
    if (updateHash) this.replaceUrl({ hash: this.slideTargets[index].id })
    if (this.presenting && (focus || leavingFocus)) this.slideTargets[index].focus({ preventScroll: true })
  }

  // Informações abertas (Popover API) ficam na camada superior: fecham ao trocar de slide.
  closePopovers() {
    if (!("hidePopover" in HTMLElement.prototype)) return
    this.element.querySelectorAll("[popover]:popover-open").forEach((popover) => popover.hidePopover())
  }

  // Posições visíveis do mesmo grupo (sequência principal ou apêndices) do slide atual.
  currentGroup() {
    const appendix = this.isAppendix(this.index)
    return this.visiblePositions().filter((position) => this.isAppendix(position) === appendix)
  }

  visiblePositions() {
    return this.slideTargets.map((_slide, position) => position).filter((position) => this.isVisible(position))
  }

  isVisible(position) {
    return Boolean(this.slideTargets[position]) && !this.slideTargets[position].hidden
  }

  isAppendix(position) {
    return this.slideTargets[position]?.dataset.appendix === "true"
  }

  firstAvailable() {
    return this.visiblePositions().find((position) => !this.isAppendix(position)) ?? 0
  }

  // Substituto previsível para um slide oculto: o próximo visível do mesmo grupo,
  // senão o anterior, senão o primeiro slide da apresentação (a capa é obrigatória).
  nearestVisible(position) {
    const group = this.visiblePositions().filter((candidate) => this.isAppendix(candidate) === this.isAppendix(position))
    return group.find((candidate) => candidate > position) ??
      group.reverse().find((candidate) => candidate < position) ??
      this.firstAvailable()
  }

  updateChrome() {
    const slide = this.slideTargets[this.index]
    const group = this.currentGroup()
    const position = group.indexOf(this.index)
    const appendix = this.isAppendix(this.index)
    const title = slide.dataset.title
    const label = this.labels?.[slide.dataset.slideId] || ""

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = appendix
        ? `Apêndice ${label} · ${position + 1}/${group.length}`
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
      const prefix = appendix ? `Apêndice ${label}` : `Slide ${position + 1} de ${group.length}`
      this.announcerTarget.textContent = `${prefix}: ${title}`
    }
  }

  // Seleção de slides e conteúdos

  // Aplica a seleção atual a toda a página: slides, blocos, índice, rótulos, tempo e painel.
  applyVisibility() {
    const selection = this.selection
    const root = this.element
    this.labels = selection.labels()
    const mainCount = selection.mainSlides().length

    this.slideTargets.forEach((slide) => { slide.hidden = !selection.slideVisible(slide.dataset.slideId) })
    root.querySelectorAll("[data-apr-item]").forEach((element) => {
      element.hidden = !selection.itemVisible(element.dataset.aprItem)
    })
    // Grupos internos primeiro: um grupo fica oculto quando nenhum bloco dentro dele aparece.
    ;[...root.querySelectorAll("[data-apr-group]")].reverse().forEach((group) => {
      group.hidden = ![...group.querySelectorAll("[data-apr-item]")].some((item) => this.shownWithin(item, group))
    })
    root.querySelectorAll("[data-apr-slide-ref]").forEach((element) => {
      element.hidden = !selection.slideVisible(element.dataset.aprSlideRef)
    })
    root.querySelectorAll("[data-apr-slide-ref-off]").forEach((element) => {
      element.hidden = selection.slideVisible(element.dataset.aprSlideRefOff)
    })
    root.querySelectorAll("[data-apr-slide-group]").forEach((group) => {
      const appendix = group.dataset.aprSlideGroup === "appendix"
      group.hidden = !selection.visibleSlides().some((slide) => slide.appendix === appendix)
    })
    root.querySelectorAll("[data-apr-label-for]").forEach((element) => {
      element.textContent = `${element.dataset.aprLabelPrefix ?? ""}${this.labels[element.dataset.aprLabelFor] || "—"}`
    })
    root.querySelectorAll("[data-apr-folio-for]").forEach((element) => {
      const slide = selection.slides.get(element.dataset.aprFolioFor)
      const label = this.labels[slide.id] || "—"
      element.textContent = slide.appendix ? `Apêndice ${label}` : `${label} / ${String(mainCount).padStart(2, "0")}`
    })

    let elapsed = 0
    selection.catalog.filter((slide) => !slide.appendix).forEach((slide) => {
      const visible = selection.slideVisible(slide.id)
      if (visible) elapsed += slide.seconds
      root.querySelectorAll(`[data-apr-elapsed-for="${slide.id}"]`).forEach((cell) => {
        cell.textContent = visible ? formatDuration(elapsed) : ""
      })
    })

    const total = selection.totalSeconds()
    const limit = this.limitValue || null
    this.estimateTargets.forEach((element) => {
      element.textContent = estimateText(total, mainCount, limit)
      element.classList.toggle("is-over", Boolean(limit && total > limit))
    })

    this.syncCustomPanel()
  }

  shownWithin(element, root) {
    for (let node = element; node && node !== root; node = node.parentElement) {
      if (node.hidden) return false
    }
    return true
  }

  syncCustomPanel() {
    if (!this.hasCustomDialogTarget) return

    const selection = this.selection
    this.customDialogTarget.querySelectorAll("[data-apr-toggle]").forEach((input) => {
      input.checked = selection.chosen(input.dataset.aprToggle)
    })
    this.customDialogTarget.querySelectorAll("[data-apr-custom-slide]").forEach((row) => {
      const id = row.dataset.aprCustomSlide
      const slide = selection.slides.get(id)
      const chosen = selection.chosen(id)
      row.querySelector(".apr-custom__items")?.classList.toggle("is-muted", !chosen)
      row.classList.toggle("is-off", !selection.slideVisible(id))

      const hint = row.querySelector("[data-apr-hint-for]")
      if (!hint) return
      if (slide.required) hint.textContent = "Sempre exibido."
      else if (selection.withoutContent(id)) hint.textContent = "Nenhum conteúdo marcado: o slide será omitido."
      else if (!chosen && slide.items.length > 0) hint.textContent = "Slide oculto. As escolhas abaixo ficam guardadas."
      else hint.textContent = ""
    })

    const changed = !selection.equals(this.choicesValue)
    if (this.hasCustomStatusTarget) {
      this.customStatusTarget.textContent = changed
        ? "Ajustes temporários ativos nesta página (não salvos)."
        : "Seleção igual ao perfil."
    }
    if (this.hasCustomButtonTarget) this.customButtonTarget.classList.toggle("is-customized", changed)
  }

  toggleChoice(event) {
    const input = event.target
    this.selection.set(input.dataset.aprToggle, input.checked)
    this.refreshAfterSelection()
  }

  restoreProfile() {
    this.selection = new PresentationSelection(this.catalogValue, this.choicesValue)
    this.refreshAfterSelection()
    if (this.hasCustomStatusTarget) this.customStatusTarget.textContent = "Padrão do perfil restaurado."
  }

  // Se o slide atual sumiu, segue para o próximo visível (ou o anterior) sem perder o lugar.
  refreshAfterSelection() {
    const previous = this.index
    this.applyVisibility()
    if (!this.isVisible(previous)) {
      this.slideMovedWhileCustomizing = true
      this.show(this.nearestVisible(previous))
      if (this.hasAnnouncerTarget) {
        this.announcerTarget.textContent = `Slide atual ocultado. Exibindo: ${this.slideTargets[this.index].dataset.title}`
      }
    } else {
      this.updateChrome()
    }
  }

  openCustomize() {
    this.slideMovedWhileCustomizing = false
    this.customDialogTarget.showModal()
    this.customHeadingTarget.focus()
  }

  closeCustomize() {
    this.customDialogTarget.close()
  }

  // Ao fechar, o foco volta ao botão; se o slide atual foi ocultado, vai para o novo slide.
  customClosed() {
    if (this.slideMovedWhileCustomizing && this.presenting) {
      this.slideTargets[this.index].focus({ preventScroll: true })
    } else if (this.slideMovedWhileCustomizing) {
      this.slideTargets[this.index].scrollIntoView({ block: "start" })
      this.slideTargets[this.index].focus({ preventScroll: true })
    } else if (this.hasCustomButtonTarget) {
      this.customButtonTarget.focus()
    }
    this.slideMovedWhileCustomizing = false
  }

  // Links internos (#s-...) e índice

  followSlideLink(event) {
    const link = event.target.closest?.('a[href^="#s-"]')
    if (!link || !this.element.contains(link)) return

    const index = this.slideTargets.findIndex((slide) => `#${slide.id}` === link.getAttribute("href"))
    if (index < 0) return

    event.preventDefault()
    if (this.indexDialogTarget.open) this.indexDialogTarget.close()
    this.goTo(this.isVisible(index) ? index : this.nearestVisible(index))
  }

  goTo(index) {
    this.show(index, { focus: true })
    if (!this.presenting) {
      const slide = this.slideTargets[this.index]
      slide.scrollIntoView({ behavior: this.reducedMotion.matches ? "auto" : "smooth", block: "start" })
      slide.focus({ preventScroll: true })
    }
  }

  handleHashChange() {
    const index = this.indexFromHash()
    if (index === null) return
    if (index !== this.index) this.show(index, { updateHash: false })
    if (`#${this.slideTargets[this.index].id}` !== window.location.hash) {
      this.replaceUrl({ hash: this.slideTargets[this.index].id })
    }
  }

  // Slide pedido no fragmento da URL; um slide oculto cai no visível mais próximo.
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
    if (index < 0) return null
    return this.isVisible(index) ? index : this.nearestVisible(index)
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
    const index = this.slideTargets.findIndex((slide) => !slide.hidden && slide.getBoundingClientRect().bottom > offset + 80)
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
    const scrollsSideways = event.target.closest?.(".apr-table-wrap, .apr-data-viewport, .apr-lightbox")
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

  // Índice, ampliação, personalização e janelas de evidências: setas não trocam de slide.
  dialogOpen() {
    return Boolean(this.element.querySelector("dialog[open]"))
  }

// Janelas de detalhes (evidências do código, repositório). O botão também declara
// commandfor/command="show-modal", que abre a janela sem JavaScript nos navegadores atuais.

openDialog(event) {
  event.preventDefault()
  const dialog = document.getElementById(event.currentTarget.getAttribute("commandfor"))
  if (!dialog || dialog.open) return

  this.dialogOpener = event.currentTarget
  dialog.showModal()
  dialog.querySelector("[data-dialog-initial-focus]")?.focus()
}

closeDialog(event) {
  event.currentTarget.closest("dialog")?.close()
}

dialogClosed() {
  if (this.dialogOpener?.isConnected) this.dialogOpener.focus()
  this.dialogOpener = null
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
      // Uma imagem por tema; o CSS mostra a do tema ativo, como na miniatura.
      media = [...trigger.querySelectorAll("img[data-zoom-src]")].map((thumbnail) => {
        const image = document.createElement("img")
        image.src = thumbnail.dataset.zoomSrc
        image.alt = thumbnail.alt
        if (thumbnail.dataset.theme !== "any") image.className = `apr-theme-only--${thumbnail.dataset.theme}`
        return image
      })
    } else if (figure?.querySelector(".apr-data-viewport")) {
      media = figure.querySelector(".apr-data-viewport").cloneNode(true)
      media.classList.add("apr-data-viewport--zoomed")
      media.querySelectorAll("[aria-pressed]").forEach((button) => button.setAttribute("aria-pressed", "false"))
      media.querySelectorAll(".has-selection, .is-linked, .is-selected").forEach((node) => {
        node.classList.remove("has-selection", "is-linked", "is-selected")
      })
      media.classList.remove("has-selection")
    } else {
      media = trigger.querySelector("svg")?.cloneNode(true)
      if (!media) return
      const label = media.querySelector("title")?.textContent || ""
      media.querySelectorAll("title[id], desc[id]").forEach((node) => node.removeAttribute("id"))
      media.removeAttribute("aria-labelledby")
      media.setAttribute("aria-label", label)
    }

    this.lightboxMediaTarget.replaceChildren(...[ media ].flat())
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
