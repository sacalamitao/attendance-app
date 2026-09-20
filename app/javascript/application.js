// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Register the PWA service worker (app shell caching + offline page).
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker", { scope: "/" }).catch((error) => {
      console.warn("Service worker registration failed:", error)
    })
  })
}
