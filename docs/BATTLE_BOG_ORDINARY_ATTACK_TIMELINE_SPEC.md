# Battle Bog Ordinary Attack Timeline Specification

Status: shared timeline, melee split, Creature ownership, suppression provenance
and Alligator migration implemented; later creature migrations open

Compiled: 2026-07-27

## State Machine

```text
InputFrame (player or bot)
          |
          v
request_primary_attack(payload)
          |
          v
IDLE -> STARTUP -> ACTIVE -> RECOVERY -> IDLE
          warning    resolve     hit / whiff / released / interrupted
                     exactly once
```

Locomotion continues independently and receives the current phase's movement
multiplier. Boss actors retain their separate major-attack framework. Snapping
Turtle retains its specialized windup until explicitly migrated.

## Timeline API

Location:

`scripts/sim/combat/attack_timeline.gd`

```gdscript
enum Phase { IDLE, STARTUP, ACTIVE, RECOVERY }
enum Outcome { NONE, HIT, WHIFF, RELEASED, INTERRUPTED }

func start(config, payload, strike_direction, simulation_tick, time_scale) -> bool
func advance(delta, simulation_tick: int, active_resolver: Callable) -> Array[Dictionary]
func interrupt(reason: String, simulation_tick: int, hard := false) -> Dictionary
func reset() -> void
func snapshot() -> Dictionary
func is_idle() -> bool
func movement_multiplier() -> float
func blocks_abilities() -> bool
func has_phase_tag(tag: String) -> bool
```

Snapshot:

```text
attack_phase
phase_t
attack_outcome
attack_sequence_id
attack_started_tick
attack_active_tick
strike_heading
payload
hit_count
hit_region
interruption_reason
```

`advance()` consumes overshoot deterministically, may cross multiple boundaries
in one large tick and invokes the active resolver exactly once per sequence.
The caller supplies the authoritative current simulation tick; the timeline
records that value when active begins rather than deriving tick identity from
delta size or call count.

Implemented coverage includes exact and overshot boundaries, tiny-delta
conservation, authoritative ticks, hit/whiff/released recovery, soft and hard
interruption, reset/restart, defensive value copies, resolver reentrancy and
deterministic traces.

## Creature Ownership

`Creature` owns one primary timeline.

Implementation status: complete for the shared primary-attack foundation.

Implemented integration:

- reset on `apply_creature()` and respawn;
- expose request, interrupt, committed/tag query, snapshot and
  presentation-update helpers;
- advance after movement/body-heading updates and before `kit.tick()`;
- a request begins at full startup and cannot damage on its request tick;
- multiply normal movement by current phase policy;
- filter other abilities only when the timeline data requests it;
- interrupt startup synchronously on action-denying stun;
- export strike heading, phase, progress, sequence, authoritative ticks,
  outcome, hit data and sequence-bound presentation data;
- preserve an accepted commitment across controller switching.

`primary_timer` remains attack cadence ownership. It starts when the request is
accepted. The timeline owns commitment, active contact and recovery.

Known integration boundary: `Creature` currently samples one phase movement
multiplier for the whole simulation tick before advancing the timeline. A tick
that overshoots into a phase with a different multiplier is therefore not
time-weighted across the boundary. Alligator is unaffected because every Bite
phase uses `1.0`; split-step movement integration is required before migrating
an attack whose phase multipliers differ.

General travel/attention headings, signed-turn state, presentation death
lifecycle and migrated airborne warning derivation belong to later presentation
and creature-specific slices; their absence does not reopen Creature's timeline
ownership.

## Input Suppression Provenance

Implementation status: complete.

`InputFrame.suppressed_buttons` records actions cleared by controller switching,
the one-tick neutral gate or invalid routing. `is_intentional_release()` keeps
those synthetic clears distinct from a genuine button-up event.

This distinction lets committed attacks survive controller transfer without
misreading routing cleanup as player intent. Alligator uses it to preserve a
valid Bite latch through suppression while still honoring a real primary-button
release.

## Hit Resolution Split

Refactor ordinary melee into:

```gdscript
build_shape(actor, reach_px, strike_heading, opts) -> Dictionary
query(actor, shape, opts) -> Array[Dictionary]
resolve(actor, shape, query, damage, delivery, plane, source, opts) -> Dictionary
hit(...) -> Array # compatibility wrapper
```

Implementation status: complete. The compatibility wrapper preserves existing
callers and ordering while the structured path snapshots arena order, fails
closed on malformed shapes, revalidates contacts and reports harvesting,
normal/latcher contacts and core hits separately.

Add an origin/heading-based melee-arc constructor so the committed direction
does not silently follow later cursor movement.

Resolution result:

```text
outcome: hit | whiff | harvest
hits
hit_records
hit_count
harvest_hit
core_hits
```

Deterministic active-tick order:

1. build from current actor position and locked strike heading;
2. snapshot targets in current arena-entity order;
3. resolve harvesting;
4. resolve snapshotted targets in query order;
5. resolve special latched-attacker contact;
6. resolve core damage;
7. store outcome and recovery duration;
8. emit swing and resolved events;
9. enter recovery after active time expires.

Target snapshotting prevents entity-list mutation from skipping or reordering
targets.

## Initial Prototype Data

| Creature/Variant | Startup | Active | Hit Recovery | Whiff Recovery | Interrupted |
| --- | ---: | ---: | ---: | ---: | ---: |
| Alligator (implemented) | `0.30` | `0.10` | `0.40` | `0.80` | `0.50` |
| Kingfisher ground | `0.25` | `0.08` | `0.25` | `0.42` | `0.35` |
| Kingfisher air | `0.32` | `0.10` | `0.30` | `0.50` | `0.40` |
| Kingfisher plunge | `0.45` | `0.12` | `0.40` | `0.65` | `0.50` |
| Mosquito release | `0.24` | `0.06` | released `0.20` | `0.30` | `0.30` |

Each definition also owns:

- aim policy;
- phase movement multipliers;
- ability-block policy;
- phase time-scaling policy;
- low-window phase tags.

Attack speed is snapshotted at acceptance and applies consistently to phase
time and cadence.

Creatures without timeline data retain legacy behavior during migration.

## Lifecycle Semantics

| Event | Rule |
| --- | --- |
| Stun during startup | cancel damage, enter interrupted recovery, no cooldown refund |
| Stun during active | resolved contact is not rolled back |
| Stun during recovery | recovery continues under stun |
| Root | does not automatically interrupt |
| Silence | does not automatically interrupt primary |
| Death | hard reset, no pending resolution; respawn starts idle |
| Controller switch | commitment persists; new controller inherits timeline |
| Input release | does not cancel a committed strike |
| Match completion | existing freeze stops progression |
| Displacement | continues unless kit-specific active validation rejects state |
| Terrain transition | continues unless a variant such as airborne Kingfisher becomes invalid |

## Migration Rules

### Alligator

Implementation status: complete for simulation and the presentation-data
bridge.

- leaves Ambush only after request acceptance;
- locks strike heading at acceptance;
- publishes a projected startup shape that follows the actor origin without
  changing locked aim;
- applies damage exactly once in the active resolver;
- publishes the resolved shape and first valid contact point;
- chooses hit, whiff, released or interrupted recovery;
- latches only a live latchable target when primary is held or synthetically
  suppressed at active;
- treats a genuine primary release as release intent without canceling the
  already committed damage event;
- keeps Death Roll independent from Bite release handling;
- preserves timeline commitment and latch behavior through controller
  switching;
- keeps Alligator PvAI on the same legal input and visibility path.

The procedural body pose and diagnostic deterministic attack reel are
implemented. Player-camera gameplay, shoreline and density captures remain
presentation evidence work, not missing simulation behavior.

### Kingfisher

- snapshot ground, air or plunge variant at request;
- consume movement charge at request acceptance;
- own low vulnerability through phase tags;
- grounding before airborne active creates interrupted recovery.

### Mosquito

- spawn projectile only on active using locked direction;
- timeline outcome becomes `released`;
- later projectile and field results remain independent.

### Compatibility

- Snapping Turtle remains unchanged;
- bosses remain unchanged;
- legacy `hit()` wrapper preserves current unmigrated call sites.

## Test Sequence

Current coverage status:

- items 1 and 2: complete;
- item 3: complete for Alligator simulation, presentation data, telegraph
  sequence ownership and lifecycle behavior;
- the Alligator portions of item 6, including suppression/controller transfer
  behavior and PvAI latch continuity: complete;
- Kingfisher, Mosquito and roster-wide migration coverage: open.

1. pure timeline boundaries, overshoot, progress, single resolution, outcomes,
   interruption and reset;
2. melee build/query/resolve, locked direction, snapshot ordering, harvest/core
   and legacy wrapper;
3. Alligator no-pre-startup damage, latch once, aim lock, recoveries, stun and
   death;
4. Kingfisher variants, low window and grounding interruption;
5. Mosquito delayed release and independent field lifecycle;
6. bot commitment, action suppression, controller transfer and reacquisition;
7. bosses, Snapping Turtle, lifecycle, movement and complete suite.

## Smallest Safe Commits

```text
[complete] 1 timeline class + pure tests; no creature enabled
[complete] 2 hit split + compatibility wrapper
[complete] 3 Creature ownership + attack snapshot + catalog validation
[complete] 4 suppression provenance + controller-transfer tests
[complete] 5 Alligator data/migration/presentation bridge/tests
[complete] 6 Alligator bot commitment and latch-continuity tests
[open]     7 Kingfisher variants/low truth/tests
[open]     8 Mosquito release/tests
[open]     9 roster-wide compatibility and final closeout
```
