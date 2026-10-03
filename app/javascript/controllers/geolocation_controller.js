import { Controller } from "@hotwired/stimulus"

// Localização da ocorrência. Só pede permissão depois do clique e mostra cada estado
// (carregando, negado, indisponível, tempo esgotado, sem suporte), sugerindo o local manual.
// O servidor valida de novo pares, faixas e horário da captura.
export default class extends Controller {
  static targets = ["source", "gpsPanel", "manualPanel", "captureButton", "status",
    "latitude", "longitude", "accuracy", "capturedAt"]
  static values = { hasLocations: Boolean }

  connect() {
    this.supported = "geolocation" in navigator
    if (this.hasCaptureButtonTarget) this.captureButtonTarget.classList.toggle("hidden", !this.supported)
    if (!this.supported) {
      this.say(this.fallbackText("Este navegador não oferece localização."))
    }
    this.switch()
  }

  switch() {
    const source = this.selectedSource()
    this.gpsPanelTarget.hidden = source !== "gps"
    this.manualPanelTarget.hidden = source !== "manual"
    if (source === "manual") this.clearGps()
  }

  capture() {
    if (!this.supported) return

    this.captureButtonTarget.disabled = true
    this.say("Obtendo localização… Se o navegador perguntar, permita o acesso.")
    navigator.geolocation.getCurrentPosition(
      (position) => this.captured(position),
      (error) => this.failed(error),
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 }
    )
  }

  captured(position) {
    const { latitude, longitude, accuracy } = position.coords
    this.latitudeTarget.value = latitude.toFixed(7)
    this.longitudeTarget.value = longitude.toFixed(7)
    this.accuracyTarget.value = Number.isFinite(accuracy) ? accuracy.toFixed(2) : ""
    this.capturedAtTarget.value = new Date(position.timestamp || Date.now()).toISOString()
    this.captureButtonTarget.disabled = false
    const precision = Number.isFinite(accuracy) ? ` (precisão aproximada de ${Math.round(accuracy)} m)` : ""
    this.say(`Localização capturada${precision}. Você pode capturar de novo se tiver se deslocado.`)
  }

  failed(error) {
    this.captureButtonTarget.disabled = false
    this.clearGps()
    const messages = {
      1: "Permissão de localização negada.",
      2: "O aparelho não conseguiu determinar a posição.",
      3: "A localização demorou demais (tempo esgotado)."
    }
    this.say(this.fallbackText(messages[error.code] || "Não foi possível obter a localização."))
  }

  clearGps() {
    ;[this.latitudeTarget, this.longitudeTarget, this.accuracyTarget, this.capturedAtTarget].forEach((field) => { field.value = "" })
  }

  fallbackText(reason) {
    return this.hasLocationsValue
      ? `${reason} Escolha um local cadastrado em “Escolha de prédio ou área”.`
      : `${reason} Ainda não há locais cadastrados; tente novamente o GPS em área aberta ou mais tarde.`
  }

  selectedSource() {
    const checked = this.sourceTargets.find((input) => input.checked)
    return checked ? checked.value : null
  }

  say(text) {
    this.statusTarget.textContent = text
  }
}
