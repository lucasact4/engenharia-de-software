import { Controller } from "@hotwired/stimulus"

// Alterações nas fotos existentes só são efetivadas ao salvar o formulário.
export default class extends Controller {
  static targets = ["input", "preview", "fields", "status"]
  static values = { existing: Array }

  connect() {
    this.photos = this.existingValue.map(photo => ({ ...photo, persisted: true }))
    this.removed = []
    this.render()
  }

  disconnect() { this.photos.filter(photo => !photo.persisted).forEach(photo => URL.revokeObjectURL(photo.url)) }

  update() {
    const selected = Array.from(this.inputTarget.files)
    if (this.photos.length + selected.length > 5) {
      this.say("Você pode usar até 5 fotos. Remova uma antes de adicionar outras.")
      this.syncFiles()
      return
    }
    for (const file of selected) {
      if (!["image/png", "image/jpeg"].includes(file.type) || file.size > 5 * 1024 * 1024) {
        this.say("Selecione imagens PNG ou JPEG de até 5 MB.")
        this.syncFiles()
        return
      }
    }
    this.photos.push(...selected.map(file => ({ file, url: URL.createObjectURL(file), persisted: false })))
    this.render()
    this.say(`${this.photos.length} foto(s) selecionada(s). A primeira será a capa.`)
  }

  render(focusIndex = null) {
    this.previewTarget.replaceChildren()
    this.photos.forEach((photo, index) => {
      const card = document.createElement("div")
      card.className = "photo-editor-card"
      card.dataset.photoPosition = index + 1
      const image = document.createElement("img")
      image.addEventListener("load", () => { image.dataset.ready = "true" }, { once: true })
      image.src = photo.url
      image.alt = `Prévia da foto ${index + 1}`
      const badge = document.createElement("span")
      badge.className = "photo-editor-badge"
      badge.textContent = index === 0 ? "Capa" : `Foto ${index + 1}`
      const controls = document.createElement("div")
      controls.className = "photo-editor-controls"
      controls.append(this.button(index === 0 ? "Capa atual" : "Usar como capa", `Usar foto ${index + 1} como capa`, () => this.move(index, 0), index === 0))
      const ordering = document.createElement("div")
      ordering.className = "photo-editor-order"
      ordering.append(this.button("←", `Mover foto ${index + 1} para antes`, () => this.move(index, index - 1), index === 0))
      ordering.append(this.button("→", `Mover foto ${index + 1} para depois`, () => this.move(index, index + 1), index === this.photos.length - 1))
      ordering.append(this.button("Remover", `Remover foto ${index + 1}`, () => this.remove(index)))
      controls.append(ordering)
      card.append(image, badge, controls)
      this.previewTarget.append(card)
    })
    this.syncFiles()
    this.syncFields()
    if (focusIndex !== null) this.previewTarget.children[focusIndex]?.querySelector("button:not([disabled])")?.focus()
  }

  button(text, label, action, disabled = false) {
    const button = document.createElement("button")
    button.type = "button"
    button.textContent = text
    button.setAttribute("aria-label", label)
    button.disabled = disabled
    button.addEventListener("click", action)
    return button
  }

  move(from, to) {
    const [photo] = this.photos.splice(from, 1)
    this.photos.splice(to, 0, photo)
    this.render(to)
    this.say(to === 0 ? "Capa atualizada. Salve para confirmar." : "Ordem atualizada. Salve para confirmar.")
  }

  remove(index) {
    const [photo] = this.photos.splice(index, 1)
    if (photo.persisted) this.removed.push(photo.id)
    else URL.revokeObjectURL(photo.url)
    this.render(Math.min(index, this.photos.length - 1))
    this.say("Foto removida da seleção. Salve para confirmar.")
  }

  syncFiles() {
    const transfer = new DataTransfer()
    this.photos.filter(photo => !photo.persisted).forEach(photo => transfer.items.add(photo.file))
    this.inputTarget.files = transfer.files
  }

  syncFields() {
    if (!this.hasFieldsTarget) return
    this.fieldsTarget.replaceChildren()
    const pending = this.photos.filter(photo => !photo.persisted)
    this.photos.forEach(photo => this.hidden("alert[photo_order][]", photo.persisted ? `existing_${photo.id}` : `new_${pending.indexOf(photo)}`))
    this.removed.forEach(id => this.hidden("alert[removed_photo_ids][]", id))
  }

  hidden(name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    this.fieldsTarget.append(input)
  }

  say(text) { if (this.hasStatusTarget) this.statusTarget.textContent = text }
}
