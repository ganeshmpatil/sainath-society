import { useEffect, useRef } from 'react'
import { apiClient } from '../api/client'

const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:8080/api/v1'

/**
 * Converts a base64url VAPID key to a Uint8Array for PushManager.subscribe().
 */
function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
  const rawData = window.atob(base64)
  const outputArray = new Uint8Array(rawData.length)
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i)
  }
  return outputArray
}

/**
 * usePushNotifications — registers the service worker and subscribes to
 * Web Push when the user is authenticated. Runs once on mount.
 */
export function usePushNotifications(isAuthenticated: boolean) {
  const subscribed = useRef(false)

  useEffect(() => {
    if (!isAuthenticated || subscribed.current) return
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) return

    const subscribe = async () => {
      try {
        // 1. Register service worker
        const registration = await navigator.serviceWorker.register('/sw.js')
        await navigator.serviceWorker.ready

        // 2. Get VAPID public key from server
        const { publicKey } = await apiClient.get<{ publicKey: string }>('/push/vapid-key')
        if (!publicKey) return

        // 3. Check existing subscription
        let subscription = await registration.pushManager.getSubscription()

        if (!subscription) {
          // 4. Request permission & subscribe
          const permission = await Notification.requestPermission()
          if (permission !== 'granted') return

          subscription = await registration.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: urlBase64ToUint8Array(publicKey) as BufferSource,
          })
        }

        // 5. Send subscription to server
        const key = subscription.getKey('p256dh')
        const auth = subscription.getKey('auth')
        if (!key || !auth) return

        await fetch(`${API_BASE}/push/subscribe`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${apiClient.getAccessToken()}`,
          },
          body: JSON.stringify({
            endpoint: subscription.endpoint,
            keyP256dh: btoa(String.fromCharCode(...new Uint8Array(key))),
            keyAuth: btoa(String.fromCharCode(...new Uint8Array(auth))),
          }),
        })

        subscribed.current = true
      } catch (err) {
        console.warn('Push subscription failed:', err)
      }
    }

    subscribe()
  }, [isAuthenticated])
}
