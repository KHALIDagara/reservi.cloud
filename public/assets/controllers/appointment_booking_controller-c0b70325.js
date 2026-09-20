import { Controller } from "@hotwired/stimulus"

// Collaborative appointment booking controller.
//
// Manages the agent picker -> available days -> time slots -> book flow
// via AJAX calls to the appointments API.
export default class extends Controller {
  static targets = [
    "agentSelect", "loading", "error", "daysPanel",
    "daysList", "slotsPanel", "slotsList", "summary",
    "summaryDate", "summaryTime", "summaryAgent",
    "form", "scheduledAgentField", "startsAtField", "operationKeyField",
    "reschedulePanel", "rescheduleCurrent", "rescheduleDaysList",
    "rescheduleSlotsList", "rescheduleSummary"
  ]

  static values = {
    accountId: String,
    conversationId: String,
    roleKey: String,
    formAction: String,
    availabilityUrl: String
  }

  connect() {
    this._selectedDay = null
    this._selectedSlot = null
    this._selectedAgentName = null
    this._rescheduleAppointmentId = null
    this._rescheduleSelectedSlot = null
    this._rescheduleAgentId = null
  }

  // ── Agent picker ──────────────────────────────────────────────────

  agentChanged(event) {
    const agentId = event.target.value
    if (!agentId) {
      this.hideDays()
      return
    }
    this._selectedAgentName = event.target.options[event.target.selectedIndex]?.text
    this._rescheduleAgentId = agentId
    this.loadAvailability(agentId)
  }

  // ── Availability loading ───────────────────────────────────────────

  loadAvailability(agentId, date = null, excludeAppointmentId = null) {
    this.showLoading()
    this.hideDays()
    this.hideSummary()
    this.hideError()

    const url = new URL(this.availabilityUrlValue, window.location.origin)
    url.searchParams.set("agent_id", agentId)
    url.searchParams.set("duration_minutes", "60")
    if (date) url.searchParams.set("date", date)
    if (excludeAppointmentId) url.searchParams.set("exclude_appointment_id", excludeAppointmentId)

    fetch(url)
      .then(response => {
        if (!response.ok) throw new Error("Failed to load availability")
        return response.json()
      })
      .then(data => {
        this.hideLoading()
        if (data.error) {
          this.showError(data.error)
          return
        }

        // If loading for date, populate slots
        if (date) {
          this.populateSlots(data.available_slots, data.available_days)
        } else {
          this.populateDays(data.available_days)
        }
      })
      .catch(err => {
        this.hideLoading()
        this.showError(err.message || "Could not load availability")
      })
  }

  // ── Days ───────────────────────────────────────────────────────────

  populateDays(availableDays) {
    if (!availableDays || availableDays.length === 0) {
      this.showError("No available days found for this agent.")
      return
    }

    this.daysPanelTarget.classList.remove("hidden")
    this.daysListTarget.innerHTML = ""

    availableDays.forEach(dateStr => {
      const day = new Date(dateStr + "T00:00:00")
      const label = day.toLocaleDateString("en-US", {
        weekday: "short", month: "short", day: "numeric"
      })

      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "min-h-9 rounded-lg border border-slate-200 bg-white px-3 text-xs font-semibold text-slate-700 hover:border-indigo-300 hover:text-indigo-700"
      btn.textContent = label
      btn.addEventListener("click", () => {
        this.selectDay(dateStr, btn)
      })
      this.daysListTarget.appendChild(btn)
    })
  }

  selectDay(dateStr, button) {
    // Highlight the selected day button
    this.daysListTarget.querySelectorAll("button").forEach(b => {
      b.classList.remove("border-indigo-600", "bg-indigo-50", "text-indigo-700")
    })
    button.classList.add("border-indigo-600", "bg-indigo-50", "text-indigo-700")

    this._selectedDay = dateStr
    this.loadAvailability(this.agentSelectTarget.value, dateStr,
      this._rescheduleAppointmentId || null)
  }

  // ── Slots ──────────────────────────────────────────────────────────

  populateSlots(availableSlots) {
    this.slotsPanelTarget.classList.remove("hidden")
    this.slotsListTarget.innerHTML = ""
    this.hideSummary()

    if (!availableSlots || availableSlots.length === 0) {
      const p = document.createElement("p")
      p.className = "text-xs text-slate-400"
      p.textContent = "No available slots for this date."
      this.slotsListTarget.appendChild(p)
      return
    }

    availableSlots.forEach(slotIso => {
      const slotTime = new Date(slotIso)
      const label = slotTime.toLocaleTimeString("en-US", {
        hour: "2-digit", minute: "2-digit", hour12: false
      })

      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "min-h-9 rounded-lg border border-slate-200 bg-white px-3 text-xs font-semibold text-slate-700 hover:border-emerald-300 hover:text-emerald-700"
      btn.textContent = label
      btn.addEventListener("click", () => {
        this.selectSlot(slotIso, label, btn)
      })
      this.slotsListTarget.appendChild(btn)
    })
  }

  selectSlot(slotIso, label, button) {
    // Highlight the selected slot
    this.slotsListTarget.querySelectorAll("button").forEach(b => {
      b.classList.remove("border-emerald-600", "bg-emerald-50", "text-emerald-700")
    })
    button.classList.add("border-emerald-600", "bg-emerald-50", "text-emerald-700")

    this._selectedSlot = slotIso
    this._rescheduleSelectedSlot = slotIso
    this.showBookingSummary(slotIso, label)
  }

  // ── Booking summary ────────────────────────────────────────────────

  showBookingSummary(slotIso, timeLabel) {
    const day = new Date(this._selectedDay + "T00:00:00")
    this.summaryDateTarget.textContent = day.toLocaleDateString("en-US", {
      weekday: "long", month: "long", day: "numeric"
    })
    this.summaryTimeTarget.textContent = timeLabel
    this.summaryTarget.classList.remove("hidden")

    // Fill hidden form values
    this.scheduledAgentFieldTarget.value = this.agentSelectTarget.value
    this.startsAtFieldTarget.value = slotIso
    this.operationKeyFieldTarget.value = this.generateOperationKey()
    this.summaryAgentTarget.textContent = this._selectedAgentName
  }

  // ── Submit booking ─────────────────────────────────────────────────

  submitBooking() {
    if (!this._selectedSlot) return
    this.formTarget.submit()
  }

  // ── Reschedule ─────────────────────────────────────────────────────

  openReschedule(event) {
    const appointmentId = event.params.appointmentId
    this._rescheduleAppointmentId = appointmentId
    this.reschedulePanelTarget.classList.remove("hidden")
    this.daysPanelTarget.classList.add("hidden")

    // Show current appointment info
    const currentEl = this.rescheduleCurrentTarget
    const slotRow = event.target.closest("[data-appointment-booking-target]")
    if (slotRow) {
      const info = slotRow.querySelector("p").textContent
      currentEl.textContent = info
    }

    // Load availability for the currently selected agent (same agent by default)
    // Re-use the appointment's scheduled agent
    this.loadAvailability(this.agentSelectTarget.value, null, appointmentId)
  }

  submitReschedule() {
    if (!this._rescheduleSelectedSlot || !this._rescheduleAppointmentId) return

    const form = document.createElement("form")
    form.method = "POST"
    form.action = `/a/${this.accountIdValue}/appointments/${this._rescheduleAppointmentId}/reschedule`

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    if (csrfToken) {
      const csrfInput = document.createElement("input")
      csrfInput.type = "hidden"
      csrfInput.name = "authenticity_token"
      csrfInput.value = csrfToken
      form.appendChild(csrfInput)
    }

    const startsAtInput = document.createElement("input")
    startsAtInput.type = "hidden"
    startsAtInput.name = "starts_at"
    startsAtInput.value = this._rescheduleSelectedSlot
    form.appendChild(startsAtInput)

    const durationInput = document.createElement("input")
    durationInput.type = "hidden"
    durationInput.name = "duration_minutes"
    durationInput.value = "60"
    form.appendChild(durationInput)

    document.body.appendChild(form)
    form.submit()
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  showLoading() {
    this.loadingTarget.classList.remove("hidden")
  }

  hideLoading() {
    this.loadingTarget.classList.add("hidden")
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  hideError() {
    this.errorTarget.classList.add("hidden")
  }

  hideDays() {
    this.daysPanelTarget.classList.add("hidden")
    this.slotsPanelTarget.classList.add("hidden")
  }

  hideSummary() {
    this.summaryTarget.classList.add("hidden")
  }

  generateOperationKey() {
    const randomPart = Math.random().toString(36).substring(2, 10)
    return `${this.conversationIdValue}-${this.roleKeyValue}-${Date.now()}-${randomPart}`
  }
}