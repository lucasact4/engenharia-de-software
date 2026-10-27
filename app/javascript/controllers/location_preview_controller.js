import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { latitude: Number, longitude: Number }

  connect() {
    this.disposed = false
    this.loadMap()
  }

  disconnect() {
    this.disposed = true
    this.map?.remove()
  }

  async loadMap() {
    try {
      await import("leaflet")
      if (this.disposed || !this.element.isConnected) return

      const point = [this.latitudeValue, this.longitudeValue]
      this.map = L.map(this.element, { scrollWheelZoom: false }).setView(point, 17)
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      }).addTo(this.map)
      L.circleMarker(point, { radius: 9, color: "#0f766e", fillColor: "#14b8a6", fillOpacity: 1, weight: 3 }).addTo(this.map)
      requestAnimationFrame(() => this.map?.invalidateSize())
    } catch {
      this.element.textContent = "Não foi possível carregar o mapa. Use o link para abrir a localização no Google Maps."
      this.element.classList.add("flex", "items-center", "justify-center", "bg-surface-muted", "px-4", "text-center", "text-sm", "text-muted")
    }
  }
}
