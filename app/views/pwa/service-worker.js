const INBOX_PATH = "/notificacoes"

self.addEventListener("push", event => {
  let tag = "sgu-notification"
  try {
    const message = event.data?.json()
    if (/^sgu-\d+$/.test(message?.tag)) tag = message.tag
  } catch {
    // Um aviso genérico ainda pode ser exibido sem payload válido.
  }
  event.waitUntil(self.registration.showNotification("SGU UFRPE", {
    body: "Você tem uma nova notificação. Entre no SGU para ler.",
    tag
  }))
})

self.addEventListener("notificationclick", event => {
  event.notification.close()
  event.waitUntil((async () => {
    const inbox = new URL(INBOX_PATH, self.location.origin).href
    const windows = await self.clients.matchAll({ type: "window", includeUncontrolled: true })
    const current = windows.find(client => client.url === inbox)
    return current ? current.focus() : self.clients.openWindow(inbox)
  })())
})
