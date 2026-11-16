import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]
  static values = { presenceUrl: String, pushUrl: String, vapidPublicKey: String }

  async enablePush() {
    try {
      if (!this.vapidPublicKeyValue) throw new Error("Push ainda não está configurado neste ambiente.")
      if (!("serviceWorker" in navigator) || !("PushManager" in window)) throw new Error("Este navegador não oferece suporte a push.")
      const permission = await Notification.requestPermission()
      if (permission !== "granted") throw new Error("Permita notificações no navegador para receber emergências.")
      await navigator.serviceWorker.register("/service-worker.js")
      const registration = await navigator.serviceWorker.ready
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.decodeKey(this.vapidPublicKeyValue)
      })
      await this.send(this.pushUrlValue, { subscription: subscription.toJSON() })
      this.say("Push de emergência ativado neste dispositivo.")
    } catch (error) {
      this.say(error.message)
    }
  }

  async disablePush() {
    try {
      const registration = await navigator.serviceWorker.getRegistration("/")
      const subscription = await registration?.pushManager.getSubscription()
      if (subscription) {
        await this.send(`${this.pushUrlValue}?endpoint=${encodeURIComponent(subscription.endpoint)}`, {}, "DELETE")
        await subscription.unsubscribe()
      }
      this.say("Push desativado neste dispositivo.")
    } catch (_error) {
      this.say("Não foi possível desativar o push agora.")
    }
  }

  startPresence() {
    if (!navigator.geolocation) return this.say("Este navegador não oferece geolocalização.")
    if (this.watchId) navigator.geolocation.clearWatch(this.watchId)
    this.lastSentAt = 0
    this.watchId = navigator.geolocation.watchPosition(({ coords }) => {
      this.position = { latitude: coords.latitude, longitude: coords.longitude }
      this.sendPresence()
    }, () => this.say("GPS indisponível ou permissão negada; os alertas continuarão chegando à equipe por contingência."), {
      enableHighAccuracy: true, maximumAge: 15000, timeout: 10000
    })
    this.heartbeatId = window.setInterval(() => this.sendPresence(), 60000)
  }

  async stopPresence() {
    if (this.watchId) navigator.geolocation.clearWatch(this.watchId)
    this.watchId = null
    if (this.heartbeatId) window.clearInterval(this.heartbeatId)
    this.heartbeatId = null
    this.position = null
    try {
      await this.send(this.presenceUrlValue, {}, "DELETE")
      this.say("Compartilhamento de localização encerrado.")
    } catch (_error) {
      this.say("Não foi possível encerrar o compartilhamento agora.")
    }
  }

  disconnect() {
    if (this.watchId) navigator.geolocation.clearWatch(this.watchId)
    if (this.heartbeatId) window.clearInterval(this.heartbeatId)
    if (this.position) this.send(this.presenceUrlValue, {}, "DELETE").catch(() => {})
  }

  async sendPresence() {
    if (!this.position || Date.now() - this.lastSentAt < 30000) return
    this.lastSentAt = Date.now()
    try {
      await this.send(this.presenceUrlValue, this.position)
      this.say("Localização compartilhada durante o plantão.")
    } catch (_error) {
      this.say("Não foi possível atualizar sua localização de plantão.")
    }
  }

  async send(url, body, method = "POST") {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const response = await fetch(url, {
      method,
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token, Accept: "application/json" },
      body: method === "POST" ? JSON.stringify(body) : undefined,
      credentials: "same-origin"
    })
    if (!response.ok) throw new Error("Não foi possível ativar esse recurso.")
  }

  decodeKey(value) {
    const padding = "=".repeat((4 - value.length % 4) % 4)
    const raw = atob((value + padding).replace(/-/g, "+").replace(/_/g, "/"))
    return Uint8Array.from(raw, (character) => character.charCodeAt(0))
  }

  say(message) { this.statusTarget.textContent = message }
}
