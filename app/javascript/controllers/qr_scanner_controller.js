import { Controller } from "@hotwired/stimulus"
import { apiRequest, ApiError } from "api"
import jsQR from "jsqr"

// Continuous QR attendance scanner.
//
// Decodes frames with the native BarcodeDetector when available and falls
// back to jsQR on a canvas. Every decoded payload is POSTed to the backend,
// which decides whether the scan is valid; the UI only renders the result.
const RESULT_STYLES = {
  neutral:   "border-slate-200 bg-white",
  recorded:  "border-emerald-500 bg-emerald-50",
  duplicate: "border-amber-400 bg-amber-50",
  error:     "border-rose-500 bg-rose-50",
  info:      "border-sky-400 bg-sky-50"
}

const FRAME_STYLES = {
  idle:      "border-white/70",
  detected:  "border-emerald-400",
  error:     "border-rose-400"
}

export default class extends Controller {
  static targets = [
    "video", "canvas", "frame", "overlay", "overlayText", "startButton", "stopButton",
    "status", "result", "resultTitle", "resultName", "resultDetail", "presentCount", "manualInput"
  ]
  static values = {
    scanUrl: String,
    presentCount: Number,
    cooldown: { type: Number, default: 2500 } // ms before the same code is submitted again
  }

  connect() {
    this.processing = false
    this.lastPayload = null
    this.lastPayloadAt = 0
    this.detector = ("BarcodeDetector" in window) ? new window.BarcodeDetector({ formats: ["qr_code"] }) : null
    this.handleVisibility = this.handleVisibility.bind(this)
    document.addEventListener("visibilitychange", this.handleVisibility)
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.handleVisibility)
    this.stop()
  }

  // ---- Camera lifecycle -------------------------------------------------

  async start() {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      this.showOverlay("This browser does not support camera access. Use the manual entry below.")
      return
    }
    if (!window.isSecureContext) {
      this.showOverlay("Camera access requires a secure (HTTPS) connection.")
      return
    }

    this.setStatus("Requesting camera permission…")
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: "environment" }, width: { ideal: 1280 }, height: { ideal: 720 } },
        audio: false
      })
    } catch (error) {
      this.handleCameraError(error)
      return
    }

    this.videoTarget.srcObject = this.stream
    try {
      await this.videoTarget.play()
    } catch (_) { /* autoplay restrictions: the video still renders once playing */ }

    this.overlayTarget.hidden = true
    this.stopButtonTarget.hidden = false
    this.scanning = true
    this.setStatus(this.detector ? "Scanning… (native decoder)" : "Scanning…")
    this.scheduleFrame()
  }

  stop() {
    this.scanning = false
    if (this.frameHandle) {
      cancelAnimationFrame(this.frameHandle)
      clearTimeout(this.frameHandle)
      this.frameHandle = null
    }
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop())
      this.stream = null
    }
    if (this.hasVideoTarget) this.videoTarget.srcObject = null
    if (this.hasOverlayTarget) {
      this.overlayTarget.hidden = false
      this.overlayTextTarget.textContent = "Camera stopped. Start it again to continue scanning."
    }
    if (this.hasStopButtonTarget) this.stopButtonTarget.hidden = true
    this.setStatus("Camera off")
  }

  handleVisibility() {
    if (document.hidden && this.scanning) {
      this.stop()
      this.overlayTextTarget.textContent = "Camera paused while the app was in the background. Tap Start to resume."
    }
  }

  handleCameraError(error) {
    const name = error && error.name
    let message
    if (name === "NotAllowedError" || name === "SecurityError") {
      message = "Camera permission was denied. Enable camera access for this site in your browser settings, then reload and try again."
    } else if (name === "NotFoundError" || name === "OverconstrainedError") {
      message = "No camera was found on this device. Use the manual entry below."
    } else if (name === "NotReadableError") {
      message = "The camera is in use by another app. Close it and try again."
    } else {
      message = `Could not start the camera (${name || "unknown error"}).`
    }
    this.showOverlay(message)
    this.setStatus("Camera unavailable")
    this.renderResult("error", "Camera unavailable", message, "")
  }

  showOverlay(message) {
    this.overlayTarget.hidden = false
    this.overlayTextTarget.textContent = message
  }

  // ---- Frame loop -------------------------------------------------------

  scheduleFrame() {
    if (!this.scanning) return
    // Throttle decode work: ~10 fps is plenty for QR codes and keeps phones cool.
    this.frameHandle = setTimeout(() => {
      this.frameHandle = requestAnimationFrame(() => this.processFrame())
    }, 100)
  }

  async processFrame() {
    if (!this.scanning) return
    const video = this.videoTarget
    if (video.readyState < 2 || this.processing) {
      this.scheduleFrame()
      return
    }

    let payload = null
    try {
      payload = await this.decodeFrame(video)
    } catch (_) {
      payload = null
    }

    if (payload) {
      await this.handleDecoded(payload)
    }
    this.scheduleFrame()
  }

  async decodeFrame(video) {
    if (this.detector) {
      const codes = await this.detector.detect(video)
      return codes.length ? codes[0].rawValue : null
    }

    const canvas = this.canvasTarget
    const scale = Math.min(1, 640 / video.videoWidth)
    canvas.width = Math.floor(video.videoWidth * scale)
    canvas.height = Math.floor(video.videoHeight * scale)
    const ctx = canvas.getContext("2d", { willReadFrequently: true })
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height)
    const image = ctx.getImageData(0, 0, canvas.width, canvas.height)
    const code = jsQR(image.data, image.width, image.height, { inversionAttempts: "dontInvert" })
    return code ? code.data : null
  }

  // ---- Submission -------------------------------------------------------

  async handleDecoded(payload) {
    const now = Date.now()
    if (payload === this.lastPayload && now - this.lastPayloadAt < this.cooldownValue) {
      return // same code still in front of the camera
    }
    this.lastPayload = payload
    this.lastPayloadAt = now
    this.flashFrame("detected")
    await this.submit(payload)
  }

  async submitManual(event) {
    event.preventDefault()
    const value = this.manualInputTarget.value.trim()
    if (!value) return
    this.manualInputTarget.value = ""
    await this.submit(value)
  }

  async submit(payload) {
    if (this.processing) return
    this.processing = true
    this.setStatus("Sending scan…")

    try {
      const { payload: data, status } = await apiRequest(this.scanUrlValue, { method: "POST", body: { qr_token: payload } })
      this.renderScanResponse(data, status)
    } catch (error) {
      this.renderFailure(error)
    } finally {
      this.processing = false
      if (this.scanning) this.setStatus("Scanning…")
    }
  }

  renderScanResponse(data, status) {
    if (!data) {
      this.renderResult("error", "Unexpected response", `The server returned status ${status}.`, "")
      return
    }

    const attendee = data.attendee
    const name = attendee ? attendee.full_name : ""
    const ministry = attendee && attendee.ministry_label ? attendee.ministry_label : ""

    if (typeof data.present_count === "number") this.updatePresentCount(data.present_count)

    switch (data.status) {
      case "recorded":
        this.renderResult("recorded", "✓ Attendance recorded", name, `${ministry} · Scanned at ${data.attendance.scanned_at_label}`)
        this.feedback("success")
        break
      case "duplicate":
        this.renderResult("duplicate", "Already recorded", `${name} is already present.`, `${ministry} · First scanned at ${data.attendance.scanned_at_label}`)
        this.feedback("warning")
        break
      case "attendee_not_found":
        this.renderResult("error", "Attendee not found", "This QR code is not registered.", "")
        this.feedback("error")
        break
      case "attendee_inactive":
        this.renderResult("error", "Inactive attendee", name, data.message)
        this.feedback("error")
        break
      case "event_closed":
        this.renderResult("error", "Attendance closed", "This event is no longer accepting scans.", "")
        this.feedback("error")
        this.stop()
        break
      case "event_not_open":
        this.renderResult("error", "Event not open", data.message, "")
        this.feedback("error")
        break
      default: {
        const message = (data.error && data.error.message) || data.message || `Scan failed (${status}).`
        this.renderResult("error", "Scan failed", message, "")
        this.feedback("error")
      }
    }
  }

  renderFailure(error) {
    if (error instanceof ApiError) {
      if (error.code === "offline" || error.code === "network_error") {
        this.renderResult("error", "No connection", "The scan was NOT saved.", "Check the network and scan again once you are back online.")
      } else if (error.code === "unauthenticated") {
        this.renderResult("error", "Signed out", error.message, "")
        window.location.assign("/users/sign_in")
      } else {
        this.renderResult("error", "Scan failed", error.message, "")
      }
    } else {
      this.renderResult("error", "Scan failed", "An unexpected error occurred.", "")
    }
    this.feedback("error")
  }

  // ---- UI helpers -------------------------------------------------------

  renderResult(kind, title, name, detail) {
    const el = this.resultTarget
    Object.values(RESULT_STYLES).forEach((classes) => classes.split(" ").forEach((c) => el.classList.remove(c)))
    RESULT_STYLES[kind].split(" ").forEach((c) => el.classList.add(c))
    this.resultTitleTarget.textContent = title
    this.resultNameTarget.textContent = name
    this.resultDetailTarget.textContent = detail
    this.flashFrame(kind === "recorded" || kind === "duplicate" ? "detected" : (kind === "error" ? "error" : "idle"))
  }

  flashFrame(state) {
    if (!this.hasFrameTarget) return
    const el = this.frameTarget
    Object.values(FRAME_STYLES).forEach((c) => el.classList.remove(c))
    el.classList.add(FRAME_STYLES[state] || FRAME_STYLES.idle)
    clearTimeout(this.frameTimer)
    this.frameTimer = setTimeout(() => {
      Object.values(FRAME_STYLES).forEach((c) => el.classList.remove(c))
      el.classList.add(FRAME_STYLES.idle)
    }, 800)
  }

  updatePresentCount(value) {
    this.presentCountValue = value
    if (this.hasPresentCountTarget) this.presentCountTarget.textContent = value
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }

  feedback(kind) {
    if (navigator.vibrate) {
      navigator.vibrate(kind === "success" ? 80 : (kind === "warning" ? [60, 60, 60] : [150, 80, 150]))
    }
  }
}
