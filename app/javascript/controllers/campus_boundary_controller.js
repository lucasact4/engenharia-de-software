import { Controller } from "@hotwired/stimulus"

// Editor simples de polígonos para os contornos revisados pela administração.
export default class extends Controller {
  static targets = ["map", "input", "status"]
  static values = { geojson: String }

  async connect() {
    this.disposed = false
    try {
      await import("leaflet")
      if (this.disposed || !this.element.isConnected) return
      this.map = L.map(this.mapTarget, { scrollWheelZoom: false }).setView([-8.0175, -34.9492], 16)
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      }).addTo(this.map)
      this.layer = L.featureGroup().addTo(this.map)
      this.points = []
      this.renderSavedBoundary()
      this.onMapClick = event => {
        if (this.drawing) this.addPoint(this.map.mouseEventToLatLng(event))
      }
      this.mapTarget.addEventListener("click", this.onMapClick, true)
      requestAnimationFrame(() => this.map?.invalidateSize())
    } catch {
      this.statusTarget.textContent = "O mapa não carregou; tente novamente mais tarde."
    }
  }

  disconnect() {
    this.disposed = true
    if (this.onMapClick) this.mapTarget.removeEventListener("click", this.onMapClick, true)
    this.map?.remove()
  }

  start() {
    this.drawing = true
    this.editing = false
    this.points = []
    this.layer.clearLayers()
    this.inputTarget.value = ""
    this.statusTarget.textContent = "Clique no mapa para marcar os vértices do prédio."
  }

  addPoint(point) {
    if (!this.drawing) return
    this.points.push(point)
    L.circleMarker(point, { radius: 5, color: "#0f766e", fillOpacity: 1 }).addTo(this.layer)
    if (this.points.length > 1) L.polyline(this.points, { color: "#0f766e", weight: 2 }).addTo(this.layer)
    this.statusTarget.textContent = `${this.points.length} ponto(s) marcado(s).`
  }

  undo() {
    if ((!this.drawing && !this.editing) || this.points.length === 0) return
    if (this.editing && this.points.length <= 3) {
      this.statusTarget.textContent = "O contorno precisa manter pelo menos três vértices."
      return
    }
    this.points.pop()
    if (this.editing) this.renderEditableBoundary()
    else {
      this.layer.clearLayers()
      const points = [...this.points]
      this.points = []
      points.forEach(point => this.addPoint(point))
    }
  }

  edit() {
    if (!this.geojsonValue) return
    try {
      const boundary = JSON.parse(this.geojsonValue)
      const ring = boundary.coordinates?.[0]
      if (boundary.type !== "Polygon" || !Array.isArray(ring) || ring.length < 4) throw new Error()
      this.drawing = false
      this.editing = true
      this.points = ring.slice(0, -1).map(([longitude, latitude]) => L.latLng(latitude, longitude))
      this.renderEditableBoundary()
      this.statusTarget.textContent = "Arraste os pontos brancos para ajustar o contorno. Salve o local para aplicar as correções."
    } catch {
      this.statusTarget.textContent = "O contorno salvo não pôde ser editado. Redesenhe a área."
    }
  }

  renderEditableBoundary() {
    this.layer.clearLayers()
    L.polygon(this.points, { color: "#0f766e", fillColor: "#14b8a6", fillOpacity: 0.28, weight: 2 }).addTo(this.layer)
    this.points.forEach((point, index) => {
      L.marker(point, {
        draggable: true,
        icon: L.divIcon({ className: "boundary-edit-handle", iconSize: [18, 18], iconAnchor: [9, 9] })
      }).addTo(this.layer).on("dragend", event => {
        this.points[index] = event.target.getLatLng()
        this.renderEditableBoundary()
      })
    })
    this.updateGeoJSON()
  }

  updateGeoJSON() {
    const first = this.points[0]
    const coordinates = [...this.points, first].map(point => [point.lng, point.lat])
    this.inputTarget.value = JSON.stringify({ type: "Polygon", coordinates: [coordinates] })
  }

  finish() {
    if ((!this.drawing && !this.editing) || this.points.length < 3) {
      this.statusTarget.textContent = "Marque pelo menos três pontos antes de finalizar."
      return
    }
    this.updateGeoJSON()
    this.layer.clearLayers()
    L.polygon(this.points, { color: "#0f766e", fillColor: "#14b8a6", fillOpacity: 0.28, weight: 2 }).addTo(this.layer)
    this.drawing = false
    this.editing = false
    this.statusTarget.textContent = "Contorno finalizado. Salve o local para aplicar a alteração."
  }

  clear() {
    this.drawing = false
    this.editing = false
    this.points = []
    this.layer.clearLayers()
    this.inputTarget.value = ""
    this.statusTarget.textContent = "Contorno removido. Salve o local para aplicar a alteração."
  }

  renderSavedBoundary() {
    if (!this.geojsonValue) return
    try {
      const boundary = JSON.parse(this.geojsonValue)
      const layer = L.geoJSON(boundary).addTo(this.layer)
      this.map.fitBounds(layer.getBounds(), { padding: [20, 20] })
      this.points = boundary.coordinates[0].slice(0, -1).map(([longitude, latitude]) => L.latLng(latitude, longitude))
    } catch {
      this.statusTarget.textContent = "O contorno salvo não pôde ser exibido. Redesenhe-o antes de salvar."
    }
  }
}
