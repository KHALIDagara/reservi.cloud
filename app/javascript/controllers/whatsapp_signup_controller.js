import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "status"]
  static values = {
    appId: String,
    configurationId: String,
    apiVersion: String,
    endpoint: String
  }

  connect() {
    this.authCode = null
    this.businessData = null
    this.handleMessage = this.handleMessage.bind(this)
    window.addEventListener("message", this.handleMessage)
  }

  disconnect() {
    window.removeEventListener("message", this.handleMessage)
  }

  async start() {
    this.setBusy(true, "Opening WhatsApp setup…")
    try {
      await this.loadFacebookSdk()
      const code = await this.login()
      this.authCode = code
      this.statusTarget.textContent = "Finishing your WhatsApp connection…"
      await this.completeIfReady()
    } catch (error) {
      this.showError(error.message || "WhatsApp setup could not be completed.")
    }
  }

  handleMessage(event) {
    let origin
    try {
      origin = new URL(event.origin)
    } catch {
      return
    }
    if (origin.protocol !== "https:" || (origin.hostname !== "facebook.com" && !origin.hostname.endsWith(".facebook.com"))) return

    let payload = event.data
    if (typeof payload === "string") {
      try { payload = JSON.parse(payload) } catch { return }
    }
    if (!payload || payload.type !== "WA_EMBEDDED_SIGNUP") return

    if (["FINISH", "FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING"].includes(payload.event)) {
      const data = payload.data || {}
      if (data.business_id && data.waba_id && data.phone_number_id) {
        this.businessData = data
        this.completeIfReady()
      }
    } else if (payload.event === "CANCEL") {
      this.showError("WhatsApp setup was cancelled.")
    } else if (payload.event === "error") {
      this.showError(payload.error_message || "WhatsApp reported a setup error.")
    }
  }

  async completeIfReady() {
    if (!this.authCode || !this.businessData || this.completing) return
    this.completing = true

    const response = await fetch(this.endpointValue, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
      },
      body: JSON.stringify({ code: this.authCode, ...this.businessData })
    })
    const result = await response.json()
    if (!response.ok) throw new Error(result.error || "WhatsApp connection failed.")

    window.location.assign(result.redirect_url)
  }

  loadFacebookSdk() {
    if (window.FB) {
      this.initializeFacebook()
      return Promise.resolve()
    }

    return new Promise((resolve, reject) => {
      window.fbAsyncInit = () => {
        this.initializeFacebook()
        resolve()
      }
      const script = document.createElement("script")
      script.src = "https://connect.facebook.net/en_US/sdk.js"
      script.async = true
      script.defer = true
      script.crossOrigin = "anonymous"
      script.onerror = () => reject(new Error("Could not load Meta's secure signup."))
      document.head.appendChild(script)
    })
  }

  initializeFacebook() {
    window.FB.init({
      appId: this.appIdValue,
      autoLogAppEvents: true,
      xfbml: false,
      version: this.apiVersionValue
    })
  }

  login() {
    return new Promise((resolve, reject) => {
      window.FB.login(response => {
        if (response.authResponse?.code) resolve(response.authResponse.code)
        else reject(new Error(response.error?.message || "WhatsApp login was cancelled."))
      }, {
        config_id: this.configurationIdValue,
        response_type: "code",
        override_default_response_type: true,
        extras: {
          setup: {},
          featureType: "whatsapp_business_app_onboarding",
          sessionInfoVersion: "3"
        }
      })
    })
  }

  setBusy(busy, message) {
    this.buttonTarget.disabled = busy
    this.buttonTarget.classList.toggle("opacity-60", busy)
    this.statusTarget.textContent = message
  }

  showError(message) {
    this.completing = false
    this.setBusy(false, message)
    this.statusTarget.classList.add("text-rose-600")
  }
}
