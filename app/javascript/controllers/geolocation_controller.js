import { Controller } from "@hotwired/stimulus"

// GPS exige clique; seleção no mapa não gera horário ou precisão fictícios de captura.
export default class extends Controller {
  static targets = ["source", "gpsPanel", "manualPanel", "mapPanel", "captureButton", "status",
    "latitude", "longitude", "accuracy", "capturedAt", "map", "mapLatitude", "mapLongitude", "googleLink", "googleUrl", "catalog"]

  connect() {
    this.disposed = false
    this.supported = "geolocation" in navigator
    this.request = 0
    if (this.hasCaptureButtonTarget) this.captureButtonTarget.disabled = !this.supported
    this.switch()
    if (!this.supported && this.selectedSource() === "gps") this.say("GPS indisponível. Você pode marcar no mapa ou informar o local.")
  }

  disconnect() {
    this.disposed = true
    this.request++
    this.mapInstance?.remove()
  }

  switch() {
    const source = this.selectedSource()
    this.request++
    this.gpsPanelTarget.hidden = source !== "gps"
    this.manualPanelTarget.hidden = source !== "manual"
    this.mapPanelTarget.hidden = source !== "map"
    ;[this.mapLatitudeTarget, this.mapLongitudeTarget, this.googleUrlTarget].forEach(input => { input.disabled = source !== "map" })
    if (source === "manual" || (source === "gps" && this.currentSource === "map")) this.clearGps()
    if (source === "map") {
      this.accuracyTarget.value = ""
      this.capturedAtTarget.value = ""
      this.ensureMap()
    }
    this.currentSource = source
    this.captureButtonTarget.disabled = !this.supported
    this.updateLink()
  }

  catalogChanged() {
    if (this.catalogTarget.value && !this.latitudeTarget.value) {
      this.sourceTargets.find(input => input.value === "manual").checked = true
      this.switch()
    }
  }

  capture() {
    if (!this.supported) return
    const request = ++this.request
    this.captureButtonTarget.disabled = true
    this.say("Obtendo localização… Autorize o GPS no navegador.")
    navigator.geolocation.getCurrentPosition(
      position => {
        if (request !== this.request || this.disposed || this.selectedSource() !== "gps") return
        const { latitude, longitude, accuracy } = position.coords
        this.latitudeTarget.value = latitude.toFixed(7)
        this.longitudeTarget.value = longitude.toFixed(7)
        this.accuracyTarget.value = Number.isFinite(accuracy) ? accuracy.toFixed(2) : ""
        this.capturedAtTarget.value = new Date(position.timestamp || Date.now()).toISOString()
        this.captureButtonTarget.disabled = false
        this.updateLink()
        const precision = Number.isFinite(accuracy) ? ` (precisão aproximada de ${Math.round(accuracy)} m)` : ""
        this.say(`Localização capturada${precision}. Você pode capturar de novo.`)
      },
      error => {
        if (request !== this.request || this.disposed) return
        this.captureButtonTarget.disabled = false
        this.clearGps()
        const messages = { 1: "Permissão de localização negada.", 2: "O aparelho não conseguiu determinar a posição.", 3: "A localização demorou demais (tempo esgotado)." }
        this.say(`${messages[error.code] || "Não foi possível obter a localização."} Você também pode descrever o local ou marcar no mapa.`)
      },
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 }
    )
  }

  async ensureMap() {
    try {
      if (!this.mapInstance) {
        await import("leaflet")
        if (this.disposed || !this.element.isConnected) return
        if (this.mapInstance) return this.mapInstance.invalidateSize()
        const coordinates = this.coordinates() || [-8.05, -34.9]
        this.mapInstance = L.map(this.mapTarget, { scrollWheelZoom: false }).setView(coordinates, this.coordinates() ? 17 : 12)
        L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
          maxZoom: 19,
          attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        }).addTo(this.mapInstance)
        this.mapInstance.on("click", event => this.setPoint(event.latlng.lat, event.latlng.lng))
        if (this.coordinates()) this.showMarker(...this.coordinates())
      }
      requestAnimationFrame(() => this.mapInstance?.invalidateSize())
    } catch {
      this.say("O mapa não carregou. Use GPS, informe coordenadas ou descreva o local.")
    }
  }

  useCenter() {
    if (!this.mapInstance) return
    const center = this.mapInstance.getCenter()
    this.setPoint(center.lat, center.lng)
  }

  coordinatesChanged() {
    if (!this.mapLatitudeTarget.value || !this.mapLongitudeTarget.value) {
      this.clearPoint()
      return this.say("Informe as duas coordenadas para marcar o ponto.")
    }
    this.setPoint(Number(this.mapLatitudeTarget.value), Number(this.mapLongitudeTarget.value))
  }

  setPoint(latitude, longitude) {
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
      this.clearPoint()
      this.say("Confira latitude (-90 a 90) e longitude (-180 a 180).")
      return
    }
    this.latitudeTarget.value = latitude.toFixed(7)
    this.longitudeTarget.value = longitude.toFixed(7)
    this.accuracyTarget.value = ""
    this.capturedAtTarget.value = ""
    this.showMarker(latitude, longitude)
    this.updateLink()
    this.say("Ponto selecionado no mapa. Confira se corresponde ao local da ocorrência.")
  }

  showMarker(latitude, longitude) {
    this.mapLatitudeTarget.value = latitude.toFixed(7)
    this.mapLongitudeTarget.value = longitude.toFixed(7)
    if (!this.mapInstance) return
    if (this.marker) this.marker.setLatLng([latitude, longitude])
    else this.marker = L.marker([latitude, longitude], {
      draggable: true,
      title: "Local da ocorrência",
      icon: L.divIcon({ className: "occurrence-map-pin", html: "<span></span>", iconSize: [24, 24], iconAnchor: [12, 24] })
    }).addTo(this.mapInstance).on("dragend", event => {
      const point = event.target.getLatLng()
      this.setPoint(point.lat, point.lng)
    })
    this.mapInstance.setView([latitude, longitude], Math.max(16, this.mapInstance.getZoom()), { animate: false })
  }

  importGoogle() {
    try {
      const url = new URL(this.googleUrlTarget.value.trim())
      const allowed = ["google.com", "www.google.com", "maps.google.com", "google.com.br", "www.google.com.br"]
      if (url.protocol !== "https:" || !allowed.includes(url.hostname) || (url.hostname !== "maps.google.com" && !url.pathname.startsWith("/maps"))) throw new Error()
      const path = decodeURIComponent(url.pathname)
      const point = path.match(/!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/) ||
        (url.searchParams.get("query") || url.searchParams.get("q") || url.searchParams.get("ll") || "").match(/^(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)$/) ||
        path.match(/@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/)
      if (!point) throw new Error()
      this.setPoint(Number(point[1]), Number(point[2]))
    } catch {
      this.say("Use um link completo do Google Maps com coordenadas. Se o link for curto, abra-o e copie o endereço completo, ou marque o ponto neste mapa.")
    }
  }

  coordinates() {
    if (!this.latitudeTarget.value || !this.longitudeTarget.value) return null
    return [Number(this.latitudeTarget.value), Number(this.longitudeTarget.value)]
  }

  updateLink() {
    if (this.hasGoogleLinkTarget) this.googleLinkTarget.href = this.coordinates() ? `https://www.google.com/maps/search/?api=1&query=${this.coordinates().join(",")}` : "https://www.google.com/maps"
  }

  clearPoint() {
    this.clearGps()
    this.marker?.remove()
    this.marker = null
    this.updateLink()
  }

  clearGps() {
    ;[this.latitudeTarget, this.longitudeTarget, this.accuracyTarget, this.capturedAtTarget].forEach(field => { field.value = "" })
  }

  selectedSource() { return this.sourceTargets.find(input => input.checked)?.value }
  say(text) { this.statusTarget.textContent = text }
}
