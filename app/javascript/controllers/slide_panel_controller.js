import { Controller } from "@hotwired/stimulus"

// Slide panel controller for the conversation tools panel.
// On mobile (< sm breakpoint), the panel slides in from the right.
// On desktop, it's always visible as a sticky sidebar.
export default class extends Controller {
  static targets = ["panel", "overlay"]
  static classes = ["open", "closed"]

  toggle() {
    if (this.hasOpenClass) {
      this.close()
    } else {
      this.open()
    }
  }

  get hasOpenClass() {
    return this.openClass.split(/\s+/).some(cls => this.panelTarget.classList.contains(cls))
  }

  get closedClasses() {
    return this.closedClass.split(/\s+/)
  }

  get openClasses() {
    return this.openClass.split(/\s+/)
  }

  open() {
    this.panelTarget.classList.remove(...this.closedClasses)
    this.panelTarget.classList.add(...this.openClasses)
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("hidden")
    }
  }

  close() {
    this.panelTarget.classList.remove(...this.openClasses)
    this.panelTarget.classList.add(...this.closedClasses)
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("hidden")
    }
  }
}