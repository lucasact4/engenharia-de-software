import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { worker: String, url: String, key: String, enabled: Boolean }
  static targets = ["button", "status"]

  connect() {
    if (!window.isSecureContext || !("serviceWorker" in navigator) || !("PushManager" in window) || !("Notification" in window)) {
      this.statusTarget.textContent = "Os avisos push precisam de um navegador compatível e de uma conexão segura."
      return
    }
    this.buttonTarget.hidden = false
    this.updateButton()
  }

  async toggle() {
    this.buttonTarget.disabled = true
    try {
      if (this.enabledValue) {
        await this.save("DELETE")
        this.enabledValue = false
        const registration = await navigator.serviceWorker.getRegistration(this.workerValue)
        const subscription = await registration?.pushManager.getSubscription()
        await subscription?.unsubscribe()
        this.statusTarget.textContent = "Avisos push desativados neste navegador."
      } else {
        if (await Notification.requestPermission() !== "granted") {
          this.statusTarget.textContent = "Permita as notificações nas configurações do navegador para ativar os avisos."
          return
        }
        await navigator.serviceWorker.register(this.workerValue)
        const registration = await navigator.serviceWorker.ready
        const key = Uint8Array.from(atob(this.keyValue.replace(/-/g, "+").replace(/_/g, "/")), char => char.charCodeAt(0))
        let subscription = await registration.pushManager.getSubscription()
        const existingKey = subscription?.options.applicationServerKey
        if (existingKey && String(new Uint8Array(existingKey)) !== String(key)) {
          await subscription.unsubscribe()
          subscription = null
        }
        subscription ||= await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: key })
        await this.save("POST", { subscription: subscription.toJSON() })
        this.enabledValue = true
        this.statusTarget.textContent = "Avisos push ativados neste navegador."
      }
    } catch {
      this.statusTarget.textContent = "Não foi possível atualizar os avisos push. Tente novamente."
    } finally {
      this.buttonTarget.disabled = false
      this.updateButton()
    }
  }

  async save(method, body) {
    const response = await fetch(this.urlValue, {
      method,
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(8000)
    })
    if (response.redirected || !response.ok) throw new Error("subscription")
  }

  updateButton() {
    this.buttonTarget.textContent = this.enabledValue ? "Desativar push neste navegador" : "Ativar push neste navegador"
    this.buttonTarget.setAttribute("aria-pressed", String(this.enabledValue))
  }
}
