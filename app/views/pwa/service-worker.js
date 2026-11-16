self.addEventListener("push", (event) => {
  if (!event.data) return
  let payload = {}
  try { payload = event.data.json() } catch (_error) { /* Mantém aviso genérico. */ }
  const emergency = typeof payload.title === "string"
  event.waitUntil(self.registration.showNotification(emergency ? payload.title : "SGU UFRPE", {
    body: payload.body || "Você tem uma nova notificação. Entre no SGU para ler.",
    icon: payload.icon || "/icon.png",
    tag: payload.tag || "sgu-notification",
    requireInteraction: emergency || payload.requireInteraction === true,
    data: { ...(payload.data || {}), path: payload.data?.path || "/notificacoes" }
  }))
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const path = event.notification.data?.path || "/notificacoes"
  event.waitUntil(clients.matchAll({ type: "window", includeUncontrolled: true }).then((windows) => {
    const existing = windows.find((client) => new URL(client.url).pathname === path)
    return existing ? existing.focus() : clients.openWindow(path)
  }))
})
