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
      this.spotLayer = L.layerGroup().addTo(this.map)
      this.spotMarkers = []
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 20,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      }).addTo(this.map)

      const bounds = []
      this.addOfficialBuildings(buildings, bounds)
      this.locationsValue.forEach(location => this.addLocation(location, bounds))
      this.spotsValue.forEach(spot => this.addReport(spot, bounds))
      if (bounds.length) this.map.fitBounds(bounds, { padding: [24, 24], maxZoom: 18 })
      this.map.on("zoomend moveend", this.refreshSpotLayer, this)
      this.refreshSpotLayer()
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
    const marker = L.marker(point, { icon, title: `${report.count} publicação(ões) neste local` })
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
    this.spotMarkers.push({ marker, report })
    bounds.push(point)
  }

  refreshSpotLayer() {
    if (!this.spotLayer || !this.map) return
    this.spotLayer.clearLayers()

    const groups = this.clusterSpots(this.clusterRadius())
    groups.forEach(group => {
      if (group.length === 1) {
        this.spotLayer.addLayer(group[0].marker)
      } else {
        this.spotLayer.addLayer(this.clusterMarker(group))
      }
    })
  }

  clusterRadius() {
    const zoom = this.map.getZoom()
    if (zoom >= 18) return 0
    if (zoom >= 16) return 30
    if (zoom >= 14) return 48
    return 64
  }

  clusterSpots(radius) {
    const items = this.spotMarkers.map(item => ({
      ...item,
      projected: this.map.project(item.marker.getLatLng(), this.map.getZoom())
    }))
    if (radius === 0) return items.map(item => [item])

    const parents = items.map((_item, index) => index)
    const find = index => {
      if (parents[index] !== index) parents[index] = find(parents[index])
      return parents[index]
    }
    const join = (first, second) => {
      const firstRoot = find(first)
      const secondRoot = find(second)
      if (firstRoot !== secondRoot) parents[secondRoot] = firstRoot
    }
    const cells = new Map()
    const radiusSquared = radius * radius

    items.forEach((item, index) => {
      const cellX = Math.floor(item.projected.x / radius)
      const cellY = Math.floor(item.projected.y / radius)
      for (let offsetX = -1; offsetX <= 1; offsetX++) {
        for (let offsetY = -1; offsetY <= 1; offsetY++) {
          const nearby = cells.get(`${cellX + offsetX}:${cellY + offsetY}`) || []
          nearby.forEach(otherIndex => {
            const other = items[otherIndex].projected
            const deltaX = item.projected.x - other.x
            const deltaY = item.projected.y - other.y
            if (deltaX * deltaX + deltaY * deltaY <= radiusSquared) join(index, otherIndex)
          })
        }
      }
      const cellKey = `${cellX}:${cellY}`
      cells.set(cellKey, [ ...(cells.get(cellKey) || []), index ])
    })

    const grouped = new Map()
    items.forEach((item, index) => {
      const root = find(index)
      grouped.set(root, [ ...(grouped.get(root) || []), item ])
    })
    return Array.from(grouped.values())
  }

  clusterMarker(group) {
    const publications = group.reduce((count, item) => count + item.report.count, 0)
    const center = L.latLng(
      group.reduce((sum, item) => sum + item.marker.getLatLng().lat, 0) / group.length,
      group.reduce((sum, item) => sum + item.marker.getLatLng().lng, 0) / group.length
    )
    const size = Math.max(40, 26 + String(publications).length * 9)
    const marker = L.marker(center, {
      icon: L.divIcon({
        className: "campus-map-cluster",
        html: `<span>${publications}</span>`,
        iconSize: [size, size],
        iconAnchor: [size / 2, size / 2]
      }),
      title: `${publications} publicações em ${group.length} locais próximos`
    })
    const bounds = L.latLngBounds(group.map(item => item.marker.getLatLng()))
    marker.on("click", () => {
      const currentZoom = this.map.getZoom()
      this.map.fitBounds(bounds, { padding: [36, 36], maxZoom: 18, animate: false })
      if (this.map.getZoom() <= currentZoom && currentZoom < 18) this.map.setZoom(currentZoom + 1)
    })
    return marker
  }
}
