import { Controller } from "@hotwired/stimulus"

// Contagem pelo horário real: alternar abas não acumula atraso dos intervalos.
export default class extends Controller {
  static targets = ["display", "toggle", "announcer", "editor", "minutes"]
  static values = { duration: { type: Number, default: 420 } }

  connect() {
    this.remaining = this.durationValue * 1000
    this.running = false
    this.onVisibility = () => this.tick()
    document.addEventListener("visibilitychange", this.onVisibility)
    this.render()
  }

  disconnect() {
    clearInterval(this.interval)
    document.removeEventListener("visibilitychange", this.onVisibility)
  }

  toggle() {
    if (this.running) {
      this.remaining = Math.max(0, this.deadline - Date.now())
      this.stop()
      this.announce("Contador pausado.")
    } else {
      if (this.remaining <= 0) this.remaining = this.durationValue * 1000
      this.deadline = Date.now() + this.remaining
      this.running = true
      this.interval = setInterval(() => this.tick(), 200)
      this.announce("Contador iniciado.")
    }
    this.render()
  }

  tick() {
    if (!this.running) return
    this.remaining = Math.max(0, this.deadline - Date.now())
    if (this.remaining === 0) {
      this.stop()
      this.announce("Tempo da apresentação encerrado.")
    }
    this.render()
  }

  stop() { this.running = false; clearInterval(this.interval) }

  reset() {
    this.stop()
    this.remaining = this.durationValue * 1000
    this.announce("Contador resetado e pausado.")
    this.render()
  }

  edit(event) {
    this.editorTrigger = event.currentTarget
    this.minutesTarget.value = this.durationValue / 60
    this.editorTarget.showModal()
    this.minutesTarget.focus()
  }

  close() { this.editorTarget.close(); this.editorTrigger?.focus() }

  save(event) {
    event.preventDefault()
    if (!this.minutesTarget.reportValidity()) return
    this.durationValue = Number(this.minutesTarget.value) * 60
    this.reset()
    this.close()
  }

  render() {
    const seconds = Math.ceil(this.remaining / 1000)
    this.displayTarget.textContent = `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`
    this.element.classList.toggle("is-ending", seconds > 0 && seconds <= 60)
    this.element.classList.toggle("is-finished", seconds === 0)
    this.toggleTarget.setAttribute("aria-label", this.running ? "Pausar contador" : "Iniciar contador")
    this.toggleTarget.setAttribute("aria-pressed", String(this.running))
    this.toggleTarget.querySelector("svg").innerHTML = this.running ? '<path d="M8 5v14M16 5v14"/>' : '<path d="m8 5 11 7-11 7z"/>'
  }

  announce(message) { this.announcerTarget.textContent = message }
}
