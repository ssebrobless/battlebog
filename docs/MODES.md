# Game Modes

Battle Bog has one canonical competitive ruleset. Match modes choose who controls
the six team slots; they do not silently change the map, economy, objectives, or
victory rules.

```text
competitive_3v3
|-- Play vs AI
|   |-- Blue: one human swaps among three allied slots
|   |-- Inactive Blue slots: autonomous AI
|   `-- Red: three autonomous AI slots
|-- All Bots
|   `-- Six autonomous AI slots for seeded simulation and balance work
`-- Future PvP
    `-- Deferred; reuses the same rules with network controllers
```

## Canonical Competitive Rules

- Unified expanded map: 480 x 170 design units.
- Three creature slots per team.
- Two lane huts per team.
- Three lane minions per surviving hut every 20 seconds.
- Hunger drains from full to empty in 105 seconds before modifiers.
- Ecology, harvesting, deposits, breeding, side bosses, center bosses, and
  visibility are part of the same match loop.
- Each creature slot starts with three stocks.
- Team stock exhaustion is the target victory policy.
- Cores remain visible habitat structures but become non-targetable when the
  stable six-slot stock lifecycle is enabled.

## Play vs AI

The current `1v1` string is a temporary compatibility name for Play vs AI.

- The player selects three unique playable creatures.
- Slot 1 starts under human control.
- `1`, `2`, and `3` transfer control among living allied slots.
- Position, health, hunger, cooldowns, stocks, and objective state remain on the
  creature when control changes.
- The previously controlled creature immediately returns to autonomous AI.
- Inactive allies forage, fight, defend, retreat, and participate in objectives
  through the same legal-information actor brain as enemy bots.
- A deterministic team director assigns bounded follow, aggro, defend, contest,
  claim, boss-fight, and lane-pressure roles without replacing creature-specific
  combat hooks or exposing hidden enemy state.
- Inactive allies may return, deposit, and breed autonomously. The currently
  controlled creature still requires explicit player deposit input.

## Legacy 3v3 Entry

The current `3v3` entry is a temporary local compatibility topology: one human
controls one Blue creature, two Blue allies are bots, and all three Red creatures
are bots. It now uses the same competitive map pressure and timing as Play vs AI.
It is not multiplayer and must not be treated as the future network topology.

## All Bots

`All Bots` is an executable headless simulation topology, not a player-facing
menu mode. It requires exact three-creature rosters for both teams and an
explicit nonnegative seed, fails closed on invalid requests, routes no local
gameplay input, and writes stable roster/slot/seed telemetry for balance work.
It uses the same canonical rules as Play vs AI.

## Hero Lab

Hero Lab is a separate practice request rather than a competitive rules variant.
It currently uses the unified map and a closer learning camera, with one selected
creature against one rival bot. Its 18-second practice wave remains presentation
and training-specific until Hero Lab receives a dedicated practice contract.

## Migration Boundary

The canonical rules snapshot, six stable competitive slots, atomic controller
routing, stock victory, non-targetable competitive cores, the shared autonomous
ecology/combat layer, deterministic team coordination, natural opponent
forage/deposit/breeding, side-boss participation, immutable match completion,
results presentation, and Play vs AI menu/HUD naming are implemented and covered
by deterministic runtime checks. Simulation balance, human playtest tuning, and
visual production remain. Multiplayer stays deferred until gameplay and
presentation are complete.
