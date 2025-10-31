# ForgeGrind — Project Brief (for Codex)

## Stack / Conventions
- Rails 8, Ruby 3.3.0, PostgreSQL, Turbo + Stimulus, Tailwind.
- Prefer `turbo_frame_tag` for replaceable blocks.
- Views:  HTML ERB
- Normalize core enums to tables (e.g., `rarities`, `currencies`).
- Avoid generators if controller exists; edit methods directly.

## High-Level Loop
- **Eggs → Pets → Evolutions**: pets provide multipliers, abilities; limited equip slots (3).
- **Rebirth** boosts long-term progression (meta currency / multipliers).

## Key Domains (models/relations)
- **User** has many **UserPets**, **UserEggs**, balances in **Currency**.
- **Pet**: base species; many evolutions; rarity separate (`rarities`).
- **UserPet**: instance state (equipped:boolean, level, learned_abilities, personality flags).
  - Equipped pets override base tick interval / bonuses.
- **Egg**/**UserEgg**: source of new pets; world- or shop-acquired.
- **Exploration/World/Zone** (new): time-gated runs that may require specific **pet abilities** (e.g., foraging, fire affinity) to unlock special drops; zones can roll traits on first clear and reappear randomly.

## Controllers / Views (not exhaustive)
- **AdoptController#index**: shop-like list of eggs, disabled if unaffordable; inventory summary at top (icons + counts).
- **Nursery**: shows user eggs and hatching progress.
- **Pets UI**: 3-slot equip widget; modal to pick/unequip; compact 50×50 list + stat block.
- Use Turbo Streams for partial updates; pre-render DOM, toggle visibility (no JS asset fetching at runtime).

## Abilities & Evolutions
- `UserPet` tracks learned abilities; default backfilled ability on create.
- Evolutions branch by level + personality + happiness windows; missed windows can route to alternate forms.
- Abilities gate exploration drops/paths; some zones demand specific ability presence in the equipped set.

## Data / Jobs
- Tick job accrues energy; multipliers from equipped pets and upgrades.
- Prefer YAML/seeded tables for static content (rarities, ability refs, drop tables).

## UI Rules of Thumb
- Cards: rounded-2xl, soft shadow, gradient overlays for zone art.
- Inventory and affordability states must update after actions (Turbo Stream responses).
- Favor `turbo_frame_tag` keys over DOM ids for replaceable regions.

## Testing / Safety
- Guard controller actions for currency spend; server-side disable + afford checks.
- When evolving or granting drops, transact with explicit locks or optimistic checks.

## What to Ignore (noise)
- `node_modules/`, build outputs, logs, caches, coverage, vendor, large images.
- Spec scaffolds unless explicitly in scope.

## When Asking Codex to Change Things
- **Scope** first: list exact files/folders. Do not scan entire repo.
- Use/consult `docs/codex_brief.md` for context. Do not restate it.
- Output: minimal diffs or whole-file replacements per file, no extra commentary.
- If UI: keep Tailwind + Turbo patterns consistent; no new frameworks.
- Do NOT write tests