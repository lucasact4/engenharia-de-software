// Aplica a preferência antes da primeira pintura e mantém o tema durante a navegação Turbo.
(() => {
  if (window.sguThemeInstalled) return
  window.sguThemeInstalled = true
  const key = "sgu.theme"
  let theme = "dark"
  try { if (localStorage.getItem(key) === "light") theme = "light" } catch {}
  const sync = () => {
    document.documentElement.dataset.theme = theme
    document.querySelectorAll("[data-theme-toggle]").forEach(button => {
      button.setAttribute("aria-label", theme === "dark" ? "Ativar modo claro" : "Ativar modo escuro")
      button.setAttribute("aria-pressed", String(theme === "light"))
      button.title = button.getAttribute("aria-label")
    })
  }
  sync()
  document.addEventListener("DOMContentLoaded", sync)
  document.addEventListener("turbo:load", sync)
  document.addEventListener("turbo:render", sync)
  document.addEventListener("turbo:before-render", event => { event.detail.newBody.ownerDocument.documentElement.dataset.theme = theme })
  document.addEventListener("click", event => {
    if (!event.target.closest("[data-theme-toggle]")) return
    theme = theme === "dark" ? "light" : "dark"
    try { localStorage.setItem(key, theme) } catch {}
    sync()
  })
  window.addEventListener("storage", event => {
    if (event.key !== key && event.key !== null) return
    theme = event.newValue === "light" ? "light" : "dark"
    sync()
  })
})()
