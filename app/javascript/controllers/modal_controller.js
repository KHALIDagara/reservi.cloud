import { Controller } from "@hotwired/stimulus"

// Simple modal dialog controller for conversation work modals
// (field editing, catalog selection, appointment booking).
//
// Opens/closes via Turbo Frame navigation events.
// The frame content is rendered server-side; this controller
// only manages the dialog chrome (backdrop, focus, escape).
export default class extends Controller {
  static targets = ["backdrop", "panel"]
  static values = { open: { type: Boolean, default: false } }

  connect() {
    // Listen for turbo:frame-load on the modal frame
    this.boundOnFrameLoad = this.onFrameLoad.bind(this)
    document.addEventListener("turbo:frame-load", this.boundOnFrameLoad)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.boundOnFrameLoad)
    this.close()
  }

  onFrameLoad(event) {
    if (event.target.id === "conversation_modal" &&
        event.target.innerHTML.trim().length > 0) {
      this.open()
    }
  }

  open() {
    this.element.classList.remove("hidden")
    this.element.setAttribute("aria-hidden", "false")
    this.openValue = true
    document.body.classList.add("overflow-hidden")

    // Focus the panel for accessibility
    if (this.hasPanelTarget) {
      this.panelTarget.focus()
    }
  }

  close() {
    this.element.classList.add("hidden")
    this.element.setAttribute("aria-hidden", "true")
    this.openValue = false
    document.body.classList.remove("overflow-hidden")

    // Clear frame content so re-opening works
    const frame = document.getElementById("conversation_modal")
    if (frame) frame.innerHTML = ""
  }

  closeOnBackdrop(event) {
    if (event.target === this.backdropTarget) {
      this.close()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}