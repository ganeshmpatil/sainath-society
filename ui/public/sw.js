// Service Worker for Web Push Notifications — Sainath Society

self.addEventListener('push', (event) => {
  if (!event.data) return

  let payload
  try {
    payload = event.data.json()
  } catch {
    payload = { title: 'Sainath Society', body: event.data.text() }
  }

  const options = {
    body: payload.body || '',
    icon: payload.icon || '/sai.jpg',
    badge: payload.badge || '/sai.jpg',
    tag: payload.eventType || 'general',
    renotify: true,
    data: {
      url: payload.url || '/',
      eventType: payload.eventType,
      resourceId: payload.resourceId,
    },
  }

  event.waitUntil(self.registration.showNotification(payload.title || 'Sainath Society', options))
})

// When user clicks the notification, open the app
self.addEventListener('notificationclick', (event) => {
  event.notification.close()

  const url = event.notification.data?.url || '/'

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      // Focus existing tab if open
      for (const client of windowClients) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.focus()
          if (url !== '/') client.navigate(url)
          return
        }
      }
      // Otherwise open new tab
      return clients.openWindow(url)
    })
  )
})
