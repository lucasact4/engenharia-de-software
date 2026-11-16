import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchDialog", "searchField", "compactLabel"]

  connect() {
    try { this.element.classList.toggle("mural-shell--compact", localStorage.getItem("sgu:mural-compact") !== "0") } catch { /* Preferência opcional. */ }
    this.updateNavigationLabel()
    if (this.hasSearchDialogTarget) {
      this.searchDialogTarget.close()
      if (new URLSearchParams(location.search).get("pesquisa") === "1") this.openSearch()
    }
  }

  openSearch(event) {
    if (!this.hasSearchDialogTarget) return
    event?.preventDefault()
    this.searchTrigger = event?.currentTarget
    this.searchDialogTarget.showModal()
    if (this.hasSearchFieldTarget) this.searchFieldTarget.focus()
  }

  closeSearch() {
    this.searchDialogTarget.close()
    this.searchTrigger?.focus()
  }

  closeBackdrop(event) {
    if (event.target === this.searchDialogTarget) this.closeSearch()
  }

  toggleNavigation() {
    const compact = this.element.classList.toggle("mural-shell--compact")
    try { localStorage.setItem("sgu:mural-compact", compact ? "1" : "0") } catch { /* Preferência opcional. */ }
    this.updateNavigationLabel()
  }

  updateNavigationLabel() {
    if (this.hasCompactLabelTarget) this.compactLabelTarget.textContent = this.element.classList.contains("mural-shell--compact") ? "Expandir menu" : "Recolher menu"
  }
}
