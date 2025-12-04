import { Controller } from "@hotwired/stimulus"

// Ensures viewport-dependent layouts (like the pet hub) stay within the visible screen
// even on mobile browsers that resize the visual viewport as chrome appears/disappears.
export default class extends Controller {
  connect() {
    this.boundUpdate = this.update.bind(this)
    window.addEventListener("resize", this.boundUpdate)

    if (window.visualViewport) {
      window.visualViewport.addEventListener("resize", this.boundUpdate)
      this.hasVisualViewportListener = true
    }

    this.update()
  }

  disconnect() {
    window.removeEventListener("resize", this.boundUpdate)

    if (this.hasVisualViewportListener && window.visualViewport) {
      window.visualViewport.removeEventListener("resize", this.boundUpdate)
    }
  }

  update() {
    const viewportHeight = this.currentViewportHeight()
    this.setCssVar("--viewport-height", `${viewportHeight}px`)

    const headerHeight = this.measureTargetHeight("header")
    const tabbarHeight = this.measureTargetHeight("tabbar")
    this.setCssVar("--app-shell-header-height", `${headerHeight}px`)
    this.setCssVar("--app-shell-tabbar-height", `${tabbarHeight}px`)

    const mainHeight = Math.max(viewportHeight - headerHeight - tabbarHeight, 0)
    this.setCssVar("--app-shell-main-height", `${mainHeight}px`)
  }

  currentViewportHeight() {
    if (window.visualViewport) {
      return Math.round(window.visualViewport.height)
    }

    return Math.round(window.innerHeight)
  }

  measureTargetHeight(name) {
    if (!this.hasTarget(name)) {
      return 0
    }

    const element = this[`${name}Target`]
    return element ? Math.round(element.getBoundingClientRect().height) : 0
  }

  setCssVar(name, value) {
    document.documentElement.style.setProperty(name, value)
  }
}
