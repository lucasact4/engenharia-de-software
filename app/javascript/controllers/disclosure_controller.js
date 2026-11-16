import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  outside(event) {
    if (this.element.open && !this.element.contains(event.target)) this.element.open = false
  }

  close(event) {
    if (!this.element.open) return
    event.preventDefault()
    this.element.open = false
    this.element.querySelector("summary")?.focus()
  }
}
