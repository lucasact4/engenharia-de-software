import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "position", "stopForm"]
  static values = { url: String, share: Boolean, stopped: Boolean }

  connect() {
    this.requests = new AbortController()
    if (this.shareValue && navigator.geolocation) {
      this.watch = navigator.geolocation.watchPosition(
        (position) => { this.pending = position },
        () => { this.statusTarget.textContent = "GPS indisponível. Verifique a permissão de localização." },
        { enableHighAccuracy: true, maximumAge: 0, timeout: 15000 }
      )
    }
    this.refresh()
  }

  disconnect() {
    this.requests?.abort()
    window.clearTimeout(this.timer)
    this.stopWatching()
  }

  stopWatching() {
    if (this.watch !== undefined) navigator.geolocation.clearWatch(this.watch)
    this.watch = undefined
    this.pending = null
  }

  async refresh() {
    const signal = this.requests.signal
    try {
      const position = this.pending
      if (position && !this.stoppedValue) {
        const token = document.querySelector('meta[name="csrf-token"]')?.content
        const response = await fetch(this.urlValue, {
          method: "PATCH", signal,
          headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
          body: JSON.stringify({
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
            captured_at: Math.trunc(position.timestamp)
          })
        })
        if (!response.ok && ![410, 422].includes(response.status)) throw new Error("GPS update failed")
        if (this.pending === position) this.pending = null
      }

      const response = await fetch(this.urlValue, { signal, headers: { Accept: "application/json" } })
      if (!response.ok || response.redirected) throw new Error("GPS status unavailable")
      const { stopped, position: latest, source } = await response.json()
      if (signal.aborted) return
      if (latest) {
        const time = new Date(latest.captured_at).toLocaleTimeString()
        const label = source === "live" ? "Última posição" : "Posição inicial (reserva)"
        this.positionTarget.textContent = `${label} às ${time} — ${latest.latitude.toFixed(5)}, ${latest.longitude.toFixed(5)}`
      }
      if (stopped) {
        this.positionTarget.textContent = ""
        this.stoppedValue = true
        this.stopWatching()
        this.statusTarget.textContent = "Acompanhamento encerrado."
        if (this.hasStopFormTarget) this.stopFormTarget.hidden = true
      } else {
        this.statusTarget.textContent = source === "live" ? "Acompanhamento ativo." : "Aguardando posição atual do GPS."
      }
    } catch (_error) {
      if (!signal.aborted) this.statusTarget.textContent = "Não foi possível sincronizar a localização."
    } finally {
      if (!signal.aborted && !this.stoppedValue) this.timer = window.setTimeout(() => this.refresh(), 5000)
    }
  }
}
