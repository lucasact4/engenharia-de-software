import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["map", "status"]
  static values = { locations: Array, reports: Array, center: Array }

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

      this.map = L.map(this.mapTarget, { scrollWheelZoom: true }).setView(this.centerValue, 16)
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 20,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      }).addTo(this.map)

      const bounds = []
      this.locationsValue.forEach(location => this.addLocation(location, bounds))
      this.reportsValue.forEach(report => this.addReport(report, bounds))
      if (bounds.length) this.map.fitBounds(bounds, { padding: [24, 24], maxZoom: 18 })
      this.statusTarget.textContent = `${this.reportsValue.length} ocorrência(s) localizada(s) em áreas cadastradas da sede Recife.`
      requestAnimationFrame(() => this.map?.invalidateSize())
    } catch {
      this.statusTarget.textContent = "Não foi possível carregar o mapa. Verifique sua conexão e tente novamente."
    }
  }

  addLocation(location, bounds) {
    const ring = location.boundary?.coordinates?.[0]
    if (location.boundary?.type !== "Polygon" || !Array.isArray(ring)) return

    const polygon = L.polygon(ring.map(([longitude, latitude]) => [latitude, longitude]), {
      color: location.color, fillColor: location.color, fillOpacity: 0.42, weight: 2
    }).addTo(this.map)
    bounds.push(polygon.getBounds())
  }

  addReport(report, bounds) {
    const point = [report.latitude, report.longitude]
    const marker = L.circleMarker(point, { radius: 9, color: "#0f766e", fillColor: "#14b8a6", fillOpacity: 1, weight: 3 }).addTo(this.map)
    const popup = document.createElement("div")
    const title = document.createElement("strong")
    title.textContent = report.title
    const accuracy = document.createElement("p")
    accuracy.textContent = report.exact ? "Ponto exato compartilhado pelo autor" : "Local aproximado do prédio"
    const link = document.createElement("a")
    link.href = report.url
    link.textContent = "Abrir publicação do mural ↗"
    popup.append(title, accuracy, link)
    marker.bindPopup(popup)
    bounds.push(point)
  }
}
