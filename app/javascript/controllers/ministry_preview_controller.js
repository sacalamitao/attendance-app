import { Controller } from "@hotwired/stimulus"
import { apiRequest } from "api"

// Previews the ministry classification on the attendee form by asking the
// backend, so the rules live in exactly one place (MinistryClassifier).
export default class extends Controller {
  static targets = ["gender", "birthdate", "output"]
  static values = { url: String }

  update() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.fetchPreview(), 250)
  }

  async fetchPreview() {
    const gender = this.genderTarget.value
    const birthdate = this.birthdateTarget.value
    if (!gender || !birthdate) {
      this.outputTarget.innerHTML = '<span class="text-sm text-slate-500">Enter gender and birthdate to see the ministry.</span>'
      return
    }

    try {
      const params = new URLSearchParams({ gender, birthdate })
      const { payload } = await apiRequest(`${this.urlValue}?${params}`)
      if (payload && payload.ministry_label) {
        this.outputTarget.innerHTML = `<span class="inline-flex items-center rounded-full bg-indigo-100 px-3 py-1 text-base font-semibold text-indigo-800 ring-1 ring-inset ring-indigo-200">${payload.ministry_label}</span> <span class="text-sm text-slate-500">age ${payload.age}</span>`
      } else {
        const message = (payload && payload.error) || "Not classifiable."
        this.outputTarget.innerHTML = `<span class="text-sm text-rose-700">${message}</span>`
      }
    } catch (error) {
      this.outputTarget.innerHTML = '<span class="text-sm text-slate-500">Ministry will be calculated when you save.</span>'
    }
  }
}
