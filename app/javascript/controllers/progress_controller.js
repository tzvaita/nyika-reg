import { Controller } from "@hotwired/stimulus"

// Fills a campaign's progress bar and counts the raised figure up, once, when it
// scrolls into view.
//
// This page's whole argument is live evidence rather than a claim, so the number
// arriving earns a moment of motion. The bar is rendered at its correct width
// server-side, so with JavaScript off it simply shows the right proportion
// without animating.
export default class extends Controller {
  static targets = ["bar", "amount"]
  static values = { percent: Number, amount: Number, prefix: String }

  connect() {
    if (this.prefersReducedMotion) return

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return
        this.animate()
        this.observer.disconnect()
      })
    }, { threshold: 0.25 })

    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  get prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }

  animate() {
    if (this.hasBarTarget) {
      this.barTarget.style.width = "0%"
      requestAnimationFrame(() => {
        this.barTarget.style.transition = "width 900ms ease-out"
        this.barTarget.style.width = `${Math.min(this.percentValue, 100)}%`
      })
    }

    if (this.hasAmountTarget) this.countUp()
  }

  countUp() {
    const target = this.amountValue
    const duration = 900
    const start = performance.now()

    const step = (now) => {
      const progress = Math.min((now - start) / duration, 1)
      // Ease out, so it settles rather than stopping dead.
      const eased = 1 - Math.pow(1 - progress, 3)
      const value = Math.round(target * eased)
      this.amountTarget.textContent = `${this.prefixValue}${value.toLocaleString()}`
      if (progress < 1) requestAnimationFrame(step)
    }

    requestAnimationFrame(step)
  }
}
