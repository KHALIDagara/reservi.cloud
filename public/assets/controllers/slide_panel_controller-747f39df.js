import { Controller } from "@hotwired/stimulus"

// Slide panel controller for the conversation tools panel.
// On mobile (< sm breakpoint), the panel slides in from the right.
// On desktop, it's always visible as a sticky sidebar.
export default class extends Controller {
  static targets = ["panel", "overlay", "trigger", "closeButton"]
  static classes = ["open", "closed"]

  connect() {
    this.desktopQuery = window.matchMedia("(min-width: 1024px)")
    this.configureForViewport = this.configureForViewport.bind(this)
    this.desktopQuery.addEventListener("change", this.configureForViewport)
    this.configureForViewport()
  }

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
    if (this.desktopQuery.matches) return
    this.panelTarget.classList.remove(...this.closedClasses)
    this.panelTarget.classList.add(...this.openClasses)
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove("hidden")
    }
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", "true")
    this.panelTarget.setAttribute("aria-hidden", "false")
    this.panelTarget.inert = false
    document.body.classList.add("overflow-hidden")
    if (this.hasCloseButtonTarget) this.closeButtonTarget.focus()
  }

  close() {
    if (this.desktopQuery.matches) return
    this.panelTarget.classList.remove(...this.openClasses)
    this.panelTarget.classList.add(...this.closedClasses)
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add("hidden")
    }
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", "false")
      this.triggerTarget.focus()
    }
    this.panelTarget.setAttribute("aria-hidden", "true")
    this.panelTarget.inert = true
    document.body.classList.remove("overflow-hidden")
  }

  disconnect() {
    this.desktopQuery?.removeEventListener("change", this.configureForViewport)
    document.body.classList.remove("overflow-hidden")
  }

  configureForViewport() {
    if (this.desktopQuery.matches) {
      this.panelTarget.classList.remove(...this.openClasses)
      this.panelTarget.classList.add(...this.closedClasses)
      this.panelTarget.setAttribute("role", "complementary")
      this.panelTarget.removeAttribute("aria-modal")
      this.panelTarget.removeAttribute("aria-hidden")
      this.panelTarget.inert = false
      this.overlayTarget.classList.add("hidden")
      if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", "false")
      document.body.classList.remove("overflow-hidden")
    } else {
      this.panelTarget.setAttribute("role", "dialog")
      this.panelTarget.setAttribute("aria-modal", "true")
      this.panelTarget.setAttribute("aria-hidden", this.hasOpenClass ? "false" : "true")
      this.panelTarget.inert = !this.hasOpenClass
      if (!this.hasOpenClass) this.overlayTarget.classList.add("hidden")
    }
  }

  trapFocus(event) {
    if (this.desktopQuery.matches || this.panelTarget.inert) return

    const focusable = this.panelTarget.querySelectorAll(
      'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
    )
    if (!focusable.length) return

    const first = focusable[0]
    const last = focusable[focusable.length - 1]
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }
}
