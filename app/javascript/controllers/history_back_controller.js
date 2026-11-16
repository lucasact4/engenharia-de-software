import { Controller } from "@hotwired/stimulus"

// Guarda a tela anterior dentro do SGU (navegações do Turbo não atualizam document.referrer).
const KEY = "sgu:navigation"
const SKIP = /^\/(entrar|cadastro|senha|sair|admin)(\/|$)/

function record() {
  try {
    const nav = JSON.parse(sessionStorage.getItem(KEY) || "{}")
    if (nav.current !== location.href) {
      nav.previous = nav.current
      nav.current = location.href
      sessionStorage.setItem(KEY, JSON.stringify(nav))
    }
  } catch { /* armazenamento indisponível: o link usa o destino padrão */ }
}

record()
document.addEventListener("turbo:load", record)

// "Voltar" do topo: volta no histórico quando a tela anterior é do próprio SGU;
// caso contrário segue o href (destino lógico da tela).
export default class extends Controller {
  go(event) {
    let previous
    try { previous = new URL(JSON.parse(sessionStorage.getItem(KEY) || "{}").previous) } catch { return }
    if (previous.origin !== location.origin || previous.pathname === location.pathname || SKIP.test(previous.pathname)) return
    if (window.history.length < 2) return

    event.preventDefault()
    window.history.back()
  }
}
