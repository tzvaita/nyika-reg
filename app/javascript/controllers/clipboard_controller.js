import { Controller } from "@hotwired/stimulus"

// Tap to copy the approved receiving account, so a resident can paste it
// straight into EcoCash rather than copying digits by hand off a screen.
//
// This is the practical end of the brief's "payment confusion" risk: the fewer
// digits someone retypes, the fewer payments go to the wrong place. The number
// stays visible and selectable, so nothing is lost without JavaScript — the
// button hides itself if the browser has no clipboard API.
export default class extends Controller {
  static targets = ["source", "button"]

  connect() {
    if (!navigator.clipboard && this.hasButtonTarget) this.buttonTarget.hidden = true
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.textContent.trim())
      this.flash("Copied")
    } catch {
      this.flash("Press and hold to copy")
    }
  }

  flash(message) {
    const button = this.buttonTarget
    const original = button.textContent
    button.textContent = message
    setTimeout(() => { button.textContent = original }, 1800)
  }
}
