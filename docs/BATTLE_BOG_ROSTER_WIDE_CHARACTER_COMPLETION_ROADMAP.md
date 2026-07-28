# Battle Bog Roster-Wide Character Completion Roadmap

Status: planning source of truth for completing all 21 playable creatures

Minimum planning ancestor: `710b5d4`

Required execution tag: `battle-bog-roster-plan-v2`

Historical R0 implementation checkpoint: `9e211c8`

Compiled: 2026-07-28

## Scope Answer

The completion program applies to every playable creature.

The expensive four-way visual-pipeline experiment does not repeat for all 21.
It runs on representative stress cases:

```text
Alligator
  -> proves grounded, amphibious, long-body, latch and heavy-contact needs
  -> selects viable pipeline candidates

Kingfisher
  -> proves altitude, aim separation, dive, low-window and shoreline needs

Mosquito Swarm
  -> proves distributed bodies, projectile release, resource state and density

Mixed 3v3
  -> proves that the selected default survives real roster interaction

Selected roster pipeline
  -> rolls through the remaining 18 creatures with documented exceptions only
```

Every creature still receives the same simulation, PvAI, switching, movement,
presentation, camera, accessibility, performance and readability gates.

Reference roles remain deliberately separate:

```text
Battlerite       combat precision, camera stability and phase clarity
SUPERVIVE        altitude, layered information and controlled energy ceiling
Pokemon UNITE    creature-scale readability and heroic anatomy compression
Wildlife sources locomotion, preparation, contact and medium-transition truth
Battle Bog       wetland identity, roster kits, map rules and final authorship
```

References are mined for observable principles and production evidence, never
for copied assets or a wholesale visual identity.

## Authority And Labels

This roadmap owns execution order and completion status. Detailed contracts
remain authoritative in:

- `docs/BATTLE_BOG_DECISIONS.md`
- `docs/BATTLE_BOG_PVAI_BALANCE_AND_PLAYTEST_PLAN.md`
- `docs/BATTLE_BOG_DAMAGING_ACTION_INVENTORY.md`
- `docs/BATTLE_BOG_WEAK_MODEL_EXECUTION_RUNBOOK.md`
- `docs/BATTLE_BOG_ORDINARY_ATTACK_TIMELINE_SPEC.md`
- `docs/BATTLE_BOG_COMBAT_READABILITY_CONSTITUTION.md`
- `docs/BATTLE_BOG_CREATURE_SILHOUETTE_AND_SCALE_CONSTITUTION.md`
- `docs/BATTLE_BOG_VISUAL_DIRECTION_BRIEF.md`
- `docs/BATTLE_BOG_VISUAL_VALIDATION_SPEC.md`
- `docs/BATTLE_BOG_ALLIGATOR_PIPELINE_GATE.md`
- `docs/RESEARCH_WILDLIFE_MOVEMENT_EVIDENCE.md`
- `docs/RESEARCH_VISUAL_DEEP_MINE_SOURCE_LEDGER.md`

Labels:

- `LOCKED`: existing project decision or implemented behavior.
- `IMPLEMENTED PROTOTYPE`: implemented and tested, but not a locked balance
  value or final presentation choice.
- `PROTOTYPE`: explicit implementation default; proceed without asking, then
  tune through evidence and playtest.
- `RESEARCH`: visual brief may not lock until its evidence gap closes.
- `HUMAN GATE`: requires blinded comprehension or user visual selection.

Prototype timing is not a balance promise. It prevents implementers from
inventing timing independently while retaining one later tuning gate.

The runbook is normative for checkout safety, phase inputs, write sets,
commands, artifacts, failure routing, checkpoint state and human-gate resume
rules. The historical R0 SHA is evidence only. Never check it out, reset to it
or treat it as the execution branch. Execution always starts from the current
clean branch head after proving `battle-bog-roster-plan-v2` is an ancestor.

## Program Shape

```text
CURRENT GREEN FOUNDATION
  96/96 tests + deterministic Alligator diagnostic reel
                         |
          +--------------+--------------+
          |              |              |
          v              v              v
   GAMEPLAY TRUTH   EVIDENCE FACTORY   MOTION RESEARCH
   every damage     camera/comparator  bounded source gaps
   action + 20
   primary migrations
          |              |              |
          +--------------+--------------+
                         |
                         v
                LOCKED PvAI EXIT GATE
        Stage B/C evidence + victory/defeat/soak
                         |
                         v
              REPRESENTATIVE PIPELINE GATE
              Alligator -> Kingfisher -> Mosquito
                         |
                         v
                 ROSTER PRODUCTION WAVES
                         |
                         v
                 MIXED PvAI / 3v3 RELEASE GATE
```

Gameplay truth can progress while motion research continues. A creature is not
complete until all three tracks converge.

## Current Roster Baseline

All 21 creatures exist in the roster and currently have a dedicated kit, bot
hook, movement profile, scale class and procedural `VisualStyle` support.
Alligator alone has the new authoritative ordinary-attack timeline and
deterministic attack pose reel, but its locked frame-data conformance remains
open at `R0.5`. The other 20 primaries still use legacy request/cooldown
execution. This is a functional baseline, not a completed character-production
state.

```text
Alligator                  timeline/presentation prototype; R0.5 + evidence open
Other 20 playable animals  functional kit + bot + movement + procedural read
                           timeline/action audit + authored production open
```

## Universal Creature Definition Of Done

A creature is `COMPLETE` only when every required row passes.

| Gate | Required Evidence |
| --- | --- |
| Identity | species, team, heading, scale, altitude and medium readable without labels |
| Damaging actions | every discrete primary, ability, passive, retaliation, summon, field and hazard is inventoried with an owner, timing policy, exemption and evidence |
| Timeline simulation | no request-tick damage; exactly one active resolution; committed aim/shape for every discrete damaging action governed by Decision #23 |
| Outcomes | hit, whiff, interrupted and released semantics are explicit where applicable |
| Lifecycle | death, respawn, match freeze and creature replacement clear commitment safely |
| Input | switching, neutral gate, suppression and genuine release remain distinguishable |
| PvAI | bot accepts, commits, releases and reacquires through every strategy branch |
| Solo squad | inactive allies forage, fight, retreat, defend, return, deposit, breed and pursue objectives under legal information while the controlled creature still deposits explicitly |
| Movement | authentic start, travel, turn, reverse, stop and required medium transitions |
| Presentation | canonical snapshot drives attack, movement, contact, weakpoint and death state |
| Combat read | warning, active contact and recovery are distinct at real player camera |
| HUD/visibility | ownership, state, minimap and information-limited world rules remain truthful |
| Accessibility | team and threat meaning survives grayscale and three CVD transforms |
| Determinism | three repeated evidence runs match within the approved baseline contract |
| Performance evidence | five-run telemetry is complete with 300 warm-up and 1,800 measured frames and screenshot readback disabled; numbers remain record-only until target hardware/settings are locked; missing evidence, visual-truth failure and event misalignment remain hard failures |
| Human read | recognition, phase, direction, threat and reacquisition thresholds pass |
| Production | source asset, editable file, pivots, manifests, rights ledger and fallback exist |
| Regression | focused tests, existing creature-wave test and full strict suite pass |

Universal focused test:

`scripts/test/battle_bog_<creature>_timeline_check.gd`

Universal player-camera scenario:

`<creature>_player_camera_attack`

Required ordinary-attack capture interval:

Capture every frame from 30 frames before `TEL+0` through recovery end. Preserve
named anchors `TEL+0`, `HIT-1`, `HIT+0` and `RECOVERY+0` in every artifact.

## Locked PvAI Exit Gate

Decision #44 and `BATTLE_BOG_PVAI_BALANCE_AND_PLAYTEST_PLAN.md` prohibit visual
production until PvAI tuning and human playtest pass. Infrastructure,
procedural diagnostic evidence and combat migration may proceed beforehand;
candidate asset production and final animation authoring may not.

Required order:

```text
StageB5 -> StageB15 -> throughput review
        -> StageCMain -> StageCExtended
        -> natural Blue victory
        -> natural Blue defeat
        -> 21+ minute objective soak
        -> logs agree with video and no S0/S1 remains
        -> visual production may begin
```

Run exactly one named stage at a time. Review `StageB5` before `StageB15`;
accept `StageB15` and throughput optimization before `StageCMain`; classify
every `StageCMain` threshold miss before `StageCExtended`. `Stage Full` may not
bypass the `MaxJobs=32` cap without an explicit reviewed override. Preserve
each stage's manifests, merged summaries, anomaly classifications, replay
references and promotion decision.

The three human sessions must exercise switching while moving, attacking,
injured, hungry, on cooldown, dead and exhausted. Inactive allies must visibly
forage, fight, retreat, defend, return, deposit, breed and pursue objectives
without omniscient information. Only inactive allies may deposit and breed
autonomously; the actively controlled creature retains explicit deposit input.

Any later change to damage, cadence, action timing, collision, speed,
acceleration, turn rate, terrain or flight rules, AI decisions or objective
routing invalidates affected PvAI evidence. Rerun `StageB5`, the relevant
longer matrix stage and affected human session before visual production
continues.

Stage commands use a unique reviewed `<run-id>`:

```powershell
.\scripts\test\run_balance_matrix.ps1 -Stage StageB5 -WorkerCount 4 -MaxJobs 14 -TimeoutSec 300 -OutputRoot "artifacts\balance-matrix\stageb5-<run-id>"
.\scripts\test\run_balance_matrix.ps1 -Stage StageB15 -WorkerCount 4 -MaxJobs 14 -TimeoutSec 900 -OutputRoot "artifacts\balance-matrix\stageb15-<run-id>"

# Run only after the prior-stage promotion record explicitly approves the job count.
.\scripts\test\run_balance_matrix.ps1 -Stage StageCMain -WorkerCount 4 -MaxJobs 336 -TimeoutSec 900 -OutputRoot "artifacts\balance-matrix\stagecmain-<run-id>"
.\scripts\test\run_balance_matrix.ps1 -Stage StageCExtended -WorkerCount 4 -MaxJobs 112 -TimeoutSec 1200 -OutputRoot "artifacts\balance-matrix\stagecextended-<run-id>"

.\scripts\test\battle_bog_balance_matrix_contract_check.ps1
.\scripts\test\battle_bog_balance_summary_contract_check.ps1
```

Every output root retains `manifest.json`, `results.jsonl`, `summary.json` and
all per-job artifacts. Review adds:

```text
review/anomalies.md       classified threshold, idle and lifecycle anomalies
review/replays/           copied references or exact source artifact paths
review/promotion.json     stage, build/rules fingerprints, reviewer, decision
```

`promotion.json` must say `promote`, `rerun` or `tune_then_rerun`. Only
`promote` unlocks the next command. Never reuse an output root after gameplay
or build identity changes.

Every non-pass follows the fail-closed triage and invalidation rules in
`BATTLE_BOG_WEAK_MODEL_EXECUTION_RUNBOOK.md`. A wall-clock or harness timeout is
a failed command. A balance simulation whose result status is `timeout` is
valid unresolved-match evidence and remains in all required denominators; it
is not a completed match.

## One-Time Infrastructure

These tasks are implemented once and reused by the roster.

| ID | Deliverable | Dependency | Acceptance |
| --- | --- | --- | --- |
| I0 | split-step attack movement integration | current timeline | coarse ticks conserve phase-specific steering movement, exact-once resolution and new-latch duration |
| I1 | immutable presentation snapshot | I0 | validated value-only identity, motion, direction, turn, medium, attack, lifecycle and compatibility data remain isolated |
| I2 | projectile release resolver | I1 | Mosquito then Firefly prove release and later projectile impact cannot rewrite one another |
| I3 | attack alternation context | I1 | Newt then Crayfish prove selection at acceptance and no rollback on interruption; Duck follows |
| I4 | timeline melee resolver | I1 | extract only while migrating Bullfrog as Alligator's second grounded-melee consumer |
| I5 | narrow latch follow-up helpers | I4 | Alligator and Water Snake prove effective hold, first-live-target attachment, intentional release and lifecycle safety |
| I6 | aerial strike context | I1 | Kingfisher and Owl jointly prove variant, altitude, target, landing projection, damage plane and low window |
| I7 | Cane Toad channel pilot | I1 | kit-local startup, pulse, release, stun and ammo rules pass before any shared channel abstraction |
| I8 | real Arena fixture builder | I1 | real Creature, kit, target, terrain, telegraph, visibility, HUD and camera run deterministically |
| I9 | camera presets | I8 | PvAI `2.6` and competitive `2.2` are recorded in artifacts |
| I10 | capture modes | I8 | diagnostic, answer-free evaluator and screenshot-free performance modes share one simulation |
| I11 | semantic truth output | I8 | body, organ, ground anchor, heading, projected shape, contact and occluder data export |
| I12 | baseline promotion/comparator | I10-I11 | explicit promotion, three-run determinism, MAE, ROI SSIM and changed-pixel gates |
| I13 | shoreline/depth compositor proof | I8 | dry, mud, shallow, deep, submerge and foreground interleave are distinguishable |
| I14 | performance runner | I8 | 300 warm-up, 1,800 measured, five runs and required telemetry |
| I15 | blinded review packager | I10-I12 | randomized anonymous clips, separate answer key and trial metadata |
| I16 | visual adapter boundary | I1 | all candidates consume one snapshot and cannot own gameplay timing or collision |

Do not create one universal animal controller. Shared helpers are accepted only
after at least two creatures need the same semantic behavior.

### R0.5 Locked Frame-Data Conformance

The current Alligator timeline is an implemented prototype, not yet a pass
against Decisions #23-26. Before split-step or roster migration:

1. treat whiff recovery as full recovery and derive hit recovery as
   `whiff_recovery_sec * 0.60`;
2. block every new Primary, Q, E, flight and context action start during
   recovery except a dash cancel explicitly flagged by that action;
3. derive counter-hit eligibility from authoritative `STARTUP` and clear it on
   interruption;
4. apply the locked `+20%` counter-hit damage with its distinct flash;
5. produce exactly three render-only hitstop frames for hits of at least 50
   damage without pausing simulation.

Focused tests must prove recovery lock for primary/Q/E/context inputs, exact
hit-recovery derivation from `whiff_recovery_sec * 0.60`, startup-only counter
hits, interruption cleanup, distinct
counter feedback, render-only hitstop and unchanged deterministic sim state.
Use zero cooldowns to prove suppressed starts while already-running Death Roll
and latch continuation still function.

Implementation packet:

1. Add failing `scripts/test/battle_bog_frame_data_check.gd`; extend Alligator
   timeline, damage-meta and production-catalog checks.
2. Change Alligator hit recovery to `0.48`. Replace Q/E-only filtering with
   phase-aware Primary/Q/E/flight/context start suppression and record
   suppressed-button provenance so held latch input is not mistaken for
   intentional release. Keep active unblocked so held Q may begin Death Roll at
   Bite contact.
3. Make production catalog validation reject non-`0.60` recovery derivation and
   disabled recovery blocking. Keep arbitrary values legal in pure
   `AttackTimeline` mechanics fixtures.
4. Add an authoritative timeline phase query and a value-only kit action-phase
   query aggregated by `Creature`. Any committed primary or kit action is
   counter-vulnerable exactly in `STARTUP`; use the legacy VFX timer only for
   unmigrated attacks. Death Roll startup participates; channel/exit do not.
5. Route `counter_hit` through render feedback, retain existing `COUNTER` text
   and ring, and add a visually distinct counter flash.
6. Apply counter-hit to every positive enemy-sourced event during startup,
   including DOT/field ticks; exclude self and environment damage. Replace
   second-based hitstop with `HITSTOP_FRAMES := 3`; decrement it only
   from render processing and never from `tick_sim()`.
7. Keep Death Roll kit-owned as `startup -> channel -> exit/recovery`, preserve
   its five-second 30-DPS behavior, and use `0.35 s` startup, `0.40 s` release
   exit and `0.55 s` interrupted exit as `PROTOTYPE` values.
8. Update the diagnostic Alligator reel and render signatures that currently
   duplicate `0.40` hit recovery or second-based hitstop.
9. Add `recovery_allows_dash_cancel: bool` to normalized timeline policy with
   default `false`. No R0.5 or R4 action sets it true.
10. Treat an enemy source as a valid, live `source_actor` whose actor differs
    from the victim and whose team differs from the victim. Children preserve
    their attributed actor. Self, ally, null-source and environment damage
    cannot counter-hit.
11. A qualifying hit applies `max(existing_frames, 3)` to attacker and victim.
    Decrement exactly once per `_process()` call; never stack above three.

R0.5 has one integration owner. Its exact write set is
`scripts/sim/combat/attack_timeline.gd`, `scripts/sim/creature.gd`,
`scripts/sim/kits/alligator.gd`, `scripts/data/creature_catalog.gd`,
`scripts/game/arena.gd`, `data/battle_bog_roster.json`,
`scripts/test/visual/scenarios/alligator_attack_reel_scenario.gd`,
`tests/visual/manifest.json`, new `scripts/test/run_checked_command.ps1`,
new `scripts/test/battle_bog_checked_command_contract_check.ps1`, and the named
R0.5 test files. Timing data moves
from top-level `primary_attack_timelines` to the Decision #23 canonical path
`stats.action_timelines.<action_id>`; the catalog rejects the old top-level
path after migration.

Compatibility checks retain the legacy counter fallback for unmigrated
Snapping Turtle and Wolf Spider, and verify recovery blocking does not suppress
Death Roll at valid Bite contact.

Acceptance:

```powershell
.\scripts\test\battle_bog_checked_command_contract_check.ps1
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_frame_data_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_attack_*check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_alligator*_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_damage_meta_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_primary_attack_catalog_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -KeepGoing -StrictOutput
& 'C:\Godot\Godot_v4.6-stable_win64_console.exe' --headless --path . --quit-after 300
git diff --check
```

### R1A Split-Step Movement Contract

1. Add non-mutating `time_to_phase_boundary()` to `AttackTimeline`;
   `current_phase_name()` was added at R0.5.
2. Replace the full-tick movement/timeline order with one integration method
   that partitions the tick at each timeline boundary.
3. For each slice, read the current multiplier, move for that slice, then
   advance the timeline by that exact duration.
4. Re-read sequence and actor lifecycle after each boundary because a resolver
   may interrupt, reset, kill or replace the actor.
5. Give any remainder after recovery the idle multiplier `1.0`.
6. Preserve a full startup on the request tick.
7. Apply the multiplier only to steering; keep current dash and residual
   velocity behavior.
8. Preserve whole-tick `last_move_displacement_px`.
9. Guard latch generation so a latch created at active contact does not lose
   duration in the same coarse tick.
10. Implement this in
    `Creature._integrate_attack_movement_and_timeline(delta)`, replacing the
    separate attack-scaled steering and timeline advancement in `tick_sim()`.
11. `time_to_phase_boundary()` returns `INF` while idle and `0.0` at a pending
    boundary. The integration loop fails after more than eight boundaries in
    one tick rather than hanging.
12. `last_move_displacement_px` is the tick-start to tick-end displacement, not
    accumulated path length.

Tests cover every single and multi-boundary crossing, coarse-versus-partitioned
equivalence, exact-once resolution, reactive death/reset, dash behavior and
new-latch duration.

### R1B Presentation Snapshot Contract

Create `scripts/sim/presentation/creature_presentation_snapshot.gd`.
`Creature.get_presentation_snapshot()` returns the read-only snapshot;
`get_render_motion_state()` remains a temporary compatibility adapter that
returns a deep mutable copy.

The snapshot privately owns validated value data and exposes getters plus
`to_dictionary()`. Construction rejects objects, callables, cyclic containers,
non-finite values and invalid headings. Coordinate-bearing fields are world
pixels unless their name ends in `_units`; headings are normalized world-space
vectors; progress/intensity/ratio fields are in `[0, 1]`; optional values use
explicit `has_*` flags plus neutral zero values.

Exact root schema:

| Field | Type | Rule |
| --- | --- | --- |
| `schema_version` | `int` | starts at `1` |
| `simulation_tick` | `int` | fixed-step tick that produced sim truth |
| `render_revision` | `int` | increments only when render feedback changes |
| `actor_id` | `StringName` | stable slot/actor identity, never instance ID |
| `creature_id` | `StringName` | roster ID |
| `team` | `int` | canonical team enum |
| `alive` | `bool` | lifecycle truth |
| `world_position_px` | `Vector2` | root ground-plane position |
| `velocity_px_per_sec` | `Vector2` | fixed-step velocity |
| `speed_px_per_sec` | `float` | finite and non-negative |
| `speed_ratio` | `float` | normalized against current legal max |
| `locomotion_state` | `StringName` | catalogued state |
| `body_heading` | `Vector2` | normalized |
| `travel_heading` | `Vector2` | persisted normalized heading |
| `attention_heading` | `Vector2` | normalized |
| `has_strike_heading` | `bool` | controls optional heading |
| `strike_heading` | `Vector2` | normalized or `Vector2.ZERO` |
| `signed_body_turn_radians` | `float` | actual fixed-step signed delta |
| `turn_intensity` | `float` | normalized absolute turn |
| `body_radius_px` | `float` | gameplay truth radius |
| `footprint_kind` | `StringName` | `circle` or `capsule` |
| `footprint_radius_px` | `float` | gameplay hull radius |
| `capsule_half_length_px` | `float` | zero for circle |
| `model_scale` | `float` | validated visual scale |
| `visual_radius_px` | `float` | derived visible occupancy radius |
| `surface` | `StringName` | current terrain surface |
| `previous_surface` | `StringName` | surface before transition |
| `transition_kind` | `StringName` | catalogued or `none` |
| `transition_progress` | `float` | forward `0..1` |
| `elevation_state` | `StringName` | ground/perched/airborne/low/submerged |
| `height_units` | `float` | visible body height |
| `altitude_units` | `float` | ground-anchor to body lift |
| `submerged_depth_units` | `float` | zero when not submerged |
| `low_window_open` | `bool` | gameplay vulnerability truth |
| `low_window_t` | `float` | normalized window progress |
| `ground_anchor_px` | `Vector2` | world-space truth-ring anchor |
| `active_actions` | `Array[Dictionary]` | unique records sorted by `(owner_id, action_id, sequence_id)` |
| `health_ratio` | `float` | normalized current health |
| `resources` | `Dictionary` | `StringName -> float`, keys catalogued |
| `stealth_state` | `StringName` | none/hidden/revealed/broken |
| `latch_role` | `StringName` | none/attacker/victim |
| `latch_target_id` | `StringName` | stable actor ID or empty |
| `has_latch_anchor` | `bool` | controls optional anchor |
| `latch_anchor_px` | `Vector2` | world point or zero |
| `grip_ratio` | `float` | zero when not latched |
| `weakpoint_id` | `StringName` | active region or empty |
| `weakpoint_state` | `StringName` | closed/warning/open/hit |
| `death_sequence_id` | `int` | zero while no death sequence |
| `death_t` | `float` | deterministic normalized death progress |
| `respawn_remaining_sec` | `float` | zero unless dead/waiting |
| `kit_cues` | `Dictionary` | namespace -> catalogued value-only keys |
| `hitstop_frames_remaining` | `int` | render-only, zero or `1..3` |
| `counter_flash_t` | `float` | render-only normalized feedback |

Each `active_actions` item has exact keys:

```text
action_id:StringName        owner_id:StringName
sequence_id:int             phase:StringName
phase_t:float               remaining_sec:float
variant:StringName          outcome:StringName
has_strike_heading:bool     strike_heading:Vector2
projected_shape:Dictionary  has_contact_point:bool
contact_point_px:Vector2    movement_multiplier:float
blocks_action_starts:bool   counter_vulnerable:bool
```

`owner_id` is the stable actor ID that accepted or spawned the action. Allowed
phases are `startup`, `active`, `recovery`, `channel`, `armed`, `travel`,
`aftermath` and `teardown`. Allowed outcomes are `none`, `hit`, `whiff`,
`released`, `interrupted`, `expired` and `owner_lost`. A channel with no finite
end uses `remaining_sec = -1.0`. Duplicate
`(owner_id, action_id, sequence_id)` records are rejected.

`projected_shape` accepts exactly one catalogued schema:

```text
point:   kind:StringName, point_px:Vector2
none:    kind:StringName
circle:  kind:StringName, center_px:Vector2, radius_px:float
capsule: kind:StringName, center_px:Vector2, axis:Vector2,
         radius_px:float, half_length_px:float
arc:     kind:StringName, origin_px:Vector2, heading:Vector2,
         radius_px:float, half_angle_rad:float
line:    kind:StringName, start_px:Vector2, end_px:Vector2,
         half_width_px:float
rect:    kind:StringName, center_px:Vector2, heading:Vector2,
         half_extents_px:Vector2
```

All geometry is world pixels and deep-copied; axes/headings are normalized,
dimensions are finite/non-negative and extra keys are rejected. These exact
shape schemas and allowed locomotion, transition, elevation, resource and
kit-cue keys live in new `data/battle_bog_presentation_schema.json` and are
validated by `creature_catalog.gd`. Kit-cue leaves may be `bool`, `int`, finite
`float`, `StringName`, `Vector2`, `Color`, `PackedVector2Array` or nested
arrays/value dictionaries of those types only.

The schema JSON enumerates team IDs, action IDs, phases, outcomes, locomotion,
transition, elevation, resource and kit-cue keys. Unknown values fail
construction; the implementer may not silently add an enum. Add
`to_json_dictionary()` for evidence output, converting `StringName` to
`String`, `Vector2` to `[x,y]`, `Color` to `[r,g,b,a]`, and packed arrays to
ordinary JSON arrays. Runtime adapters use `to_dictionary()` only.
`with_render_feedback(hitstop_frames:int, counter_flash_t:float,
render_revision:int) -> CreaturePresentationSnapshot` is the only render
derivation API.

`Creature` builds one base snapshot after movement, timelines, kit state and
lifecycle finish each fixed simulation tick. Repeated same-tick reads return
the same object. `_process()` may call `with_render_feedback()` to create a new
immutable derived snapshot only when hitstop/flash revision changes; it may not
read or mutate gameplay. Visual adapters receive the base snapshot normally;
when render feedback changes, the derived replacement becomes the current
snapshot until the next base/feedback revision. Adapters consume only that
current immutable snapshot and static asset metadata.

Snapshot tests prove input, output and nested-copy isolation; invalid-value
rejection; idle strike invalidation; heading separation; transition direction;
switch/species reset; death/respawn state; and stable same-tick output.
Visual adapters may not read `Creature`, kit objects, timers or scene nodes
directly; the snapshot and static asset metadata are their only runtime inputs.

### R4 Combat Adapter Rules

- Executable resolver behavior stays in kit/resolver code, never in roster JSON.
- Projectile active creates exactly one projectile from the active position and
  locked heading; impact and field lifetime remain projectile-owned.
- Alternation uses `peek()` then `commit_acceptance(sequence_id)`. Rejection
  does not advance; later interruption does not roll back.
- Timeline melee wraps existing `MeleeHit` query/resolve behavior and preserves
  Alligator's normal-contact outcome policy.
- Latch sharing is limited to effective-held input, first-live-target
  attachment and intentional-release detection. Automatic, refreshable, capped
  and Death Roll policies remain kit-owned.
- Aerial context is an acceptance-time value object. It does not own flight,
  damage or collision.
- Cane Toad remains kit-local: `idle -> startup -> channel -> exit`, first pulse
  at channel entry, `0.25 s` pulses, active-only ammo drain, constrained live
  aim and release/stun cleanup.
- Duck Mobbing remains kit-owned contact-consumed state, not alternation.

### R1-R2 Artifacts And Acceptance

Planned files and proof:

| Step | Owned Files | Focused Acceptance | Artifact Or Checkpoint |
| --- | --- | --- | --- |
| R1A | `attack_timeline.gd`, `creature.gd`, new `battle_bog_attack_movement_split_check.gd` | split-step focused test plus attack/Alligator compatibility | clean commit after full strict suite |
| R1B | new `scripts/sim/presentation/creature_presentation_snapshot.gd`, `scripts/sim/creature.gd`, `scripts/data/creature_catalog.gd`, new `data/battle_bog_presentation_schema.json`, new `battle_bog_creature_presentation_snapshot_check.gd` | snapshot isolation/schema/JSON test plus movement/Alligator checks | clean commit after full strict suite |
| R2A | extend existing `scenes/test/VisualRegressionArena.tscn`, `scripts/test/visual/visual_regression_arena.gd`, `visual_manifest.gd`, `run_visual_regression.ps1`, `tests/visual/manifest.json`; add `tests/visual/semantic_capture.schema.json`, scenario catalog and checks | add `-CameraPreset PvAI|Competitive`, `-CaptureMode Diagnostic|Evaluator|Performance`; validate/list and neutral smoke at both cameras | `artifacts/visual-regression/r2a-<attempt-token>/` |
| R2B | new `scripts/test/visual/image_metrics.gd`, `compare_visual_regression.ps1`, `promote_visual_baseline.ps1`, `battle_bog_visual_comparator_check.ps1` | three-run determinism, thresholds, refusal before promotion, explicit approved promotion, post-promotion rerun | `tests/visual/baselines/<platform>/` plus `artifacts/visual-regression/r2b-<attempt-token>/` |
| R2C | Alligator player-camera/shoreline scenarios and manifest entries | full frame interval, semantic JSON, evaluator mode and compositor evidence | `artifacts/visual-regression/r2c-<run-id>/` |
| R2D | new `scripts/test/run_visual_performance.ps1`, `scripts/test/visual/performance_sampler.gd`, `scripts/test/battle_bog_visual_performance_contract_check.ps1`, `tests/visual/performance.schema.json`, `alligator_six_actor_density_scenario.gd` and manifest entry | 300 warm-up, 1,800 measured, five runs, readback disabled and required telemetry | `artifacts/visual-performance/r2d-<attempt-token>/performance.json` plus per-run samples |
| R2E | new `scripts/sim/presentation/visual_adapter.gd`, `scripts/visual/adapters/procedural_visual_adapter.gd` and `scripts/test/battle_bog_visual_adapter_boundary_check.gd` | adapter accepts snapshot/static metadata only and rejects Creature/kit/node/tree reads | artifact-free code contract; checkpoint SHA and logs live in `artifacts/visual-adapter/r2e-<attempt-token>/` |
| R2F | new `scripts/test/package_blinded_review.ps1`, `tests/visual/human_trials/trial_manifest.schema.json`, `scripts/test/battle_bog_blinded_review_contract_check.ps1` | randomized clips, participant/trial cardinality, separate answer key and no evaluator labels | `tests/visual/human_trials/<trial-id>/participant-package/` and `evaluator-package/answer-key.json` |

Commands after each relevant slice:

The new PowerShell scripts implement the parameter names shown here exactly;
their contract checks reject missing artifacts, invalid counts and unknown
arguments.

R2A extends the manifest with
`capture_window:{anchor:"TEL+0",before_frames:30,through:"RECOVERY_END"}` and
`required_anchors`. Every event-relative scenario implements
`get_named_anchors()`. R2C creates separate Alligator scenarios for
`alligator_player_camera_attack`, `alligator_shoreline_transition`,
`alligator_latch_death_roll`, `alligator_death_respawn` and
`alligator_six_actor_density`.

The comparator never writes a baseline. Promotion requires three matching
passed captures from one clean HEAD/build/renderer/viewport contract, reviewer
ID, written reason and old-hash verification. Replacing an existing baseline
requires `-Replace -ApprovedBy <id>`. Promotion gets a dedicated commit and is
followed by comparator and full-suite reruns. R4 evidence never promotes a
baseline.

`VisualAdapter` exposes only
`configure(static_metadata:Dictionary)`, `apply_snapshot(snapshot)`,
`get_root_canvas_item()` and `teardown()`. Its boundary check statically rejects
Creature, kit, timeline, collision, damage and scene-tree reads in adapter
directories. R2F encodes 60-fps clips with the repository-pinned ffmpeg and
keeps label-free `participant-package/` physically separate from
`evaluator-package/answer-key.json`.

```powershell
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_attack_movement_split_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_creature_presentation_snapshot_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_visual_regression_arena_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_visual_regression.ps1 -Validate -RunId r2a-validate-<attempt-token>
.\scripts\test\run_visual_regression.ps1 -List -RunId r2a-list-<attempt-token>
.\scripts\test\run_visual_regression.ps1 -Scenario alligator_player_camera_attack -RunId r2c-alligator-player-camera-<attempt-token> -Capture
.\scripts\test\run_visual_performance.ps1 -Scenario alligator_six_actor_density -RunId r2d-<attempt-token> -Runs 5 -WarmupFrames 300 -MeasuredFrames 1800
.\scripts\test\battle_bog_visual_performance_contract_check.ps1 -ArtifactRoot "artifacts\visual-performance\r2d-<attempt-token>"
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_visual_adapter_boundary_check.gd' -KeepGoing -StrictOutput
.\scripts\test\package_blinded_review.ps1 -InputRoot "artifacts\visual-regression\r2c-<attempt-token>" -TrialId r2f-<attempt-token> -Participants 8 -TrialsPerTask 20 -Seed 307
.\scripts\test\battle_bog_blinded_review_contract_check.ps1 -TrialRoot "tests\visual\human_trials\r2f-<attempt-token>"
.\scripts\test\run_all.ps1 -KeepGoing -StrictOutput
& 'C:\Godot\Godot_v4.6-stable_win64_console.exe' --headless --path . --quit-after 300
git diff --check
```

Each slice ends only after focused checks, compatibility checks, the full
strict suite, headless boot and `git diff --check` pass and its artifacts are
reviewed. Then create one scoped checkpoint commit before the next shared-file
owner begins. R2E intentionally produces no runtime media; save its focused,
full-suite, headless and diff logs plus `commit.txt` under
`artifacts/visual-adapter/r2e-<run-id>/`.

## Per-Creature Production Packet

Every creature moves through the same packet. Family waves share research and
infrastructure, but no row is skipped because another family member passed.

1. Freeze the current design intent and enumerate every damaging action.
2. Migrate the primary and applicable damaging actions to authoritative timing.
3. Prove player input, bot input, suppression, switching and lifecycle behavior.
4. Implement the species movement contract and every required terrain/height
   transition in the canonical presentation snapshot.
5. Capture diagnostic evidence at PvAI and 3v3 camera settings.
6. Author the selected visual-pipeline asset with eight-way direction,
   locomotion, attacks, damage, death, respawn and creature-specific states.
7. Add truthful telegraph, contact, afterstate, recovery, shadow, wake, ripple,
   height and attachment cues without changing gameplay geometry.
8. Package editable source, runtime export, pivots, frame/event manifest, rights
   ledger and procedural fallback.
9. Run accessibility, density, determinism, performance-recording and blinded
   comprehension gates.
10. Run focused tests, compatibility tests, full strict suite and a real PvAI
    playtest before marking the creature complete.

## Representative Pipeline Gate

Four candidates:

1. pre-rendered 3D atlas;
2. live orthographic 3D;
3. restrained `Skeleton2D` rig;
4. hand-authored directional key poses.

The current procedural renderer remains the deterministic diagnostic fallback.

All candidates consume one presentation snapshot. Candidate code cannot own:

- collision or hurtboxes;
- damage or target selection;
- root motion;
- attack timing;
- altitude validity;
- low-window timing;
- gameplay outcome.

Selection sequence:

```text
Alligator isolated states
  -> Alligator real shoreline combat
  -> Alligator density/performance
  -> blinded Alligator comprehension and elimination
     (at least two candidates must survive)
  -> surviving candidates on Kingfisher
  -> surviving candidates on Mosquito Swarm
  -> mixed 3v3
  -> select roster default and justified exceptions
```

## Combat Migration Waves

Decision #23 applies to every discrete damaging ability, not only primaries.
Before migrating a creature, create one inventory row for each primary variant,
Q/E damage, passive retaliation, summon attack, projectile, field and hazard.
Every row names its simulation owner, timing model, capture, focused test and
any justified continuous/environmental exemption. No creature completes its
combat gate while an inventory row is unclassified.

Discovery is complete, but normalized implementation contracts are not.
`R3.5` must expand each discovered row and each independently owned child effect
to the exact schema in `BATTLE_BOG_DAMAGING_ACTION_INVENTORY.md`. R4 cannot
start until the inventory validator and an independent reviewer mark every
non-human-gated action `CONTRACT_READY`. The sole current exception is
`otter_gang_up_cohort = HUMAN_BLOCKED` with `gate_id=R4H`; it blocks only R4F.1.
Factual extraction preserves current code
unless a `PROTOTYPE` migration record explicitly overrides it. Any genuine
behavior conflict becomes `BLOCKED`; a weaker executor never chooses a side.

Use timing schemas by action type:

| Schema | Ordered Fields | Ownership Rule |
| --- | --- | --- |
| Contact | startup / active / hit recovery / whiff recovery / interrupted recovery | committed query resolves exactly once during active |
| Projectile | startup / release window / released recovery / interrupted recovery | timeline owns release; projectile owns flight, impact and later field |
| Dash or aerial strike | startup / travel / contact-active / hit or whiff recovery / interrupted recovery | accepted context locks geometry; locomotion cannot move the hit window |
| Channel | startup / pulse interval / release exit / interrupted exit | channel owns pulses and resource drain; no repeated startup |
| Persistent or retaliation | arm condition / contact or tick cadence / lifetime / teardown | owner documents why no single whiff exists and proves exact cadence/cleanup |

Contact and projectile release use `AttackTimeline`. Dash/aerial travel is a
`STARTUP` substate and `ACTIVE` begins only at contact. Cane Toad's channel
remains a kit-owned startup/channel/exit state machine. A spawned projectile,
field or summon owns later flight, ticks, lifetime and teardown. No player
ability trigger is exempt from startup/active/recovery; only child-entity ticks
use a documented cadence/lifetime contract.

For contact actions, the table declares:

`startup / active / full whiff recovery / interrupted recovery`

`hit_recovery_sec` is always derived as `whiff_recovery_sec * 0.60` and
catalog-validated. All values are `PROTOTYPE` except locked current cadences:
Alligator `1.8 s` and Great Blue Heron `1.4 s`. Other cadences preserve current
behavior until an explicitly recorded playtest change.

| Wave | Creature | Primary Contract | Special Acceptance |
| --- | --- | --- | --- |
| C0 | Alligator | Bite `0.30 / 0.10 / 0.80 / 0.50` `IMPLEMENTED PROTOTYPE`; current hit recovery must change from `0.40` to derived `0.48`; `1.8 s` cadence `LOCKED` | R0.5 conformance, real-camera, shoreline, latch, Death Roll and death evidence open |
| C1 | Kingfisher | ground `D 0.25/0.08/0.42/0.35`; air `D 0.32/0.10/0.50/0.40`; plunge `X 0.25/0.20/0.12/0.65/0.50` | variant at acceptance; charge consumed once; grounding interrupts air; low-window truth |
| C1 | Mosquito Swarm | release `0.24/0.06`; released `0.20`; interrupted `0.30` | projectile spawns at active; field lifecycle independent; attack-edge cue |
| C2 | Bullfrog | Bite `0.35/0.10/0.55/0.45` | camouflage breaks after acceptance; Swallow uses resolved normal hit |
| C2 | Beaver | Chomp `0.30/0.08/0.45/0.35` | Gnaw uses committed shape and heals once on valid cover contact |
| C2 | Mink | Bite `0.22/0.08/0.35/0.30` | Choke remains independent until dash-strike helper is proven |
| C2 | Water Shrew | Bite `0.20/0.06/0.30/0.28` | debuff and primed effect consume only on landed contact |
| C2 | Bog Turtle | Headbutt `0.28/0.08/0.45/0.35` | self-damage occurs once at active resolution on hit or whiff; while basking, ally heal/buff follows the same accepted active resolution |
| C3 | Newt | alternating tails `0.28/0.10/0.45/0.35` | side chosen at acceptance; rejected tail-loss attack does not advance side |
| C3 | Crayfish | alternating claws `0.22/0.08/0.38/0.30` | side geometry committed; later body-radius changes do not alter shape |
| C3 | Duck | Wing `0.22/0.08/0.35/0.30`; Bite `0.28/0.08/0.42/0.35` | chain advances on acceptance; Mobbing remains armed through whiff/interruption and is consumed only by the next landed primary; airborne request rejection |
| C4 | Chorus Frog | Tongue `0.25/0.06/0.38/0.30` | tongue-tip contact, shaft miss and visible whiff recoil |
| C4 | Great Blue Heron | Spear `0.45/0.10/0.55/0.45`; `1.4 s` cadence `LOCKED` | planted body, neck coil, width-aware line, release/recoil, invalid air/perch request |
| C4 | Cane Toad | channel startup `0.30`; pulse `0.25`; exit `0.25` | live-aim constraint, ammo drain, no repeated startup, release/stun cleanup |
| C5 | Snapping Turtle | Bite `0.70/0.10/0.75/0.55` | replace ad hoc windup; Bite/Grab variant snapshot; startup stun interrupts |
| C5 | Water Snake | Bite `0.24/0.08/0.40/0.35` | bleed once; active-hit latch; suppression/real-release; ingestion independent |
| C5 | Otter | Bite `0.24/0.08/0.40/0.35` | automatic latch; Gang Up consumes only on valid latchable hit |
| C5 | Wolf Spider | Bite Lunge `X 0.00/0.16/0.08/0.45/0.35`; Burrow Charge `X 0.30/0.16/0.08/0.55/0.45` | travel itself is authoritative startup warning; locked dash and aim; contact after travel; latch/release; target-backed burrow emergence |
| C6 | Leech | release `0.30/0.06`; released `0.20`; interrupted `0.30` | resource spent at release; attach, reveal and damage-over-time remain projectile-owned |
| C6 | Firefly | release `0.24/0.06`; released `0.18`; interrupted `0.28` | release at active; reveal, homing and harvesting remain projectile-owned |
| C7 | Owl | Peck `D 0.25/0.08/0.42/0.35`; Swoop `X 0.25/0.20/0.12/0.65/0.50` | clipped target point, descent/contact, stealth break, low window and braking recovery |

`R4A-R4D` own every action for their named creatures, including retaliation,
fields, pets and finishers in `BATTLE_BOG_DAMAGING_ACTION_INVENTORY.md`.
`R4E-R4F` contain only the remaining creatures:

| Order | Creatures | Required Actions | Shared Owner And Focused Tests |
| --- | --- | --- | --- |
| R4E.1 | Beaver, Bog Turtle | Chomp; Headbutt/self-recoil/basking follow-up | one integration owner for roster/catalog; kit owners add `battle_bog_beaver_timeline_check.gd` and `battle_bog_bog_turtle_timeline_check.gd` |
| R4E.2 | Water Shrew, Mink | Bite/empowered Bite; Bite/Choke impact/countdown/execute ownership | integration owner moves Choke out of `Creature`; focused timeline checks for each |
| R4E.3 | Chorus Frog, Great Blue Heron | Tongue tip/shaft geometry; planted Spear line and recoil | shared line-geometry reviewer; separate creature timeline checks |
| R4E.4 | Snapping Turtle, Wolf Spider | Bite/Grab; Bite Lunge/Burrow Charge/latch/Spiderling | one dash/latch integration owner; separate creature and pet timeline checks |
| R4F.0 | Otter | Bite/latch and Tail Whip only | may proceed before `R4H`; no Gang Up cohort behavior or final Otter assets |
| R4F.2 | Leech | primary projectile/attachment and Sensory Crypt | follows R4E.4 independently of Otter; projectile helper already proven at R4A |
| R4F.1 | Otter | Gang Up cohort only | starts after `R4H`; reuses proven Bite/latch and dedicated Otter timeline check |

The integration owner alone edits `Creature`, catalog, roster data and shared
helpers. Kit/test owners work only in the named creature files. Each order row
passes its focused checks, existing creature-wave compatibility tests and the
full strict suite before the next row.

### R4 Verification Commands

Exact implementation write sets:

| Slice | New Shared Files | Existing Implementation Files |
| --- | --- | --- |
| R4A | `scripts/sim/combat/projectile_release_resolver.gd` | `scripts/sim/kits/mosquito_swarm.gd`, `scripts/sim/kits/firefly.gd`, `scripts/sim/entities/mosquito_projectile.gd`, `scripts/sim/entities/mosquito_field.gd`, `scripts/sim/entities/firefly_projectile.gd`, `scripts/sim/creature.gd`, `data/battle_bog_roster.json`, `scripts/data/creature_catalog.gd`, `scripts/test/battle_bog_wave3_mosquito_swarm_check.gd`, `scripts/test/battle_bog_wave3_firefly_check.gd` |
| R4B | `scripts/sim/combat/attack_alternation_context.gd` | `scripts/sim/kits/newt.gd`, `scripts/sim/kits/crayfish.gd`, `scripts/sim/kits/duck.gd`, `scripts/sim/pets/duckling.gd`, `data/battle_bog_roster.json`, `scripts/data/creature_catalog.gd` |
| R4C | `scripts/sim/combat/timeline_melee_resolver.gd`, `scripts/sim/combat/latch_followup.gd` | `scripts/sim/kits/alligator.gd`, `scripts/sim/kits/bullfrog.gd`, `scripts/sim/kits/water_snake.gd`, `data/battle_bog_roster.json`, `scripts/data/creature_catalog.gd` |
| R4D | `scripts/sim/combat/aerial_strike_context.gd` | `scripts/sim/kits/kingfisher.gd`, `scripts/sim/kits/owl.gd`, `scripts/sim/kits/cane_toad.gd`, `data/battle_bog_roster.json`, `scripts/data/creature_catalog.gd`; channel remains Cane-Toad-local |
| R4E.1 | none | `scripts/sim/kits/beaver.gd`, `scripts/sim/kits/bog_turtle.gd`, `data/battle_bog_roster.json`, `scripts/data/creature_catalog.gd` |
| R4E.2 | none | `scripts/sim/kits/water_shrew.gd`, `scripts/sim/kits/mink.gd`, `scripts/sim/creature.gd`, `data/battle_bog_roster.json`, `scripts/data/creature_catalog.gd` |
| R4E.3 | `scripts/sim/combat/line_contact_resolver.gd` only if both contracts require identical line semantics | `scripts/sim/kits/chorus_frog.gd`, `scripts/sim/kits/great_blue_heron.gd`, `data/battle_bog_roster.json`, `scripts/data/creature_catalog.gd` |
| R4E.4 | none | `scripts/sim/kits/snapping_turtle.gd`, `scripts/sim/kits/wolf_spider.gd`, `scripts/sim/pets/spiderling.gd`, `data/battle_bog_roster.json`, `scripts/data/creature_catalog.gd` |
| R4F.0 | none | `scripts/sim/kits/otter.gd`, `data/battle_bog_roster.json`, `scripts/data/creature_catalog.gd`; excludes Gang Up cohort |
| R4F.2 | reuse `scripts/sim/combat/projectile_release_resolver.gd` | `scripts/sim/kits/leech.gd`, `scripts/sim/entities/leech_projectile.gd`, `scripts/sim/creature.gd::apply_dot`, `data/battle_bog_roster.json`, `scripts/data/creature_catalog.gd` |
| R4F.1 | `scripts/sim/combat/otter_cohort_context.gd` | `scripts/sim/kits/otter.gd`, `data/battle_bog_roster.json`, `scripts/data/creature_catalog.gd` |

Each named focused test is a required new file. Run the block for the current
slice, then the standard closeout block.

```powershell
# R4A
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_projectile_release_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_mosquito_swarm_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_firefly_timeline_check.gd' -KeepGoing -StrictOutput

# R4B
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_attack_alternation_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_newt_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_crayfish_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_duck_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_duckling_timeline_check.gd' -KeepGoing -StrictOutput

# R4C
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_timeline_melee_resolver_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_latch_followup_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_alligator_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_bullfrog_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_water_snake_timeline_check.gd' -KeepGoing -StrictOutput

# R4D
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_aerial_strike_context_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_kingfisher_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_owl_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_cane_toad_timeline_check.gd' -KeepGoing -StrictOutput

# R4E.1-R4F.2, run only the row being implemented
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_beaver_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_bog_turtle_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_water_shrew_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_mink_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_chorus_frog_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_great_blue_heron_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_snapping_turtle_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_wolf_spider_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_spiderling_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_otter_timeline_check.gd' -KeepGoing -StrictOutput
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_leech_timeline_check.gd' -KeepGoing -StrictOutput
```

Each slice adds one manifest scenario per normalized `action_id`. Creature-level
`<creature>_player_camera_attack` scenarios remain summary indexes and never
substitute for channel, retaliation, field, child or lifecycle evidence.

```powershell
$slice = "<slice>"
$attemptToken = "<attempt-token>"
$contracts = Get-ChildItem "docs\action-contracts\*.json" |
    ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json } |
    Where-Object { $_.r4_slice -eq $slice }
foreach ($contract in $contracts) {
  foreach ($scenario in $contract.scenario_ids) {
    $captureId = "r4-$slice-$($contract.action_id)-$scenario-$attemptToken"
    .\scripts\test\run_visual_regression.ps1 -Scenario $scenario -RunId $captureId -Capture
    .\scripts\test\battle_bog_visual_capture_artifact_check.ps1 `
        -ArtifactRoot "artifacts\visual-regression\$captureId" `
        -Scenario $scenario `
        -RequiredAnchors ($contract.required_anchors -join ",")
  }
}
```

Each capture root must contain non-empty
`<scenario>.frame_<frame>.png` and matching `.json` for every captured frame,
including every class-specific named anchor and its written capture window.
JSON must report scenario ID, action ID, seed, camera preset, simulation tick,
action phase/outcome, projected shape, contact truth, source/child ownership and
teardown truth. Missing or mismatched pairs fail the slice.

Standard closeout for `<slice>`:

Use the fail-closed command/artifact contract in
`BATTLE_BOG_WEAK_MODEL_EXECUTION_RUNBOOK.md`. The canonical closeout root is
`artifacts/combat-migration/r4-<slice>-<attempt-token>/`; every command result,
focused log, capture index and hash is copied there before another command can
overwrite shared logs.

Create one scoped commit only after those logs pass. Then write its full SHA to
`commit.txt`. R4 produces no promoted visual baseline; each procedural capture
remains under
`artifacts/visual-regression/r4-<slice>-<action-id>-<scenario>-<attempt-token>/`.

Wave promotion rule:

1. shared helper tests pass;
2. both named semantic consumers pass focused and compatibility tests:
   Mosquito+Firefly, Newt+Crayfish, Alligator+Bullfrog,
   Alligator+Water Snake, or Kingfisher+Owl as applicable;
3. independent review confirms semantic fit;
4. remaining wave creatures may proceed in parallel;
5. full strict suite and visual evidence pass before the next wave.

## Movement And Visual Production Waves

These waves are grouped by anatomy and medium, independently of combat waves.

| Visual Wave | Creatures | Shared Problem |
| --- | --- | --- |
| V0 | Alligator | grounded/shoreline long body, Ambush, latch, heavy contact |
| V1 | Kingfisher, Mosquito Swarm | pipeline stress: altitude/dive and distributed body |
| V2 | Owl, Great Blue Heron, Duck, Firefly | flight, banking, landing, height and low windows |
| V3 | Water Snake, Newt, Snapping Turtle, Bog Turtle | long/low bodies, paddle/slither, shoreline and submergence |
| V4 | Water Shrew, Beaver, Otter, Mink | mammal scurry/bound/lumber/slide, surface and underwater transitions |
| V5 | Bullfrog, Chorus Frog, Cane Toad, Crayfish, Wolf Spider, Leech | hop/coil, lateral or anchor gait, low-body direction and attack organs |

## Per-Creature Signature Evidence

Every row is additional to the universal Definition of Done.

| Creature | Required Signature Evidence | Research State |
| --- | --- | --- |
| Bullfrog | heavy coil/hop, swim, Leap, Lunge, camouflage break and execute | partial exact/proxy evidence |
| Chorus Frog | skitter-hop, ordinary travel, water entry, tongue-tip contact, Comb Call and Cree | `RESEARCH` exact travel/entry open |
| Newt | crawl, hybrid shoreline, swim, alternating tail, flip, reflection and tail loss | family transition evidence available |
| Cane Toad | squat hop, stream aim/ammo, Toxic Skin and rooted Thanatosis | exact hopping evidence available |
| Snapping Turtle | plod, swim, head retraction, neck strike, Grab/pull, lure and shell region | strike evidence strong; full locomotion partial |
| Water Snake | head-led land slither/swim, coil, drag direction, Musking and ingestion | swimming evidence strong proxy |
| Bog Turtle | creep, paddle, shore transition, bask attachment, flowers and Umbrella mount | `RESEARCH` paddle/transition open |
| Alligator | rest, high walk, turn, reverse, shore, swim, Ambush, Bite outcomes, latch, Death Roll and death | walk evidence strong; implementation pilot |
| Owl | Great Horned Owl perch, takeoff, glide, silent state, swoop, impact, low window, braking and landing | identity locked; `RESEARCH` exact-species ordinary post-strike recovery open |
| Great Blue Heron | stalk, wade, planted coil, spear release/recoil, Powder Puff and Flushing | exact-species fixed-rate strike sequence available |
| Kingfisher | perch, hover/head lock, dive corridor, descent, submerge, emerge, reset and nest | exact-species state order strong; `RESEARCH` frame timing remains open |
| Duck | waddle, paddle, takeoff, alternating primary, nesting, ducklings and Mobbing | paddling evidence strong |
| Water Shrew | staccato scurry, surface run, submerge/emerge, bite stacks and invulnerability | exact pursuit evidence strong |
| Beaver | lumber, surface/underwater turn, object transport, Tail Slap, dam placement and Gnaw | turn evidence strong; `RESEARCH` species-confirmed loaded turn partial |
| Otter | pack spacing, land slide, swim, latch, Tail Whip and Gang Up | swim evidence strong |
| Mink | land bound, hunt, fixed-camera water entry/exit, Choke mass cases and scent field | fixed-camera transition evidence strong; species identity geographically inferred |
| Leech | inchworm, undulate, spontaneous transition, release, attachment, growth and detection | gaits strong; `RESEARCH` transition open |
| Crayfish | lateral scuttle, tail preparation/flip, alternating claws, display and molt | high-quality timing evidence available |
| Mosquito Swarm | stable envelope, travel deformation, attack-edge concentration, blood states, field, trail and deposit | 3D swarm evidence strong |
| Wolf Spider | freeze/skitter, pounce/latch, burrow entry/charge/ambush, trap and spiderlings | `RESEARCH` prey ambush open |
| Firefly | independent hover paths, flash synchronization, following reveal and glowworms | open trajectories/dataset strong |

## Movement Research Gap Closure

Open research never blocks simulation, fixtures or the procedural diagnostic
fallback. It blocks only the named final animation brief or asset gate.

| Gap | Evidence Required To Close | Owner | Blocks |
| --- | --- | --- | --- |
| Chorus Frog travel/entry | exact species; overhead and side views; uninterrupted land approach, last ground contact, first water contact and first stable paddle | research lane | final Chorus Frog V5 motion brief |
| Bog Turtle gait/shore | overhead walk on firm and saturated substrate, underwater paddle, continuous approach-to-float-to-paddle shot | research lane | final Bog Turtle V3 gait and shoreline animation |
| Beaver loaded turn | species-confirmed North American beaver pickup, carried-object turn, obstacle clearance, release and recovery | research lane | carried-object portion of Beaver V4; base swim turn may proceed |
| Kingfisher phase duration | high-frame-rate Belted Kingfisher perch/hover/plunge/submerge/emerge/reperch chain with stable frame rate | research lane | final V1 dive animation timing; state order may proceed |
| Owl recovery | Great Horned Owl identity locked; fixed-camera exact-species strike through ordinary landing or lift-off | research lane | final Owl V2 recovery brief |
| Wolf Spider burrow ambush | verified Lycosidae, natural prey trigger, concealment, emergence, contact or miss and retreat/reset | research lane | final V5 burrow-attack motion; ground pounce may proceed |
| Medicinal Leech transition | exact species, visible front/rear suckers, last dual anchor, rear release, separation and first complete traveling wave; reverse transition too | research lane | final Leech V5 crawl/swim transition |

`RESOLVED HUMAN GATE - Owl species identity (R14A, 2026-07-28):` Great Horned
Owl (`Bubo virginianus`). Final anatomy uses that species only. Great Gray,
Barn and Barred Owl evidence may inform shared owl function, never anatomy.

`RESOLVED HUMAN GATE - Otter pack identity (R4H, 2026-07-28):` North American
River Otter (`Lontra canadensis`), three independently targetable 300 HP bodies,
one shared stock lost only after all three bodies fall, no mid-stock body
respawn, `6 u` legal Gang Up route, visible pounce and hidden technical rescue
only. The normative detailed contract is in
`BATTLE_BOG_DAMAGING_ACTION_INVENTORY.md` and roster data.

## Shared Scenario Catalog

Every creature:

- identity and eight-way heading;
- idle, start, travel, tight turn, reverse and stop;
- attention change without travel change;
- primary hit, whiff and interruption;
- released recovery when semantically possible;
- damage, death and respawn;
- player-controlled PvAI duel;
- autonomous inactive-squad behavior;
- competitive 3v3 cohort;
- blue/red team;
- day/dusk/night;
- grayscale, protanopia, deuteranopia and tritanopia.

Capability additions:

| Capability | Extra Scenario |
| --- | --- |
| shoreline | dry, mud, shallow, deep, entry, exit and emergence |
| flight | takeoff, high travel, aim change, descent, low window, impact and landing |
| submergence | surface marker, hidden body, warning, reveal and emergence |
| latch | acquire, hold, victim movement, suppression, real release, death and invalid target |
| stealth | enter, travel, warning, break and reveal |
| construction | preview, legal/illegal placement, finished object and pathing pressure |
| summon | birth, ownership, overlap, death and density pressure |
| field | placement, active boundary, overlap, expiry and visibility |
| weakpoint | closed, warning, open, hit, close and death interruption |
| distributed body | envelope, individuals, direction shift, contact edge and resource state |

## Camera, Raster And Human Gates

- PvAI duel: `1280 x 720`, zoom `2.6`.
- Competitive evidence: `1280 x 720`, zoom `2.2`.
- Diagnostic and evaluator captures use the same seed and camera.
- Evaluator captures contain no phase, outcome or answer labels.
- Visible contact is within four pixels of gameplay contact.
- Visual event timing is within one 60 Hz tick.
- Ordinary warning direction is recognized before active with the existing
  thresholds in `BATTLE_BOG_VISUAL_VALIDATION_SPEC.md`.
- All absolute and relative performance numbers remain record-only until target
  hardware, build type, VSync, quality mode and minimum framerate are selected.
  Visual truth, deterministic event alignment and missing-artifact failures
  remain hard gates.
- Alligator candidate elimination uses eight participants and 20 randomized
  blinded trials per critical task.
- Final release validation uses 12 participants and 20 trials per critical
  task.
- Store participant IDs, randomization order, calibrated reaction-time deltas,
  exclusions, pipeline-blindness confirmation, answers and a separate answer
  key.

## Subagent Operating Model

Use all available concurrency through bounded four-role slices. If the runtime
supports fewer concurrent agents, preserve role order across sequential waves;
if it supports more, duplicate only disjoint creature/research lanes, never
shared-file ownership.

### Shared-Infrastructure Slice

1. core implementation owner;
2. focused test/fixture owner;
3. presentation/research translator;
4. adversarial reviewer.

`Creature`, `Arena`, catalog loading and shared validation files have one owner
per slice. Other agents do not edit them concurrently.

### Creature Pair Slice

1. creature A kit plus new focused tests;
2. creature B kit plus new focused tests;
3. roster-data and PvAI integration for both;
4. independent semantic review and capture audit.

Only disjoint creature files are edited concurrently. The integration owner
alone edits centralized roster, `Creature`, `Arena`, manifests or shared helpers.

### Visual Family Slice

1. movement/presentation implementation;
2. asset/adapter implementation;
3. deterministic scenarios and semantic evidence;
4. biological and readability cross-exam.

Each wave ends with a clean checkpoint commit before the next wave starts.

## Autonomy Rules

Every slice begins from the exact scope, checkout and attempt rules in
`BATTLE_BOG_WEAK_MODEL_EXECUTION_RUNBOOK.md`. A discovered bug may be fixed in
the current slice only when its cause and every changed file are already inside
that slice's declared write set and the fix preserves the named contract.
Otherwise record it and stop for a corrective slice. Do not resolve authority
conflicts, alter balance, refactor adjacent systems, promote baselines or infer
a human/rights decision.

The implementation should continue without asking when:

- this roadmap provides a prototype timing;
- a helper can preserve existing behavior while adding truthful phases;
- focused tests reveal an ordinary bug within the current slice;
- research is incomplete but the procedural diagnostic fallback remains honest;
- a capture needs framing, text-fit or deterministic corrections.

Pause for user input only at:

1. `R2BH` initial procedural baseline truth approval;
2. `R4H` Otter pack identity;
3. `R10` victory/defeat/soak review approvals;
4. `R10A` shared Alligator concept/source rig approval;
5. `R12` candidate comprehension/elimination;
6. `R12H` target-hardware contract or record-only confirmation;
7. `R14` visual-pipeline selection;
8. `R14A` Owl species identity;
9. `R17B` final human comprehension approval;
10. another identity-changing gameplay redesign;
11. a balance choice that cannot preserve current behavior;
12. a legal or rights ambiguity affecting intended asset reuse.

When research is incomplete, continue simulation and fixture work. Do not lock
the final animation brief or claim human acceptance.

## Exact Execution Queue

```text
[complete] R0 code foundation at 9e211c8; minimum plan ancestor 710b5d4
[next]     R0.5 conform Alligator/shared frame data to locked Decisions #23-26
[next]     R1A split-step movement integration
[next]     R1B immutable presentation snapshot and compatibility adapter
[next]     R2A real Arena fixture + PvAI/3v3 camera presets + capture modes
[next]     R2B semantic output + comparator + synthetic/refusal tests
[human]    R2BH approve one exact procedural source run as baseline truth
[next]     R2B.2 promote only the approved baseline and rerun comparator/full suite
[next]     R2C full procedural Alligator player-camera/shoreline evidence
[next]     R2D expanded screenshot-free performance runner and telemetry artifacts
[next]     R2E snapshot-only visual-adapter boundary
[next]     R2F blinded-review packager, trial manifests and separate answer keys
[complete] R3 discover every damaging action and define P1-P5 prototype policies
[next]     R3.5 normalize every action/child contract and pass independent completeness review
[next]     R4A projectile adapter with Mosquito then Firefly
[next]     R4B alternation context with Newt then Crayfish; migrate Duck
[next]     R4C melee extraction with Alligator then Bullfrog; narrow latch with Water Snake
[next]     R4D aerial context with Kingfisher and Owl; Cane Toad channel remains kit-local
[next]     R4E migrate Beaver/Bog Turtle, Water Shrew/Mink, Chorus/Heron, Snapping/Wolf Spider
[next]     R4F.0 migrate Otter Bite/latch/Tail Whip without Gang Up cohort
[next]     R4F.2 migrate Leech after R4E.4
[human]    R4H select Otter Gang Up cohort, health, travel and control-transfer rules
[next]     R4F.1 implement approved Otter Gang Up cohort
[next]     R5 pass focused/full strict tests and freeze combat structure/API
[next]     R6 run/review StageB5; classify every anomaly before promotion
[next]     R7 run/review StageB15 and throughput optimization without checksum drift
[next]     R8 run/review StageCMain
[next]     R9 classify misses, then run/review StageCExtended
[human]    R10 record PvAI victory, defeat and 21+ minute soak; clear every S0/S1
[next]     R10.5 freeze gameplay content after the final clean R6-R10 loop
[human]    R10A approve the shared Alligator concept/source rig used by all four candidates
[next]     R11 build four Alligator visual adapters and automated evidence
[human]    R12 blinded Alligator comprehension/elimination; retain at least two
[human]    R12H lock target hardware/build/renderer/VSync/quality/minimum FPS or keep numerical performance record-only
[next]     R13 test survivors on Kingfisher, Mosquito and mixed 3v3
[human]    R14 select roster default visual pipeline and documented exceptions
[human]    R14A select playable Owl species and record it in roster/research
[research] R14B close or formally defer each movement-gap row before its V-wave
[next]     R14C finalize/package selected V0 Alligator and V1 Kingfisher/Mosquito
[next]     R15 complete visual waves V2-V5 in dependency order
[next]     R16 complete 21-creature camera, accessibility and visual/PvAI evidence matrix
[next]     R17A automated mixed-3v3 truth/performance release gate
[human]    R17B twelve-participant mixed-3v3 comprehension release gate
```

Immediate implementation begins at `R0.5`, then `R1A` and `R1B`. All
gameplay-affecting combat migration finishes and its structure freezes at `R5`
before the locked PvAI sequence at `R6-R10`. Any tuning change loops through
focused/full tests and restarts at R6. Content freezes only at `R10.5`. No
visual adapter production starts before
that gate passes. Shared behavior is extracted only alongside the named second
consumer, so no generalized adapter is invented in isolation.

At `R14B`, unavailable evidence defers only the affected creature's final
animation brief. Keep its truthful procedural fallback, proceed with other
wave members, and leave that creature `INCOMPLETE`; never fill the gap with an
unsupported biological claim. A deferral cannot pass R16 or R17. Before release,
each row must close. Releasing fewer than all 21 creatures requires a separately
approved roadmap version and is outside this plan.
