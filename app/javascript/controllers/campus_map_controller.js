import { Controller } from "@hotwired/stimulus"

const INLINE_PUBLICATION_LIMIT = 3

export default class extends Controller {
  static targets = ["map", "status"]
  static values = { locations: Array, spots: Array, center: Array, buildingsUrl: String }

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
      const buildingsResponse = await fetch(this.buildingsUrlValue, { headers: { Accept: "application/geo+json, application/json" } })
      if (!buildingsResponse.ok) throw new Error("Campus outline data unavailable")
      const buildings = await buildingsResponse.json()
      if (this.disposed || !this.element.isConnected) return

      this.map = L.map(this.mapTarget, { scrollWheelZoom: true }).setView(this.centerValue, 16)
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 20,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      }).addTo(this.map)

      const bounds = []
      this.addOfficialBuildings(buildings, bounds)
      this.locationsValue.forEach(location => this.addLocation(location, bounds))
      this.spotsValue.forEach(spot => this.addReport(spot, bounds))
      if (bounds.length) this.map.fitBounds(bounds, { padding: [24, 24], maxZoom: 18 })
      const publicationCount = this.spotsValue.reduce((count, spot) => count + spot.count, 0)
      this.statusTarget.textContent = `${publicationCount} publicação(ões) ativa(s); ${publicationCount} ocorrência(s) localizada(s) em ${this.spotsValue.length} local(is) da sede Recife.`
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

  addOfficialBuildings(buildings, bounds) {
    L.geoJSON(buildings, {
      style: feature => {
        const color = this.colorForBuilding(feature)
        return { color, fillColor: color, fillOpacity: 0.34, weight: 1.5 }
      },
      onEachFeature: (feature, layer) => {
        bounds.push(layer.getBounds())
        const name = document.createElement("strong")
        name.textContent = feature.properties?.name || "Edifício da UFRPE"
        layer.bindPopup(name, { className: "campus-map-popup", minWidth: 180, maxWidth: 320 })
      }
    }).addTo(this.map)
  }

  colorForBuilding(feature) {
    const colors = ["#16a34a", "#f97316", "#dc2626", "#7c3aed", "#0891b2", "#ca8a04", "#db2777", "#2563eb"]
    const index = Number.parseInt(feature?.id, 10) || 0
    return colors[Math.abs(index || 0) % colors.length]
  }

  addReport(report, bounds) {
    const point = [report.latitude, report.longitude]
    const icon = L.divIcon({
      className: "campus-map-spot",
      html: `<span><b>${report.count}</b></span>`,
      iconSize: [32, 32],
      iconAnchor: [16, 32]
    })
    const marker = L.marker(point, { icon, title: `${report.count} publicação(ões) neste local` }).addTo(this.map)
    const popup = document.createElement("div")
    popup.className = "campus-popup"
    const heading = document.createElement("h3")
    heading.className = "campus-popup-heading"
    heading.textContent = report.publications.length === 1 ? "Lista de ocorrência no local" : "Lista de ocorrências no local"
    popup.append(heading)

    if (report.publications.length <= INLINE_PUBLICATION_LIMIT) {
      const titles = document.createElement("ul")
      titles.className = "campus-popup-titles"
      report.publications.forEach(publication => {
        const item = document.createElement("li")
        const title = document.createElement("a")
        title.className = "campus-popup-title"
        title.href = publication.url
        title.textContent = publication.title
        item.append(title)
        titles.append(item)
      })
      popup.append(titles)
    } else {
      const toggle = document.createElement("button")
      toggle.className = "campus-popup-toggle"
      toggle.type = "button"
      toggle.textContent = `Ver publicações (${report.publications.length})`
      toggle.setAttribute("aria-expanded", "false")

      const list = document.createElement("ul")
      list.className = "campus-popup-list"
      list.hidden = true
      report.publications.forEach(publication => {
        const item = document.createElement("li")
        item.className = "campus-popup-row"
        const title = document.createElement("span")
        title.className = "campus-popup-title"
        title.textContent = publication.title
        const link = document.createElement("a")
        link.className = "campus-popup-open"
        link.href = publication.url
        link.textContent = "Abrir"
        link.setAttribute("aria-label", `Abrir ${publication.title} no mural`)
        item.append(title, link)
        list.append(item)
      })

      toggle.addEventListener("click", () => {
        const expanded = toggle.getAttribute("aria-expanded") === "true"
        toggle.setAttribute("aria-expanded", String(!expanded))
        toggle.textContent = expanded ? `Ver publicações (${report.publications.length})` : "Ocultar publicações"
        list.hidden = expanded
      })
      popup.append(toggle, list)
    }

    const mapLink = document.createElement("a")
    mapLink.className = "campus-popup-map-link"
    mapLink.href = report.google_maps_url
    mapLink.target = "_blank"
    mapLink.rel = "noopener noreferrer"
    mapLink.textContent = "Ver localização no Google Maps ↗"
    popup.append(mapLink)

    marker.bindPopup(popup, { className: "campus-map-popup", minWidth: 250, maxWidth: 380 })
    bounds.push(point)
  }
}
