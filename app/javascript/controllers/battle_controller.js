// app/javascript/controllers/battle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["playerHp", "enemyHp", "checkbox", "abilityButton"]
  static values  = {
    sessionId:              Number,
    enemyIndex:             Number,
    lastSyncAt:             String,   // ISO8601

    playerAttackInterval:   Number,   // seconds
    enemyAttackInterval:    Number,   // seconds
    syncInterval:           Number,   // seconds

    attackPerPoint:         Number,
    defensePerPoint:        Number,
    hpPerPoint:             Number,

    maxPets:                Number
  }

  connect() {
    // 1) Event queues
    this.tickEvents      = []
    this.abilityEvents   = []
    this.manualAttacks   = []

    // 2) Cooldown tracking
    this.cooldownEndTimes = {}
    this.abilityButtonTargets.forEach(btn => {
      const id         = btn.dataset.battleAbilityIdValue
      const nextAtIso  = btn.dataset.battleNextAvailableAtValue
      if (nextAtIso) {
        this.cooldownEndTimes[id] = Date.parse(nextAtIso)
      }
    })

    // 3) Start loops
    this._startTimers()
    this.cooldownTimer = setInterval(() => this._updateCooldowns(), 500)
  }

  disconnect() {
    this._stopTimers()
    clearInterval(this.cooldownTimer)
  }

  // — User actions —

  togglePet(event) {
    this.selectedCount = event.currentTarget.checked
      ? (this.selectedCount || 0) + 1
      : this.selectedCount - 1

    this.checkboxTargets.forEach(cb => {
      if (!cb.checked) cb.disabled = this.selectedCount >= this.maxPetsValue
    })
  }

  attack(event) {
    event.preventDefault()
    this.manualAttacks.push(new Date().toISOString())
  }

  useAbility(event) {
    event.preventDefault()
    const btn       = event.currentTarget
    const id        = btn.dataset.battleAbilityIdValue
    const cooldown  = parseInt(btn.dataset.battleCooldownValue, 10)

    // record event
    this.abilityEvents.push({ ability_id: id, at: new Date().toISOString() })

    // start cooldown
    this.cooldownEndTimes[id] = Date.now() + cooldown * 1000
    this._updateButton(id, btn)
  }

  // — Core loops —

  _startTimers() {
    this.playerTimer = setInterval(
      () => this._localPlayerHit(),
      this.playerAttackIntervalValue * 1000
    )
    this.enemyTimer = setInterval(
      () => this._localEnemyHit(),
      this.enemyAttackIntervalValue * 1000
    )
    this.syncTimer = setInterval(
      () => this._syncWithServer(),
      this.syncIntervalValue * 1000
    )
  }

  _stopTimers() {
    clearInterval(this.playerTimer)
    clearInterval(this.enemyTimer)
    clearInterval(this.syncTimer)
  }

  _localPlayerHit() {
    this.tickEvents.push({ at: new Date().toISOString() })

    const current = parseInt(this.enemyHpTarget.textContent, 10)
    const next    = current - this.attackPerPointValue
    this.enemyHpTarget.textContent = Math.max(next, 0)
  }

  _localEnemyHit() {
    const current = parseInt(this.playerHpTarget.textContent, 10)
    const next    = current - this.defensePerPointValue
    this.playerHpTarget.textContent = Math.max(next, 0)
  }

  async _syncWithServer() {
    this._stopTimers()

    const payload = {
      last_sync_at:   this.lastSyncAtValue,
      tick_events:    this.tickEvents,
      ability_events: this.abilityEvents,
      manual_attacks: this.manualAttacks
    }

    const response = await fetch(
      `/battle_sessions/${this.sessionIdValue}/sync`,
      {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept":        "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify(payload)
      }
    )

    if (response.ok) {
      // clear queues
      this.tickEvents      = []
      this.abilityEvents   = []
      this.manualAttacks   = []

      // restart loops
      this._startTimers()
    } else {
      console.error("Battle sync failed:", response.status)
    }
  }

  // — Cooldown UI —

  _updateCooldowns() {
    const now = Date.now()
    Object.entries(this.cooldownEndTimes).forEach(([id, end]) => {
      const btn = this.abilityButtonTargets.find(el =>
        el.dataset.battleAbilityIdValue === id
      )
      if (!btn) return

      const rem = Math.ceil((end - now) / 1000)
      if (rem > 0) {
        btn.disabled = true
        btn.textContent = `${btn.dataset.battleAbilityNameValue} (${rem}s)`
      } else {
        delete this.cooldownEndTimes[id]
        btn.disabled = false
        btn.textContent = btn.dataset.battleAbilityNameValue
      }
    })
  }

  _updateButton(id, btn) {
    // force an immediate single cooldown update
    const now = Date.now()
    const rem = Math.ceil((this.cooldownEndTimes[id] - now) / 1000)
    btn.disabled = rem > 0
    btn.textContent = rem > 0
      ? `${btn.dataset.battleAbilityNameValue} (${rem}s)`
      : btn.dataset.battleAbilityNameValue
  }
}
