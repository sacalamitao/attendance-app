import { Controller } from "@hotwired/stimulus"

// Polling fallback for live dashboards. Turbo Streams push refreshes over
// Action Cable; this timer guarantees the page still catches up if the socket
// is unavailable. Turbo 8 morphs the page so scroll/focus are preserved.
export default class extends Controller {
  static targets = ["status"]
  static values = { interval: { type: Number, default: 0 } }

  connect() {
    if (this.intervalValue > 0) {
      this.timer = setInterval(() => this.refresh(), this.intervalValue)
    }
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  refresh() {
    if (document.hidden || navigator.onLine === false) return
    Turbo.visit(window.location.href, { action: "replace" })
  }
}
