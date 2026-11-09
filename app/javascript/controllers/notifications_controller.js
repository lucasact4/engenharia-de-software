import { Controller } from "@hotwired/stimulus"

// A caixa de entrada persistida recupera eventos após queda de rede ou navegação Turbo.
export default class extends Controller {
  static targets = ["menu", "trigger", "list", "count", "urgent", "status"]
  static values = { url: String }

  connect() {
    if (!this.hasUrlValue) return
    this.stopped = false
    this.pinned = false
    this.readRequests = new Set()
    this.refresh = this.refresh.bind(this)
    this.beforeCache = () => { this.disconnect(); this.clearPrivateContent() }
    this.visibility = () => { if (!document.hidden) this.refresh() }
    document.addEventListener("visibilitychange", this.visibility)
    document.addEventListener("turbo:before-cache", this.beforeCache)
    this.timer = setInterval(this.refresh, 3000)
    this.refresh()
  }

  disconnect() {
    this.stopped = true
    clearInterval(this.timer)
    clearTimeout(this.closeTimer)
    this.request?.abort()
    this.readRequests?.forEach(request => request.abort())
    document.removeEventListener("visibilitychange", this.visibility)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
  }

  async refresh() {
    if (this.stopped || this.loading || document.hidden) return
    this.loading = true
    this.request = new AbortController()
    const timeout = setTimeout(() => {
      this.request.abort()
      if (!this.stopped) this.statusTarget.textContent = "Sem conexão. Tentaremos atualizar novamente."
    }, 8000)
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" }, cache: "no-store", signal: this.request.signal })
      if (response.redirected || [401, 403].includes(response.status)) {
        this.disconnect()
        this.clearPrivateContent()
        return
      }
      if (!response.ok) throw new Error("delivery")
      const data = await response.json()
      if (this.stopped) return
      this.countTarget.textContent = String(data.unread_count)
      this.statusTarget.textContent = ""
      // Não remove um botão ou link que esteja com o foco do teclado.
      if (!this.listTarget.contains(document.activeElement) && this.lastList !== data.list_version) {
        this.listTarget.innerHTML = data.list_html
        this.lastList = data.list_version
      }
      if (String(data.urgent_id || "") !== this.urgentTarget.dataset.urgentId) {
        this.urgentTarget.innerHTML = data.urgent_html || ""
        this.urgentTarget.dataset.urgentId = String(data.urgent_id || "")
      }
      this.urgentTarget.hidden = !data.urgent_id
    } catch (error) {
      if (!this.stopped && error.name !== "AbortError") this.statusTarget.textContent = "Sem conexão. Tentaremos atualizar novamente."
    } finally {
      clearTimeout(timeout)
      this.loading = false
    }
  }

  async read(event) {
    event.preventDefault()
    this.request?.abort()
    const form = event.currentTarget
    const button = form.querySelector("button")
    const request = new AbortController()
    this.readRequests.add(request)
    const timeout = setTimeout(() => request.abort(), 8000)
    button.disabled = true
    try {
      const headers = { Accept: "application/json" }
      const csrf = document.querySelector('meta[name="csrf-token"]')?.content || form.querySelector('[name="authenticity_token"]')?.value
      if (csrf) headers["X-CSRF-Token"] = csrf
      const response = await fetch(form.action, { method: "PATCH", headers, cache: "no-store", signal: request.signal })
      if (this.stopped) return
      if (response.redirected || !response.ok) throw new Error("read")
      if (this.urgentTarget.contains(form)) {
        this.urgentTarget.hidden = true
        this.urgentTarget.innerHTML = ""
        this.urgentTarget.dataset.urgentId = ""
        this.triggerTarget.focus()
      } else {
        // Histórico completo é renderizado pelo servidor; preserva paginação e estado.
        if (!this.listTarget.contains(form)) { window.location.reload(); return }
        this.pinned = true
        this.triggerTarget.focus()
      }
      await this.refresh()
    } catch {
      if (this.stopped) return
      this.statusTarget.textContent = "Não foi possível registrar a leitura. Tente novamente."
      if (this.urgentTarget.contains(form) && !form.querySelector('[role="alert"]')) {
        const error = document.createElement("p")
        error.setAttribute("role", "alert")
        error.textContent = "A leitura não foi confirmada. Tente novamente."
        form.append(error)
      }
    } finally {
      clearTimeout(timeout)
      this.readRequests.delete(request)
      button.disabled = false
    }
  }

  hover() { clearTimeout(this.closeTimer); this.open() }
  leave() {
    this.closeTimer = setTimeout(() => {
      if (!this.pinned && !this.menuTarget.contains(document.activeElement)) this.close()
    }, 250)
  }
  toggle(event) {
    event.preventDefault()
    this.pinned = !this.pinned
    if (this.pinned) this.open()
    else this.close()
  }
  open() { this.menuTarget.open = true; this.triggerTarget.setAttribute("aria-expanded", "true") }
  close(event) {
    this.menuTarget.open = false
    this.pinned = false
    this.triggerTarget.setAttribute("aria-expanded", "false")
    if (event) this.triggerTarget.focus()
  }
  clearPrivateContent() {
    if (!this.hasMenuTarget) return
    this.close()
    this.listTarget.replaceChildren()
    this.urgentTarget.replaceChildren()
    this.urgentTarget.dataset.urgentId = ""
    this.urgentTarget.hidden = true
    this.countTarget.textContent = "0"
    this.lastList = null
  }
}
