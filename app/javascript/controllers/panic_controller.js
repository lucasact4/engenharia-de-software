import { Controller } from "@hotwired/stimulus"

// Pânico: duas etapas (pedir → confirmar). Ao confirmar, espera o GPS por poucos segundos,
// congela o pedido (chave + dados) e envia. Tentativas repetidas reenviam exatamente o mesmo
// conteúdo com a mesma chave; um GPS que chegue depois não altera o pedido já congelado.
// Sem JavaScript, o formulário é enviado normalmente com a chave gerada no servidor.
const STORAGE_KEY = "sgu.panic.pending"
const GPS_WAIT_MS = 6000

export default class extends Controller {
  static targets = ["form", "latitude", "longitude", "accuracy", "capturedAt", "reason", "useGps",
    "start", "confirm", "cancel", "submit", "status", "pending", "gpsSeconds"]
  static values = { key: String, alertsUrl: String }

  connect() {
    this.sending = false
    this.payload = null
    this.gpsSecondsTarget.textContent = String(GPS_WAIT_MS / 1000)
    this.startTarget.classList.remove("hidden")
    this.cancelTarget.classList.remove("hidden")
    this.confirmTarget.hidden = true

    const pending = this.readPending()
    if (pending) {
      this.payload = pending
      this.pendingTarget.classList.remove("hidden")
    }
  }

  arm() {
    this.startTarget.hidden = true
    this.confirmTarget.hidden = false
    this.submitTarget.focus()
  }

  disarm() {
    this.confirmTarget.hidden = true
    this.startTarget.hidden = false
    this.say("")
  }

  async submit(event) {
    event.preventDefault()
    if (this.sending) return

    if (!this.payload) {
      this.sending = true
      this.submitTarget.disabled = true
      this.say("Preparando o envio…")
      await this.captureLocation()
      this.payload = { url: this.formTarget.action, entries: Array.from(new FormData(this.formTarget).entries()) }
      this.writePending(this.payload)
      this.sending = false
    }
    this.send()
  }

  resend() {
    if (this.payload) this.send()
  }

  // Nova intenção: recarrega a página, que gera outra chave no servidor.
  discard() {
    this.clearPending()
    window.location.assign(window.location.pathname)
  }

  captureLocation() {
    if (!this.useGpsTarget.checked) return this.setReason("not_shared")
    if (!("geolocation" in navigator)) return this.setReason("not_supported")

    return new Promise((resolve) => {
      let settled = false
      const finish = (callback) => {
        if (settled) return
        settled = true
        callback()
        resolve()
      }
      const timer = window.setTimeout(() => finish(() => this.setReason("timeout")), GPS_WAIT_MS + 250)

      navigator.geolocation.getCurrentPosition(
        (position) => finish(() => {
          window.clearTimeout(timer)
          const { latitude, longitude, accuracy } = position.coords
          this.latitudeTarget.value = latitude.toFixed(7)
          this.longitudeTarget.value = longitude.toFixed(7)
          this.accuracyTarget.value = Number.isFinite(accuracy) ? accuracy.toFixed(2) : ""
          this.capturedAtTarget.value = new Date(position.timestamp || Date.now()).toISOString()
          this.reasonTarget.value = ""
        }),
        (error) => finish(() => {
          window.clearTimeout(timer)
          this.setReason({ 1: "permission_denied", 2: "position_unavailable", 3: "timeout" }[error.code] || "position_unavailable")
        }),
        { enableHighAccuracy: true, timeout: GPS_WAIT_MS, maximumAge: 30000 }
      )
    })
  }

  setReason(reason) {
    ;[this.latitudeTarget, this.longitudeTarget, this.accuracyTarget, this.capturedAtTarget].forEach((field) => { field.value = "" })
    this.reasonTarget.value = reason
  }

  async send() {
    this.sending = true
    this.submitTarget.disabled = true
    this.say("Enviando o pedido…")

    const body = new FormData()
    this.payload.entries.forEach(([name, value]) => body.append(name, value))
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.payload.url, {
        method: "POST",
        body,
        credentials: "same-origin",
        redirect: "manual",
        headers: { Accept: "application/json", ...(token ? { "X-CSRF-Token": token } : {}) }
      })
      const data = await this.readJson(response)

      if (response.ok && data.url) {
        this.clearPending()
        this.say(data.message)
        window.Turbo ? window.Turbo.visit(data.url) : window.location.assign(data.url)
        return
      }
      if (response.status === 409 || response.status === 422) {
        this.clearPending()
        this.fail(data.message || "O pedido não foi aceito.", false)
        return
      }
      this.fail("Não foi possível confirmar se o pedido chegou (sessão expirada ou erro no servidor).", true)
    } catch (_error) {
      this.fail("Sem conexão: não foi possível confirmar se o pedido chegou.", true)
    }
  }

  fail(message, retryable) {
    this.sending = false
    this.submitTarget.disabled = false
    if (retryable) {
      this.pendingTarget.classList.remove("hidden")
      this.say(`${message} Use “Reenviar o mesmo pedido” — ele não cria duplicado — ou confira “Meus alertas”.`)
    } else {
      this.pendingTarget.classList.add("hidden")
      this.say(`${message} Confira “Meus alertas” antes de iniciar um novo pedido.`)
    }
  }

  async readJson(response) {
    try {
      return (response.headers.get("content-type") || "").includes("application/json") ? await response.json() : {}
    } catch (_error) {
      return {}
    }
  }

  say(text) {
    this.statusTarget.textContent = text
  }

  readPending() {
    try {
      const raw = window.sessionStorage.getItem(STORAGE_KEY)
      return raw ? JSON.parse(raw) : null
    } catch (_error) {
      return null
    }
  }

  writePending(payload) {
    try {
      window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(payload))
    } catch (_error) {
      // Sem armazenamento, o pedido continua em memória nesta página.
    }
  }

  clearPending() {
    try {
      window.sessionStorage.removeItem(STORAGE_KEY)
    } catch (_error) {
      // Nada a limpar.
    }
  }
}
