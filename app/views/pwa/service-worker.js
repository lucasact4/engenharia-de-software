self.addEventListener("push", (event) => {
  if (!event.data) return
  const payload = event.data.json()
  event.waitUntil(self.registration.showNotification(payload.title, {
    body: payload.body,
    icon: payload.icon || "/icon.png",
    tag: payload.tag || "sgu-emergency",
    requireInteraction: true,
    data: payload.data || {}
  }))
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const path = event.notification.data.path || "/painel"
  event.waitUntil(clients.matchAll({ type: "window", includeUncontrolled: true }).then((windows) => {
    const existing = windows.find((client) => new URL(client.url).pathname === path)
    return existing ? existing.focus() : clients.openWindow(path)
  }))
})
