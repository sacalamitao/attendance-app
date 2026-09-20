import { Controller } from "@hotwired/stimulus"

// Shows a persistent banner while the browser reports it is offline.
export default class extends Controller {
  static targets = ["banner"]

  connect() {
    this.update = this.update.bind(this)
    window.addEventListener("online", this.update)
    window.addEventListener("offline", this.update)
    this.update()
  }

  disconnect() {
    window.removeEventListener("online", this.update)
    window.removeEventListener("offline", this.update)
  }

  update() {
    const offline = navigator.onLine === false
    if (this.hasBannerTarget) this.bannerTarget.hidden = !offline
    document.documentElement.classList.toggle("is-offline", offline)
  }
}
