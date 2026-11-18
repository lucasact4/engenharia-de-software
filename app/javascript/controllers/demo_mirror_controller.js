import { Controller } from "@hotwired/stimulus"

// Demonstração ao vivo: o SGU no computador e no celular, espelhados nos dois sentidos.
// Quem recebe o toque, o clique ou a rolagem do usuário passa a comandar e o outro aparelho repete:
// página aberta, rolagem, campos digitados e controles da própria página (abas, menus, tema).
// Envios de formulário não são repetidos, para não duplicar ocorrências, curtidas ou pedidos de pânico:
// o outro aparelho abre a página resultante.
const SIZES = { desktop: { width: 1280, height: 800 }, phone: { width: 390, height: 844 } }
const MIRRORED_CLICKS = "button[type='button'], summary, [role='tab'], [aria-controls], [data-theme-toggle]"
const LEADER_EVENTS = ["pointerdown", "touchstart", "wheel", "keydown"]

export default class extends Controller {
  static targets = [
    "stage", "desktop", "phone", "desktopBox", "desktopViewport", "phoneViewport",
    "desktopUrl", "sync", "desktopTap", "phoneTap", "status", "fullscreen", "step", "stepPop"
  ]
  static values = { start: { type: String, default: "/" }, embedded: Boolean }

  connect() {
    this.syncing = true
    this.leader = "desktop"
    this.scales = { desktop: 1, phone: 1 }
    this.onResize = () => this.layout()
    this.onFullscreen = () => this.updateFullscreen()
    this.onKey = (event) => this.shortcut(event)
    // Dentro da apresentação, a tela cheia é a da página dos slides (mesma origem).
    this.host = this.embeddedValue && window.parent !== window ? window.parent.document : document
    window.addEventListener("resize", this.onResize)
    this.host.addEventListener("fullscreenchange", this.onFullscreen)
    document.addEventListener("keydown", this.onKey)

    for (const name of ["desktop", "phone"]) {
      this.frame(name).addEventListener("load", () => this.attach(name))
      this.frame(name).src = this.startValue
    }
    this.layout()
    this.updateFullscreen()
  }

  disconnect() {
    window.removeEventListener("resize", this.onResize)
    this.host.removeEventListener("fullscreenchange", this.onFullscreen)
    document.removeEventListener("keydown", this.onKey)
  }

  // Layout -------------------------------------------------------------------

  layout() {
    const stage = this.stageTarget.getBoundingClientRect()
    const narrow = stage.width < 760
    const gap = 12
    const availableWidth = Math.max(240, stage.width - 12)
    const availableHeight = Math.max(260, stage.height - 12)
    const phone = SIZES.phone
    const phoneScale = Math.max(0.2, Math.min(1.15,
      (availableHeight - 38) / phone.height,
      availableWidth * (narrow ? 0.38 : 0.31) / (phone.width + 12)))
    const phoneWidth = phone.width * phoneScale + 12
    const desktopWidth = Math.max(200, availableWidth - phoneWidth - gap)
    const desktopScale = Math.max(0.12, Math.min(1.4, desktopWidth / SIZES.desktop.width))
    // Usa toda a altura disponível, mantendo a largura de desktop e o celular real.
    const desktop = { width: SIZES.desktop.width, height: Math.max(300, Math.round((availableHeight - 30) / desktopScale)) }
    this.desktopTarget.height = desktop.height

    this.resizeFrame(this.desktopViewportTarget, this.desktopTarget, desktop, desktopScale)
    this.desktopBoxTarget.style.width = `${desktop.width * desktopScale}px`
    this.resizeFrame(this.phoneViewportTarget, this.phoneTarget, phone, phoneScale)
    this.scales = { desktop: desktopScale, phone: phoneScale }
  }

  resizeFrame(viewport, frame, size, factor) {
    viewport.style.width = `${size.width * factor}px`
    viewport.style.height = `${size.height * factor}px`
    frame.style.transform = `scale(${factor})`
  }

  // Barra --------------------------------------------------------------------

  go(event) {
    const path = event.currentTarget.dataset.path
    this.leader = "desktop"
    this.visit(this.desktopTarget, path)
    if (this.syncing) this.visit(this.phoneTarget, path)
  }

  toggleSync() {
    this.syncing = this.syncTarget.checked
    this.statusTarget.textContent = this.syncing
      ? "Espelhado: mexa no computador ou no celular"
      : "Espelho pausado: cada aparelho segue sozinho"
    if (this.syncing) this.follow(this.leader)
  }

  toggleFullscreen() {
    if (this.host.fullscreenElement) {
      this.host.exitFullscreen?.()
    } else {
      this.host.documentElement.requestFullscreen?.().catch(() => {})
    }
  }

  updateFullscreen() {
    if (!this.hasFullscreenTarget) return
    const active = Boolean(this.host.fullscreenElement)
    this.fullscreenTarget.setAttribute("aria-pressed", String(active))
    this.fullscreenTarget.querySelector("span").textContent = active ? "Sair da tela cheia" : "Tela cheia"
    requestAnimationFrame(() => this.layout())
  }

  shortcut(event) {
    if (event.key?.toLowerCase() === "f" && !event.ctrlKey && !event.metaKey && !event.altKey &&
        !event.target.closest?.("input, textarea, select")) {
      event.preventDefault()
      this.toggleFullscreen()
    }
  }

  // Roteiro ------------------------------------------------------------------

  // O clique no passo abre o mini popup (popovertarget); aqui ele é posicionado ao lado do passo.
  showStep(event) {
    this.markStep(Number(event.currentTarget.dataset.index))
  }

  nextStep(event) {
    const index = Number(event.currentTarget.dataset.index)
    this.stepPopTargets.forEach((pop) => { if (pop.matches(":popover-open")) pop.hidePopover() })
    this.markStep(index)
    this.stepPopTargets[index]?.showPopover()
  }

  markStep(index) {
    const button = this.stepTargets[index]
    const pop = this.stepPopTargets[index]
    if (!button || !pop) return

    this.stepTargets.forEach((step, position) => {
      step.classList.toggle("is-done", position < index)
      if (position === index) step.setAttribute("aria-current", "step")
      else step.removeAttribute("aria-current")
    })

    const rect = button.getBoundingClientRect()
    const guide = button.closest(".apr-mirror__guide").getBoundingClientRect()
    pop.style.left = `${guide.right + 10}px`
    pop.style.top = `${Math.max(8, rect.top)}px`
    // Depois de aberto, sobe o popup o necessário para caber inteiro na tela.
    requestAnimationFrame(() => {
      const height = pop.offsetHeight
      if (height) pop.style.top = `${Math.max(8, Math.min(rect.top, window.innerHeight - height - 8))}px`
    })
  }

  // Volta aos slides: fecha a sobreposição quando a demo está dentro da apresentação.
  back(event) {
    if (!this.embeddedValue || window.parent === window) return
    event.preventDefault()
    window.parent.postMessage({ type: "sgu:demo-close" }, window.location.origin)
  }

  // Espelho ------------------------------------------------------------------

  attach(name) {
    const doc = this.documentOf(this.frame(name))
    if (!doc) return

    this.follow(name)
    if (doc.sguMirrorAttached) return
    doc.sguMirrorAttached = true

    for (const type of LEADER_EVENTS) {
      doc.addEventListener(type, (event) => { if (event.isTrusted) this.leader = name }, { capture: true, passive: true })
    }
    doc.addEventListener("turbo:load", () => this.follow(name))
    doc.addEventListener("click", (event) => { if (event.isTrusted) this.mirrorClick(name, event) }, true)
    doc.addEventListener("input", (event) => { if (event.isTrusted) this.mirrorField(name, event.target) }, true)
    doc.addEventListener("change", (event) => { if (event.isTrusted) this.mirrorField(name, event.target) }, true)
    this.frame(name).contentWindow.addEventListener("scroll", () => {
      if (this.leader === name) this.queueScroll(name)
    }, { passive: true })
  }

  // O outro aparelho abre a mesma página de quem está comandando.
  follow(name) {
    const desktopPath = this.pathOf(this.desktopTarget)
    if (desktopPath) this.desktopUrlTarget.textContent = `${window.location.host}${desktopPath}`
    if (!this.syncing || name !== this.leader) return

    const path = this.pathOf(this.frame(name))
    const other = this.other(name)
    if (!path || this.pathOf(this.frame(other)) === path) return
    this.visit(this.frame(other), path)
  }

  mirrorField(name, field) {
    if (!this.syncing || !field?.matches?.("input, textarea, select") || field.type === "file" || field.type === "password") return

    const other = this.other(name)
    const twin = this.twinOf(field, other)
    if (!twin) return

    if (field.type === "checkbox" || field.type === "radio") {
      if (twin.checked === field.checked) return
      twin.checked = field.checked
    } else {
      if (twin.value === field.value) return
      twin.value = field.value
    }
    twin.dispatchEvent(new Event("input", { bubbles: true }))
    twin.dispatchEvent(new Event("change", { bubbles: true }))
    this.flash(other, twin)
  }

  mirrorClick(name, event) {
    if (!this.syncing) return

    const other = this.other(name)
    const control = event.target.closest?.(MIRRORED_CLICKS)
    if (control) {
      const twin = this.twinOf(control, other)
      if (twin) {
        this.flash(other, twin)
        twin.click()
      }
      return
    }

    // Links e envios: o outro aparelho mostra o toque e depois abre a página resultante.
    const action = event.target.closest?.("a[href], button, input[type='submit']")
    const twin = action && this.twinOf(action, other)
    if (twin) this.flash(other, twin)
  }

  queueScroll(name) {
    if (!this.syncing || this.scrollQueued) return
    this.scrollQueued = true
    requestAnimationFrame(() => {
      this.scrollQueued = false
      const sourceFrame = this.frame(name)
      const targetFrame = this.frame(this.other(name))
      const sourceDoc = this.documentOf(sourceFrame)
      const targetDoc = this.documentOf(targetFrame)
      if (!sourceDoc || !targetDoc) return

      const source = sourceFrame.contentWindow
      const target = targetFrame.contentWindow
      const range = sourceDoc.documentElement.scrollHeight - source.innerHeight
      const ratio = range > 0 ? source.scrollY / range : 0
      target.scrollTo(0, ratio * (targetDoc.documentElement.scrollHeight - target.innerHeight))
    })
  }

  // Elemento equivalente no outro aparelho: id, nome do campo, destino do link, atributos ou texto.
  twinOf(element, name) {
    const doc = this.documentOf(this.frame(name))
    if (!doc) return null

    const visible = (candidates) => [...candidates].find((node) => node.getClientRects().length > 0) || candidates[0] || null
    const css = (value) => window.CSS.escape(value)

    if (element.id) return doc.getElementById(element.id)

    const fieldName = element.getAttribute("name")
    if (fieldName) {
      const value = element.type === "radio" ? `[value="${css(element.value)}"]` : ""
      const match = visible(doc.querySelectorAll(`[name="${css(fieldName)}"]${value}`))
      if (match) return match
    }

    const href = element.getAttribute("href")
    if (href) {
      const match = visible(doc.querySelectorAll(`a[href="${css(href)}"]`))
      if (match) return match
    }

    for (const attribute of ["aria-controls", "data-action", "data-path"]) {
      const value = element.getAttribute(attribute)
      if (!value) continue
      const text = element.textContent.trim()
      const candidates = [...doc.querySelectorAll(`[${attribute}="${css(value)}"]`)]
      const match = candidates.find((node) => node.textContent.trim() === text) || visible(candidates)
      if (match) return match
    }

    const text = element.textContent.trim()
    if (text && text.length < 80) {
      const candidates = [...doc.querySelectorAll(element.tagName)].filter((node) => node.textContent.trim() === text)
      if (candidates.length) return visible(candidates)
    }
    return null
  }

  // Marca onde o "toque" aconteceu no aparelho que repetiu a ação.
  flash(name, element) {
    const rect = element.getBoundingClientRect()
    if (!rect.width && !rect.height) return

    const scale = this.scales[name] || 1
    const tap = name === "phone" ? this.phoneTapTarget : this.desktopTapTarget
    tap.style.left = `${(rect.left + rect.width / 2) * scale}px`
    tap.style.top = `${(rect.top + rect.height / 2) * scale}px`
    tap.classList.remove("is-on")
    void tap.offsetWidth
    tap.classList.add("is-on")
  }

  // Utilitários ---------------------------------------------------------------

  frame(name) {
    return name === "phone" ? this.phoneTarget : this.desktopTarget
  }

  other(name) {
    return name === "phone" ? "desktop" : "phone"
  }

  visit(frame, path) {
    const win = frame.contentWindow
    try {
      if (win?.Turbo && win.location.origin === window.location.origin) {
        win.Turbo.visit(path)
      } else {
        frame.src = path
      }
    } catch {
      frame.src = path
    }
  }

  documentOf(frame) {
    try {
      return frame.contentDocument
    } catch {
      return null
    }
  }

  pathOf(frame) {
    try {
      const { pathname, search, hash } = frame.contentWindow.location
      return pathname === "blank" || pathname === "" ? null : `${pathname}${search}${hash}`
    } catch {
      return null
    }
  }
}
