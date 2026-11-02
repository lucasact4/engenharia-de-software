import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "challenge", "widget", "status"]
  static values = { siteKey: String }

  connect() {
    this.widgetId = null
    this.loading = null
    if (this.checkboxTarget.checked) this.enableChallenge()
  }

  disconnect() {
    if (this.widgetId && window.turnstile) window.turnstile.remove(this.widgetId)
  }

  toggle() {
    if (this.checkboxTarget.checked) {
      this.enableChallenge()
      return
    }

    this.challengeTarget.hidden = true

    this.statusTarget.textContent = ""
    if (this.widgetId && window.turnstile) {
      window.turnstile.remove(this.widgetId)
      this.widgetId = null
      this.widgetTarget.replaceChildren()
    }
  }

  async enableChallenge() {
    this.challengeTarget.hidden = false
    this.statusTarget.textContent = "Carregando a proteção antirobô…"

    try {
      await this.loadTurnstile()
      if (!this.checkboxTarget.checked || this.widgetId) return

      this.widgetId = window.turnstile.render(this.widgetTarget, {
        sitekey: this.siteKeyValue,
        action: "anonymous_occurrence",
        callback: () => {
          this.statusTarget.textContent = "Desafio confirmado."
        },
        "expired-callback": () => {
          this.statusTarget.textContent = "O desafio expirou. Confirme novamente."
        },
        "error-callback": () => {
          this.statusTarget.textContent = "Não foi possível carregar o desafio. Tente novamente."
        }
      })
    } catch (_error) {
      this.statusTarget.textContent = "Não foi possível carregar a proteção antirobô."
    }
  }

  loadTurnstile() {
    if (window.turnstile) return Promise.resolve()
    if (this.loading) return this.loading

    this.loading = new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"
      script.async = true
      script.defer = true
      script.onload = resolve
      script.onerror = reject
      document.head.append(script)
    })
    return this.loading
  }
}