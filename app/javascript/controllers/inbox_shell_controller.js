import { Controller } from "@hotwired/stimulus"

// Inbox workspace mobile shell controller.
//
// On phones (<768px): shows the conversation list by default.
// When a conversation is selected (conversation_workspace frame loads
// non-empty content), hides the list and shows the conversation detail.
// A "back to list" button in the conversation header returns to the list.
//
// On desktop (>=768px): shows both columns via CSS (md: prefix).
export default class extends Controller {
  static targets = ["list", "detail"]

  connect() {
    document.addEventListener("turbo:frame-load", this.handleFrameLoad.bind(this))
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.handleFrameLoad.bind(this))
  }

  handleFrameLoad(event) {
    if (event.target.id !== "conversation_workspace") return

    // Check if the loaded frame has real content (not just the placeholder)
    const hasContent = event.target.querySelector(".conversation-header") ||
                       event.target.textContent.trim().length > 0

    if (hasContent && window.innerWidth < 768) {
      this.showDetail()
    }
  }

  showDetail() {
    if (this.hasListTarget) this.listTarget.classList.add("hidden")
    if (this.hasDetailTarget) this.detailTarget.classList.remove("hidden", "md:flex")
  }

  showList() {
    if (this.hasListTarget) this.listTarget.classList.remove("hidden")
    if (this.hasDetailTarget) this.detailTarget.classList.add("hidden")
  }
}