// app/javascript/controllers/countdown_controller.js

import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Expose Turbo globally so renderStreamMessage works
window.Turbo = Turbo

export default class extends Controller {
  static values = {
    seconds: Number,
    total: Number,
    checkpointUrl: String,
    segmentIndex: Number,
    elapsed: Number,
    encounterUrl: String,
    nextEncounterOffset: Number,
    activeEncounter: Boolean,
    segmentTotal: Number,
    segmentElapsed: Number,
    endAt: String,
    totalEdges: Number,
    completedEdges: Number,
    activeEdgeFraction: Number
  }
  static targets = ["output", "progress", "activeProgress", "barFill"]

  connect() {
    const totalFromDataset = this.hasTotalValue ? Number(this.totalValue || 0) : 0
    const elapsedFromDataset = this.hasElapsedValue ? Number(this.elapsedValue || 0) : 0
    const segmentTotalFromDataset = this.hasSegmentTotalValue ? Number(this.segmentTotalValue || 0) : 0
    const segmentElapsedFromDataset = this.hasSegmentElapsedValue ? Number(this.segmentElapsedValue || 0) : 0
    const endAtMs = this.hasEndAtValue ? Date.parse(this.endAtValue) : NaN
    const nowMs = Date.now()
    const initialSeconds = this.resolveInitialSeconds({
      providedSeconds: Number(this.secondsValue || 0),
      segmentTotalSeconds: segmentTotalFromDataset,
      segmentElapsedSeconds: segmentElapsedFromDataset,
      totalSeconds: totalFromDataset,
      elapsedSeconds: elapsedFromDataset,
      endAtMs,
      referenceNowMs: nowMs
    })

    this.totalDuration = totalFromDataset > 0 ? totalFromDataset : initialSeconds
    this.elapsedBase = elapsedFromDataset > 0 ? elapsedFromDataset : Math.max(this.totalDuration - initialSeconds, 0)
    this.segmentTotalSeconds = segmentTotalFromDataset > 0 ? segmentTotalFromDataset : 0
    this.segmentElapsedBase = Math.max(0, Math.min(segmentElapsedFromDataset, this.segmentTotalSeconds))
    this.initialRemaining = initialSeconds
    this.secondsValue = this.initialRemaining

    if (Number.isFinite(endAtMs)) {
      this.endTime = endAtMs
    } else {
      this.endTime = nowMs + this.initialRemaining * 1000
    }

    this.userExplorationId = this.element.dataset.userExplorationId
    this.userEggId = this.element.dataset.userEggId
    this.userPetId = this.element.dataset.userPetId
    this.encounterTriggered = this.hasActiveEncounterValue ? this.activeEncounterValue : false

    this.refreshDisplay(this.initialRemaining)

    if (this.initialRemaining <= 0) {
      this.handleSegmentCompletion()
      return
    }

    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    this.clearTimer()
  }

  tick() {
    const now = Date.now()
    const remaining = Math.max(0, Math.floor((this.endTime - now) / 1000))
    this.refreshDisplay(remaining)

    if (remaining <= 0) {
      this.clearTimer()
      this.handleSegmentCompletion()
    }
  }

  handleSegmentCompletion() {
    if (this.hasCheckpointUrlValue && this.checkpointUrlValue) {
      this.notifyCheckpointReached()
    } else {
      this.handleLegacyCompletion()
    }
  }

  notifyCheckpointReached() {
    const formData = new FormData()
    if (this.hasSegmentIndexValue) {
      formData.append("segment_index", this.segmentIndexValue)
    }

    fetch(this.checkpointUrlValue, {
      method: "POST",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      credentials: "same-origin",
      body: formData
    })
      .then(response => {
        if (!response.ok) {
          throw new Error(`checkpoint failed: ${response.status}`)
        }
        return response.text()
      })
      .then(html => {
        Turbo.renderStreamMessage(html)
      })
      .catch(err => {
        console.error("checkpoint notify failed:", err)
        // fall back to legacy completion to avoid getting stuck
        this.handleLegacyCompletion()
      })
  }

  handleLegacyCompletion() {
    if (this.userExplorationId) {
      fetch(`/user_explorations/${this.userExplorationId}/ready`, {
        method: "GET",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        credentials: "same-origin"
      })
        .then(response => response.text())
        .then(html => Turbo.renderStreamMessage(html))
        .catch(err => console.error("ready_expedition failed:", err))
    } else if (this.userEggId) {
      fetch(`/user_eggs/${this.userEggId}/mark_ready`, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        credentials: "same-origin"
      })
        .then(response => response.text())
        .then(html => Turbo.renderStreamMessage(html))
        .catch(err => console.error("ready_egg failed:", err))
    } else if (this.userPetId) {
      fetch(`/user_pets/${this.userPetId}/energy_tick`, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        credentials: "same-origin"
      })
        .then(response => response.text())
        .then(html => {
          Turbo.renderStreamMessage(html)
          this.clearTimer()
          this.initialRemaining = this.secondsValue
          this.endTime = Date.now() + this.secondsValue * 1000
          this.timer = setInterval(() => this.tick(), 1000)
        })
        .catch(err => console.error("energy_tick failed:", err))
    } else {
      console.warn("Countdown finished but no target ID found.")
    }
  }

  refreshDisplay(remaining) {
    const elapsedDelta = Math.max(0, this.initialRemaining - remaining)
    const totalElapsed = this.elapsedBase + elapsedDelta
    let totalEdges = null
    let completedEdges = 0
    let segmentFraction = 0

    if (this.hasOutputTarget) {
      this.outputTarget.textContent = this.formatTime(remaining)
    }

    if (this.hasProgressTarget) {
      if (this.hasTotalEdgesValue && Number(this.totalEdgesValue || 0) > 0) {
        totalEdges = Math.max(1, Number(this.totalEdgesValue || 0))
        completedEdges = Math.max(
          0,
          Math.min(Number(this.hasCompletedEdgesValue ? this.completedEdgesValue || 0 : 0), totalEdges)
        )
        const completedPercent = (completedEdges / totalEdges) * 100
        this.progressTarget.style.width = `${completedPercent.toFixed(1)}%`
      } else if (this.totalDuration > 0) {
        const progressRatio = Math.max(0, Math.min(1, totalElapsed / this.totalDuration))
        this.progressTarget.style.width = `${(progressRatio * 100).toFixed(1)}%`
      }
    }

    if (this.hasTotalEdgesValue && Number(this.totalEdgesValue || 0) > 0) {
      totalEdges = totalEdges || Math.max(1, Number(this.totalEdgesValue || 0))
      completedEdges = completedEdges || Math.max(
        0,
        Math.min(Number(this.hasCompletedEdgesValue ? this.completedEdgesValue || 0 : 0), totalEdges)
      )

      if (this.segmentTotalSeconds > 0) {
        const progressed = Math.min(this.segmentTotalSeconds, this.segmentElapsedBase + elapsedDelta)
        segmentFraction = Math.max(0, Math.min(1, progressed / this.segmentTotalSeconds))
      } else if (this.hasActiveEdgeFractionValue) {
        segmentFraction = Math.max(0, Math.min(1, Number(this.activeEdgeFractionValue || 0)))
      }
    }

    if (this.hasActiveProgressTarget && totalEdges) {
      const completedPercent = (completedEdges / totalEdges) * 100
      const segmentPercent = Math.min(100, (segmentFraction / totalEdges) * 100)
      const cappedSegmentPercent = Math.min(100 - completedPercent, segmentPercent)
      this.activeProgressTarget.style.left = `${completedPercent.toFixed(1)}%`
      this.activeProgressTarget.style.width = `${cappedSegmentPercent.toFixed(1)}%`
    }

    if (this.hasBarFillTarget && totalEdges) {
      this.barFillTargets.forEach((bar) => {
        const edgeIndex = Number(bar.dataset.edgeIndex || 0)
        let width = 0
        if (edgeIndex < completedEdges) {
          width = 100
        } else if (edgeIndex === completedEdges) {
          width = Math.min(100, segmentFraction * 100)
        }
        const state = width >= 99.5 ? "complete" : width > 0 ? "active" : "idle"
        bar.style.width = `${width.toFixed(1)}%`
        bar.classList.toggle("segment-timeline__bar-fill--complete", state === "complete")
        bar.classList.toggle("segment-timeline__bar-fill--active", state === "active")
        bar.classList.toggle("segment-timeline__bar-fill--idle", state === "idle")
      })
    }

    if (this.userExplorationId) {
      this.checkForEncounter(totalElapsed)
    }
  }

  resolveInitialSeconds({
    providedSeconds,
    segmentTotalSeconds,
    segmentElapsedSeconds,
    totalSeconds,
    elapsedSeconds,
    endAtMs,
    referenceNowMs
  }) {
    if (Number.isFinite(providedSeconds) && providedSeconds > 0) {
      return providedSeconds
    }

    if (Number.isFinite(endAtMs)) {
      const derivedFromEnd = Math.floor((endAtMs - referenceNowMs) / 1000)
      if (derivedFromEnd > 0) {
        return derivedFromEnd
      }
    }

    if (Number.isFinite(segmentTotalSeconds) && segmentTotalSeconds > 0) {
      const segmentElapsedSafe = Number.isFinite(segmentElapsedSeconds) ? Math.max(segmentElapsedSeconds, 0) : 0
      const derivedSegment = Math.max(segmentTotalSeconds - segmentElapsedSafe, 0)
      if (derivedSegment > 0) {
        return derivedSegment
      }
    }

    if (Number.isFinite(totalSeconds) && totalSeconds > 0) {
      const safeElapsed = Number.isFinite(elapsedSeconds) ? Math.max(elapsedSeconds, 0) : 0
      const derived = Math.max(totalSeconds - safeElapsed, 0)
      if (derived > 0) {
        return derived
      }
    }

    return 0
  }

  clearTimer() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  formatTime(seconds) {
    const m = Math.floor(seconds / 60)
    const s = seconds % 60
    return `${m}:${s.toString().padStart(2, "0")}`
  }

  checkForEncounter(totalElapsed) {
    if (!this.hasEncounterUrlValue || !this.encounterUrlValue) return
    if (!this.hasNextEncounterOffsetValue) return
    if (this.encounterTriggered) return

    const offset = Number(this.nextEncounterOffsetValue)
    if (Number.isNaN(offset) || offset < 0) return

    if (totalElapsed >= offset) {
      this.triggerEncounter()
    }
  }

  triggerEncounter() {
    this.encounterTriggered = true

    fetch(this.encounterUrlValue, {
      method: "POST",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      credentials: "same-origin"
    })
      .then(response => {
        if (!response.ok) {
          throw new Error(`encounter activation failed: ${response.status}`)
        }
        return response.text()
      })
      .then(html => {
        Turbo.renderStreamMessage(html)
      })
      .catch(err => {
        console.error(err)
        this.encounterTriggered = false
      })
  }
}
