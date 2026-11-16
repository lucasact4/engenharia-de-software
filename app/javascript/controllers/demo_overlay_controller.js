import { Controller } from "@hotwired/stimulus"

// Abre /apresentacao/demo por cima dos slides, na mesma página: a tela cheia da apresentação continua.
// A página da demo avisa por postMessage quando "Voltar aos slides" é clicado.
export default class extends Controller {
  static targets = ["dialog", "frame"]

  connect() {
    this.onMessage = (event) => {
      if (event.origin === window.location.origin && event.data?.type === "sgu:demo-close") this.close()
    }
    window.addEventListener("message", this.onMessage)
  }

  disconnect() {
    window.removeEventListener("message", this.onMessage)
  }

  open(event) {
    event.preventDefault()
    if (!this.frameTarget.getAttribute("src")) {
      const url = new URL(event.currentTarget.href, window.location.href)
      url.searchParams.set("embed", "1")
      this.frameTarget.src = url.toString()
    }
    this.dialogTarget.showModal()
    this.frameTarget.focus()
  }

  close() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }
}
