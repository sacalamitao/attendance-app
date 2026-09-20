// Small fetch wrapper for the same-origin JSON API. Sends the Rails CSRF token
// and normalizes network failures into a consistent error shape.

export class ApiError extends Error {
  constructor(code, message, status, payload) {
    super(message)
    this.code = code
    this.status = status
    this.payload = payload
  }
}

function csrfToken() {
  const meta = document.querySelector('meta[name="csrf-token"]')
  return meta ? meta.content : ""
}

export async function apiRequest(url, { method = "GET", body = null, signal = null } = {}) {
  if (typeof navigator !== "undefined" && navigator.onLine === false) {
    throw new ApiError("offline", "You are offline. The scan was not saved.", 0, null)
  }

  let response
  try {
    response = await fetch(url, {
      method,
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
        "X-Requested-With": "XMLHttpRequest"
      },
      credentials: "same-origin",
      body: body ? JSON.stringify(body) : null,
      signal
    })
  } catch (error) {
    throw new ApiError("network_error", "Network error. The request did not reach the server.", 0, null)
  }

  let payload = null
  try {
    payload = await response.json()
  } catch (_) {
    payload = null
  }

  if (response.status === 401) {
    throw new ApiError("unauthenticated", "Your session has expired. Please sign in again.", 401, payload)
  }

  return { ok: response.ok, status: response.status, payload }
}
