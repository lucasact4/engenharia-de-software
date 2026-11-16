import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]
  static values = { url: String, title: String }

  async share() {
    const url = new URL(this.urlValue, window.location.origin).href
    this.statusTarget.textContent = ""
    try {
      if (navigator.share) {
        await navigator.share({ title: this.titleValue, url })
      } else {
        await navigator.clipboard.writeText(url)
        this.statusTarget.textContent = "Link da publicação copiado."
      }
    } catch (error) {
      if (error.name === "AbortError") return
      const link = document.createElement("a")
      link.href = url
      link.textContent = "Abrir o link da publicação para compartilhar"
      link.className = "sgu-link"
      this.statusTarget.replaceChildren(link)
    }
  }
}
