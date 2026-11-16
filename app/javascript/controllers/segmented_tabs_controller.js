import { Controller } from "@hotwired/stimulus"

// Abas no estilo do Instagram sobre seções que já estão na página (sem JS, todas aparecem).
// A aba inicial vem do #âncora da URL (ex.: #followups_people) ou é a primeira.
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.sync = this.sync.bind(this)
    window.addEventListener("hashchange", this.sync)
    document.addEventListener("turbo:load", this.sync)
    this.sync()
  }

  disconnect() {
    window.removeEventListener("hashchange", this.sync)
    document.removeEventListener("turbo:load", this.sync)
  }

  sync() {
    const fromHash = this.panelTargets.find((panel) => `#${panel.id}` === window.location.hash)
    this.select((fromHash || this.panelTargets[0])?.id)
  }

  show(event) {
    event.preventDefault()
    const id = event.currentTarget.getAttribute("href").slice(1)
    this.select(id)
    window.history.replaceState(window.history.state, "", `#${id}`)
  }

  select(id) {
    if (!id) return
    this.panelTargets.forEach((panel) => { panel.hidden = panel.id !== id })
    this.tabTargets.forEach((tab) => {
      const active = tab.getAttribute("href") === `#${id}`
      tab.setAttribute("aria-selected", active)
      tab.tabIndex = active ? 0 : -1
    })
  }
}
