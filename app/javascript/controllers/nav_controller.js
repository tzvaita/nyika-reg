import { Controller } from "@hotwired/stimulus"

// Mobile menu toggle.
//
// The menu markup is visible by default so the site navigates with JavaScript
// off. This controller hides it on connect and toggles from there, which means
// no-JS gets a slightly longer page rather than no navigation at all.
export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.close()
  }

  toggle() {
    this.menuTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.menuTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.menuTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }
}
