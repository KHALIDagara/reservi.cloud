import { Controller } from "@hotwired/stimulus"

// Manages selected-styling on conversation list rows.
// Listens to turbo:frame-load events on the conversation_workspace frame
// and updates the active row class without full list refreshes.
export default class extends Controller {
  static targets = ["row"]

  connect() {
    // Listen for frame loads from the workspace
    this.element.addEventListener("turbo:frame-load", this.handleFrameLoad.bind(this))

    // Highlight the initial selection from URL
    this.highlightFromId()
  }

  handleFrameLoad(event) {
    // The conversation_workspace frame loaded — extract conversation id
    const frame = event.target
    if (frame.id !== "conversation_workspace") return

    const url = new URL(event.detail?.fetchResponse?.location || frame.src || "", window.location.origin)
    const conversationId = this.extractConversationId(url.pathname)

    if (conversationId) {
      this.selectRow(conversationId)
    }
  }

  extractConversationId(pathname) {
    // Matches /a/:account_id/inboxes/:inbox_id/conversations/:id
    const match = pathname.match(/inboxes\/\d+\/conversations\/(\d+)/)
    return match ? match[1] : null
  }

  highlightFromId() {
    // Read the current selected_id from the first active row or URL
    const active = this.element.querySelector('[data-active="true"]')
    if (active) {
      const id = active.closest("li")?.id?.replace("conversation_", "")
      if (id) this.selectRow(id)
    }
  }

  selectRow(conversationId) {
    // Remove active class from all rows
    this.rowTargets.forEach((row) => {
      row.classList.remove("bg-indigo-50/70", "border-l-2", "border-l-indigo-600")
    })

    // Find and highlight the matching row
    const li = this.element.querySelector(`#conversation_${conversationId}`)
    if (li) {
      const link = li.querySelector("a")
      if (link) {
        link.classList.add("bg-indigo-50/70", "border-l-2", "border-l-indigo-600")
      }
    }
  }
}