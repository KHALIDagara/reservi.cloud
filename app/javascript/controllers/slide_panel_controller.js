import { Controller } from "@hotwired/stimulus"

// Slide panel controller for the conversation tools panel.
// On mobile (< sm breakpoint), the panel slides in from the right.
// On desktop, it's always visible as a sticky sidebar.
export default class extends Controller {
  static targets = ["panel", "overlay"]
  static classes = ["open", "closed"]

  toggle() {
    if (this.panelTarget.classList.contains(this.openClass)) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.panelTarget.classList.remove(this.closedClass)
    this.panelTarget.classList.add(this.openClass)
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("hidden")
    }
  }

  close() {
    this.panelTarget.classList.remove(this.openClass)
    this.panelTarget.classList.add(this.closedClass)
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("hidden")
    }
  }
}