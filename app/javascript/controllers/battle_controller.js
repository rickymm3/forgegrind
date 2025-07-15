import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["playerHp", "enemyHp", "checkbox", "abilityButton"]
  static values  = {
    sessionId:            Number,
    enemyIndex:           Number,
    playerAttackInterval: Number,
    enemyAttackInterval:  Number,
    attackPerPoint:       Number,
    defensePerPoint:      Number,
    hpPerPoint:           Number,
    maxPets:              Number
  }

  connect() {
    this.startTime = performance.now()
    this.events    = []

    this.cooldownEndTimes = {}
    this.abilityButtonTargets.forEach(btn => {
      const id        = btn.dataset.battleAbilityIdValue
      const nextAtIso = btn.dataset.battleNextAvailableAtValue
      if (nextAtIso) this.cooldownEndTimes[id] = Date.parse(nextAtIso)
    })

    this._startTimers()
    this.cooldownTimer = setInterval(() => this._updateCooldowns(), 500)
  }

  disconnect() {
    this._stopTimers()
    clearInterval(this.cooldownTimer)
  }

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
    this.events.push({ at: performance.now() - this.startTime, type: "manual_attack" })
    this._checkEnd()
  }

  useAbility(event) {
    event.preventDefault()
    const btn      = event.currentTarget
    const id       = btn.dataset.battleAbilityIdValue
    const cooldown = parseInt(btn.dataset.battleCooldownValue, 10)

    this.events.push({ at: performance.now() - this.startTime, type: "ability", ability_id: id })
    this.cooldownEndTimes[id] = Date.now() + cooldown * 1000
    this._updateButton(id, btn)
    this._checkEnd()
  }

  _startTimers() {
    this.playerTimer = setInterval(
      () => this._localPlayerHit(),
      this.playerAttackIntervalValue * 1000
    )
    this.enemyTimer = setInterval(
      () => this._localEnemyHit(),
      this.enemyAttackIntervalValue * 1000
    )
  }

  _stopTimers() {
    clearInterval(this.playerTimer)
    clearInterval(this.enemyTimer)
  }

  _localPlayerHit() {
    this.events.push({ at: performance.now() - this.startTime, type: "player_tick" })
    const cur = parseInt(this.enemyHpTarget.textContent, 10)
    this.enemyHpTarget.textContent = Math.max(cur - this.attackPerPointValue, 0)
    this._checkEnd()
  }

  _localEnemyHit() {
    this.events.push({ at: performance.now() - this.startTime, type: "enemy_tick" })
    const cur = parseInt(this.playerHpTarget.textContent, 10)
    this.playerHpTarget.textContent = Math.max(cur - this.defensePerPointValue, 0)
    this._checkEnd()
  }

  _updateCooldowns() {
    const now = Date.now()
    Object.entries(this.cooldownEndTimes).forEach(([id, end]) => {
      const btn = this.abilityButtonTargets.find(
        b => b.dataset.battleAbilityIdValue === id
      )
      if (!btn) return
      const rem = Math.ceil((end - now) / 1000)
      if (rem > 0) {
        btn.disabled    = true
        btn.textContent = `${btn.dataset.battleAbilityNameValue} (${rem}s)`
      } else {
        delete this.cooldownEndTimes[id]
        btn.disabled    = false
        btn.textContent = btn.dataset.battleAbilityNameValue
      }
    })
  }

  _updateButton(id, btn) {
    const now = Date.now()
    const rem = Math.ceil((this.cooldownEndTimes[id] - now) / 1000)
    btn.disabled    = rem > 0
    btn.textContent = rem > 0
      ? `${btn.dataset.battleAbilityNameValue} (${rem}s)`
      : btn.dataset.battleAbilityNameValue
  }

  // ---- END-OF-BATTLE CHECK & FINAL POST ----
  _checkEnd() {
    const playerHp = parseInt(this.playerHpTarget.textContent, 10)
    const enemyHp  = parseInt(this.enemyHpTarget.textContent, 10)
    if (playerHp <= 0 || enemyHp <= 0) {
      this._stopTimers()
      clearInterval(this.cooldownTimer)
      // Prevent double submission
      if (this._ended) return
      this._ended = true
      // Choose outcome
      const status = enemyHp <= 0 && playerHp > 0 ? "won"
                  : playerHp <= 0 ? "lost"
                  : "lost"
      this._finishBattle(status)
    }
  }

  _finishBattle(status) {
    fetch(`/battle_sessions/${this.sessionIdValue}/complete`, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        events:         this.events,
        claimed_status: status
      })
    }).then(response => {
      if (!response.ok) {
        alert("Server did not accept the battle result. Try again or reload.")
      } else {
        // Optionally redirect or show trophy modal here
        window.location.reload() // crude, but you can replace with Turbo redirect/modal
      }
    })
  }
}
