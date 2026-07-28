# Battle Bog Visual Implementation Roadmap

Status: implementation underway; shared attack foundation and Alligator
simulation/presentation bridge complete, visual acceptance still open

Compiled: 2026-07-27

Execution-order note: `BATTLE_BOG_ROSTER_WIDE_CHARACTER_COMPLETION_ROADMAP.md`
supersedes this document's queue. This document remains authoritative for its
technical history and detailed visual work packages, but visual production
cannot begin before the locked PvAI exit gate in the roster-wide roadmap.

## Dependency Graph

```text
DETERMINISTIC CAPTURE HARNESS
            |
            v
ORDINARY ATTACK TIMELINE
            |
            +--> bot commitment/recovery awareness
            +--> truthful telegraphs and hit timing
            |
            v
THREE HEADING CONTRACT
            |
            +--> authored pose contract
            +--> flight and submergence projections
            |
            v
ALLIGATOR FOUR-WAY PIPELINE GATE
            |
            v
KINGFISHER ALTITUDE GATE
            |
            v
MOSQUITO CROWD GATE
            |
            +--> effect budget
            +--> simple/contextual/expanded HUD
            +--> reactive world suppression
            |
            v
REAL MIXED-CREATURE 3v3 GATE
```

Authored production assets begin only after simulation and evidence can tell us
whether they are truthful, readable and affordable.

## What The Repository Already Provides

| Area | Existing Foundation |
| --- | --- |
| Movement | species acceleration, turn limits, gait, body-heading and terrain profiles |
| Presentation data | `get_render_motion_state()` already exports many water, flight, scale, posture and weakpoint states |
| Renderer boundary | `Creature._draw()` delegates body presentation through `VisualStyle` |
| Boss attacks | real warning, active, aftermath and recovery phase precedent |
| Hit system | shared melee arc, hurtbox region, harvest and damage delivery |
| Flight | per-species height, scale, low-window scale, shadow and cue data |
| Visibility | visible, revealed, heard, last-known, suspected and hidden states |
| Minimap | visibility states and last-known ghosts |
| AI | player-compatible `InputFrame` plus legal visibility queries |
| World performance | cached terrain, throttled water and event-driven VFX |
| Tests | broad deterministic headless checks for movement, visibility and PvAI |

This is an extension project, not a foundational rewrite.

## Current Boundaries

### Simulation Truth

- timeline-enabled attacks now separate `primary_timer` cadence from
  startup/active/recovery ownership;
- `MeleeHit` now exposes committed `build_shape()`, side-effect-free `query()`
  and structured `resolve()` paths while retaining `hit()` for compatibility;
- `Creature` owns and advances a dormant primary-attack timeline, validates
  optional roster data and preserves commitment across controller switching;
- input frames now distinguish intentional button release from switch/routing
  suppression;
- Alligator bite now commits locked aim, waits for active resolution, resolves
  damage exactly once and selects hit, whiff, released or interrupted recovery;
- Alligator PvAI preserves a valid latch and can request Death Roll through the
  same input path;
- most unmigrated ordinary kits still warn and damage in the same call;
- Kingfisher and Owl begin visual air warnings and resolve damage immediately.
- broader bot reasoning about commitment and recovery remains open beyond the
  migrated Alligator behavior.

### Presentation Truth

- Alligator now publishes a sequence-bound projected bite shape during startup
  and the authoritative shape/contact point at active resolution;
- Arena windup and swing telegraphs consume the locked geometry and discard
  stale, completed or interrupted timeline-owned warnings;
- the Alligator timeline does not start the old generic animation timers, so
  those timers cannot falsely imply contact timing;
- `VisualStyle` consumes the Alligator Bite timeline as distinct startup,
  active, hit-recovery, whiff-recovery and interrupted-recovery poses, with
  latch and Death Roll priority;
- travel and attention headings are not explicit channels; locked strike
  heading exists for timeline-enabled attacks but is not roster-wide;
- start, reverse and signed turn rate are not exported;
- dead creatures stop drawing before a death clip can play;
- airborne team outline follows the body upward while no combat-radius truth
  ring remains at the ground point;
- unmigrated attack rings remain actor-centered rather than projected to their
  committed destination;
- generic swimmers lack submergence ratio, surface marker and emergence state;
- effect events have no priority class or overlap suppression.

### Evidence

- the existing test runner is headless only;
- current checks assert state dictionaries and private strings, not final
  pixels;
- visual rendering uses wall-clock-dependent values in places;
- deterministic PNG/state capture plumbing exists for a neutral smoke fixture
  and a diagnostic Alligator attack reel, and records run/frame metadata;
- no Alligator player-camera gameplay fixture, continuous-sequence comparator,
  semantic image comparator or approved baseline set exists;
- the full fixture matrix and player-camera screenshot baselines remain open.

## False-Confidence Tests

The flying-readability check verifies that
`begin_render_air_attack_startup()` becomes visible immediately after a kit
tick. It does not verify that damage waits until the warning has been
actionable.

The current live-HUD check reads private cooldown text even though the relevant
label is explicitly hidden.

These tests are useful state checks, but their names and acceptance claims must
not stand in for human-visible evidence.

## Phase 0: Deterministic Visual Evidence

Status:

- `0A` capture clock and scenario shell: complete;
- `0B` neutral PNG/state smoke capture: complete as plumbing evidence;
- deterministic repeated-capture plumbing: complete for the neutral smoke and
  diagnostic Alligator attack-reel fixtures;
- approved baselines, semantic comparison, continuous gameplay sequences, the
  full fixture matrix and performance gate: open.

Goal:

Create repeatable `1280 x 720` evidence before changing the renderer.

Detailed contract:

`docs/BATTLE_BOG_VISUAL_VALIDATION_SPEC.md`

Required:

- controllable render clock;
- fixed seed and fixed-step simulation;
- named visual scenarios;
- PNG capture at exact frames;
- short frame-sequence capture;
- procedural baseline performance sample;
- artifact manifest recording scenario, seed, frame and build.

First scenarios:

1. Alligator state reel.
2. Alligator shoreline combat.
3. Kingfisher high flight, startup, impact, low window and recovery.
4. Mosquito individual/cohesive/attack/overlap states.
5. Generic submergence and emergence.
6. Mixed six-creature objective fight.
7. Day, dusk and night.
8. Simple and expanded HUD.

This phase can land without changing gameplay.

## Phase 1: Shared Ordinary Attack Timeline

Status:

- `1A` isolated timeline, value-data validation and focused tests: complete;
- `1B` committed-shape/query/resolve split and compatibility wrapper: complete;
- `1C` `Creature` ownership, roster validation and switch/input suppression
  provenance: complete;
- `1D` Alligator simulation and sequence-bound presentation/telegraph bridge:
  complete;
- Alligator procedural phase poses and focused pose tests: complete;
- the diagnostic attack reel is complete as isolated presentation evidence;
- deterministic player-camera gameplay captures: open.

Goal:

Introduce a deterministic controller orthogonal to locomotion:

`IDLE -> STARTUP -> ACTIVE -> RECOVERY -> IDLE`

Detailed contract:

`docs/BATTLE_BOG_ORDINARY_ATTACK_TIMELINE_SPEC.md`

Required behavior:

- startup locks or tracks strike direction according to data;
- active resolves hit truth at a deterministic tick;
- recovery records hit or whiff outcome;
- phase progress is exported for presentation;
- interruption, stun, death and switching have explicit semantics;
- bots consume the same commitment and recovery truth;
- unmigrated creatures retain current behavior temporarily.

Required hit-system split:

1. build/query a hit shape;
2. resolve a previously committed attack;
3. emit hit, whiff and harvesting outcomes;
4. emit presentation events after authoritative resolution.

Prototype order:

`Alligator -> Kingfisher -> Mosquito`

Boss attack ownership remains intact and provides precedent rather than becoming
the ordinary attack controller.

## Phase 2: Presentation Snapshot

Status:

- shared attack phase, progress, sequence, authoritative ticks, outcome,
  strike heading, hit region, projected shape, contact point and interruption
  fields: implemented;
- Alligator's projected startup shape and resolved contact point: implemented;
- general travel/attention heading, signed-turn, medium-transition and
  presentation death-lifecycle fields: open.

Add:

```text
travel_heading
attention_heading
strike_heading
speed_t
signed_turn_rate
medium_transition_t
attack_phase
phase_t
attack_sequence_id
attack_started_tick
attack_active_tick
attack_outcome
hit_region
contact_point
projected_shape
interruption_reason
death_t
```

These names are canonical. `attack_sequence_id` is the identifier called
`attack_id` in early pipeline notes. `attack_active_tick` is the authoritative
phase tick. `contact_point` and `projected_shape` are nullable until active
resolution establishes them.

Ownership:

- root follows `travel_heading`;
- eyes, head or attack organ follow `attention_heading`;
- active contact follows locked `strike_heading`;
- animation cannot alter collision or damage time;
- death retains a short render lifecycle without reviving gameplay presence.

## Phase 3: Alligator Gate

Use:

`docs/BATTLE_BOG_ALLIGATOR_PIPELINE_GATE.md`

Current status:

- simulation timing, committed hit truth, suppression provenance and
  sequence-bound telegraph data are implemented and covered by state tests;
- the procedural timeline pose consumer and diagnostic attack reel are
  implemented, but the reel is not player-camera gameplay evidence;
- the shoreline, density and complete canonical-state captures remain open;
- the water compositor proof, four runtime adapters, equivalent evidence runs,
  performance comparison and human protocol remain open;
- no visual pipeline candidate has passed or been selected.

Before any candidate is accepted:

- bite phases are simulation-owned;
- turn and reverse state are exported;
- shoreline transition is deterministic;
- visible death can finish;
- contact point is compared against gameplay truth;
- all candidates run the identical state and performance captures.

No production-roster decision is made from an isolated close-up.

Before judging live 3D or any water-facing candidate, implement a minimal
shared water/foreground compositor proof:

- dry/wet/shallow/deep mask;
- per-creature depth or object mask;
- surface truth marker;
- foreground interleave;
- one shoreline entry and one submerged-body test.

A single full-screen 3D viewport is not presumed to interleave correctly with
individual 2D water and foreground layers until this proof passes.

The gate shortlists at least two viable candidates. If fewer than two pass,
improve the highest-scoring failed candidate against its failed criterion and
rerun the gate; do not advance a sole survivor by default. If three or four
pass, rank them by readability, truth, iteration cost and performance, then
carry the top two plus any candidate that uniquely satisfies a documented
roster-family need. Final roster-default selection waits until Kingfisher,
Mosquito and mixed 3v3.

## Phase 4: Height And Depth

### Flight

- keep the combat-radius truth ring at the ground point;
- render elevated body and team outline separately;
- project destination or occupied strike geometry;
- combine body pose, shadow, connector and projection;
- make the low punish window simulation-owned.

### Submergence

Add generic:

- `submergence_ratio`;
- muted submerged silhouette;
- surface truth marker;
- directional wake;
- emergence warning and projected contact;
- post-emergence recovery.

Water Shrew remains a specialist surface-skimming override rather than the
generic water model.

## Phase 5: Crowd Budget

Every effect event receives one class:

| Class | Suppression |
| --- | --- |
| `truth` | never |
| `warning` | never |
| `hit` | aggregate carefully, retain contact |
| `flavor` | suppress under overlap pressure |
| `ambient` | suppress first |

Density controller inputs:

- visible body count;
- overlapping body envelopes;
- simultaneous warning count;
- screen-space effect occupancy;
- local objective intensity;
- current accessibility mode.

First behaviors:

- aggregate repeated numbers;
- cap secondary impact particles;
- reduce flavor opacity and lifetime;
- throttle environment reactions;
- preserve silhouette, truth ring, warning and critical status.

## Phase 6: HUD Ownership

Detailed contract:

`docs/BATTLE_BOG_HUD_INFORMATION_AND_SWITCHING_CONSTITUTION.md`

### Simple

- own health and hunger;
- active abilities;
- stocks;
- compact minimap;
- controlled creature;
- critical warnings.

### Contextual

- deposit and breeding;
- boss wake, contest, claim and steal;
- reveal, heard and last-known transitions;
- height/depth state when world cues need reinforcement;
- ally intent-change alerts when switching away.

### Expanded

- current detailed squad information;
- objectives and boss-meter economy;
- strategic visibility history;
- route and timing detail.

The dense trio panel moves behind expanded ownership rather than remaining
unconditionally visible.

## Phase 7: Reactive Wetland Slice

Use:

`docs/BATTLE_BOG_WORLD_ART_CONSTITUTION.md`

Implement only after the capture and crowd-budget foundations can measure it.

First slice:

- layered dry/wet/shallow/deep shoreline;
- one cached prop cluster;
- one event-driven reed/lily response;
- one mass-scaled wake;
- one combat suppression state;
- day, dusk and night captures.

Acceptance:

- objective floor remains at least `60%` low-frequency walkable terrain;
- central prop occupancy remains at or below `20%`;
- route/habitat edge occupancy remains within `30-40%`;
- `15-30%` of nearby props react while the rest remain static or cached;
- first visible reaction begins within one simulation tick of its event;
- warning, silhouette and team truth remain above environmental motion in the
  mixed-fight capture.

## Phase 8: Real 3v3 Gate

Required cast:

- one frog;
- one bird;
- one long-bodied creature;
- three opponents with meaningfully different silhouettes.

Required conditions:

- objective fight;
- mud, water, reeds and shoreline;
- day and night;
- hidden, heard and last-known enemy transitions;
- ordinary and major attacks;
- hit and whiff;
- simple and expanded HUD;
- AI-controlled released creatures performing useful autonomous work.

The gate passes only with:

- deterministic state tests;
- normal-camera screenshots and continuous video;
- human reaction/comprehension evidence;
- performance telemetry;
- grayscale and color-vision checks;
- no regression to gameplay truth.

## Exact Current Code Anchors

| Concern | Current Anchor |
| --- | --- |
| Movement profiles | `scripts/sim/movement_feel.gd` |
| Render snapshot | `scripts/sim/creature.gd::get_render_motion_state` |
| Body render boundary | `scripts/sim/creature.gd::_draw` |
| Body and flight cues | `scripts/visual/visual_style.gd` |
| Ordinary melee resolution | `scripts/sim/abilities/melee_hit.gd` |
| Alligator bite | `scripts/sim/kits/alligator.gd::_bite` |
| Kingfisher air attack | `scripts/sim/kits/kingfisher.gd` |
| Owl air attack | `scripts/sim/kits/owl.gd` |
| Boss phase precedent | `scripts/game/bosses/boss_actor.gd` |
| VFX and text routing | `scripts/game/arena.gd` |
| Cached terrain | `scripts/game/terrain_layer.gd` |
| Throttled water | `scripts/game/water_layer.gd` |
| Minimap visibility | `scripts/ui/minimap.gd` |
| Bot input and visibility | `scripts/ai/bot_brain.gd` |
| Roster timing data | `data/battle_bog_roster.json` |
| Roster validation | `scripts/data/creature_catalog.gd` |
| Current headless runner | `scripts/test/run_all.ps1` |
| Visual capture runner | `scripts/test/run_visual_regression.ps1` |
| Visual manifest | `tests/visual/manifest.json` |
| Existing movement/readability checks | `scripts/test/battle_bog_movement_feel_check.gd` |

## Smallest Safe Delivery Sequence

```text
[complete] 0A capture clock + scenario shell
[complete] 0B neutral PNG/state metadata plumbing
[complete] 1A attack timeline unit with no migrated creatures
[complete] 1B split hit query from resolution
[complete] 1C Creature ownership + suppression provenance
[complete] 1D Alligator data, simulation and telegraph bridge
[partial]  2A attack snapshot fields; general three-heading/death fields open
[complete] 2B Alligator truthful procedural Bite pose
[open]     2C Alligator player-camera gameplay + shoreline captures
[open]     3A four pipeline adapters
[open]     3B four-way evidence run and human acceptance
[open]     4A Kingfisher projected strike and low window
[open]     4B generic submergence
[open]     5A effect classes + overlap budget
[open]     5B Mosquito gate
[open]     6A HUD ownership modes
[open]     7A wetland representative slice
[open]     8A mixed 3v3 acceptance
```

Each delivery keeps the deterministic suite green and adds visual artifacts
where the change affects pixels.
