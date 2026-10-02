import { Controller } from "@hotwired/stimulus"

// Versões dos cards de tecnologia (slide de arquitetura e tecnologias).
// Recolhidas, aparecem como dica ao passar o mouse ou focar um card; "Mostrar versões" as exibe
// em todos os cards. O estado vale só para esta página: não altera o perfil salvo.
// Quando "Versões" está desmarcado no perfil ou no painel, o botão e as versões ficam ocultos.
export default class extends Controller {
  static targets = ["button"]

  toggle() {
    const expanded = !this.element.classList.contains("is-expanded")
    this.element.classList.toggle("is-expanded", expanded)
    if (!this.hasButtonTarget) return

    this.buttonTarget.setAttribute("aria-expanded", String(expanded))
    this.buttonTarget.textContent = expanded ? "Ocultar versões" : "Mostrar versões"
  }

  // Esc fecha a dica sem tirar o foco do card (WCAG 1.4.13).
  dismiss(event) {
    const card = event.currentTarget.closest(".apr-tech__card")
    if (!card || this.element.classList.contains("is-expanded")) return

    card.classList.add("is-dismissed")
    event.stopPropagation()
  }

  restore(event) {
    event.currentTarget.closest(".apr-tech__card")?.classList.remove("is-dismissed")
  }
}
