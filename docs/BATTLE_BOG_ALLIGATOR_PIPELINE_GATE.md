# Battle Bog Alligator Pipeline Gate

Status: simulation, presentation-data prerequisites and the procedural
diagnostic prototype implemented; gameplay evidence and four-way decision open

Compiled: 2026-07-27

## Gate Shape

```text
ONE ALLIGATOR DESIGN + ONE TIMING CONTRACT
                    |
        +-----------+-----------+------------+
        |           |           |            |
        v           v           v            v
  pre-rendered   live 3D     subtle 2D    hand-authored
     atlas                      rig         key poses
        |           |           |            |
        +-----------+-----------+------------+
                    |
                    v
      SAME 1280 x 720 3v3 TEST + METRICS
```

The gate compares visible results and production consequences. It does not
select a winner from theoretical convenience.

## Current Implementation Boundary

The attack simulation prerequisite, presentation-data bridge and procedural
diagnostic pose consumer are implemented. Equivalent authored pipeline
candidates are not.

- `Creature._draw()` builds presentation data and delegates body drawing to
  `VisualStyle`.
- `Creature` owns the shared primary-attack timeline and exports phase,
  progress, sequence, authoritative ticks, outcome and locked strike heading.
- Alligator Bite uses roster-authored startup, active and recovery timing.
  Damage resolves exactly once on active rather than on the request tick.
- Alligator's sequence-bound presentation sidecar publishes a projected startup
  shape and the authoritative active shape/contact point.
- Arena telegraphs use that locked geometry and remove stale, completed or
  interrupted timeline-owned warnings.
- switch and routing suppression are distinguishable from intentional release,
  preserving committed attacks and valid latch behavior.
- timeline-owned Bite events do not activate the old generic windup/attack
  animation timers.
- `get_render_motion_state()` still exposes water, ambush, high walk, latch,
  death roll, model scale, height, transition and weakpoint information.
- `VisualStyle` consumes the Bite timeline as distinct startup, active,
  hit-recovery, whiff-recovery and interrupted-recovery poses, with latch and
  Death Roll priority.
- dead creatures still stop drawing immediately; start, reverse and signed turn
  rate are not explicit presentation fields.

The authored presentation consumes simulation state. It never moves collision,
decides hit timing, applies root motion or changes deterministic outcomes.

## Current Gate Status

Complete:

- deterministic capture clock, runner, PNG/state output and metadata plumbing
  for the neutral smoke and diagnostic Alligator attack-reel scenarios;
- ordinary attack timeline and deterministic active-tick resolution;
- committed melee build/query/resolve with a compatibility wrapper;
- Creature timeline ownership and optional roster-data validation;
- switch/input suppression provenance;
- Alligator simulation migration, PvAI continuity and sequence-bound
  presentation/telegraph bridge;
- procedural Bite timeline poses and focused pose-contract tests;
- deterministic diagnostic attack reel with repeated matching captures;
- focused state tests for those behaviors.

Open:

- player-camera Alligator gameplay, shoreline and density scenarios;
- complete canonical-state coverage beyond the diagnostic Bite reel;
- approved screenshot baselines and a semantic image comparator;
- the complete capture/performance fixture matrix;
- minimal water/foreground compositor proof;
- all four runtime pipeline adapters and equivalent candidate assets;
- blinded human visual protocol and pipeline selection.

No Alligator candidate has received human visual acceptance. The diagnostic
reel proves isolated pose readability and deterministic capture only; it does
not prove player-camera combat truth or satisfy the four-way gate.

## Next Implementation Wave

Proceed in this order. Each step preserves one simulation, telegraph and
presentation-snapshot contract for every visual candidate.

1. **Truthful player-camera fixture.** Add an Arena-backed Alligator, target,
   shoreline and real `Camera2D` scenario at the PvAI camera, then repeat it at
   the 3v3 camera. Capture every frame around warning, active contact and
   recovery boundaries, including projected shape, contact point and event
   ticks in state JSON.
2. **Canonical state and pressure fixtures.** Extend coverage through land
   movement, turn/reverse, shore entry/exit, swim, Ambush, Bite outcomes, latch,
   jaw hold, Death Roll and death. Add six-Alligator shoreline pressure and one
   mixed objective fight before judging production fitness.
3. **Comparison substrate.** Add explicit baseline promotion, repeated-run
   determinism checks, whole-frame delta metrics and semantic regions for
   silhouette, heading, telegraph footprint and contact point. Diagnostic
   overlays and answer labels remain separate from evaluator captures.
4. **One render-adapter boundary.** Route the four candidates: pre-rendered
   atlas, live 3D, subtle 2D rig and the existing hand-authored procedural key
   poses through the same snapshot and fixture interface. Candidate code may
   render state but cannot own timing, collision, root motion or outcomes.
5. **Equivalent evidence and performance.** Run every surviving candidate with
   identical source design, camera, timing, environment and capture frames,
   then execute the warm-up/measurement protocol below and package anonymous
   clips for comprehension review.
6. **Human selection.** Begin blinded trials only after at least two candidates
   satisfy automated truth, determinism and performance gates. Promote a
   pipeline only from combined readability, motion, environment fit,
   performance and iteration-cost evidence.

## Shared Presentation Snapshot

All four candidates receive:

```text
travel_heading
attention_heading
strike_heading
speed_t
signed_turn_rate
medium_transition_t
attack_phase
phase_t
hit_region
death_t
attack_sequence_id
attack_started_tick
attack_active_tick
attack_outcome
contact_point
projected_shape
interruption_reason
```

`attack_sequence_id`, `attack_started_tick` and `attack_active_tick` use the
canonical shared timeline names. `contact_point` and `projected_shape` are
nullable before active resolution.

Current availability:

- attack phase/progress, sequence, authoritative ticks, outcome, strike
  heading, hit region, interruption reason, projected shape and contact point
  are implemented;
- the projected shape is available during Alligator startup and refreshes from
  the actor's current origin while preserving locked aim;
- resolved shape/contact truth is published at active;
- travel heading, attention heading, signed turn rate, generalized
  medium-transition progress and `death_t` remain open.

Existing state such as water cruise, ambush posture, high walk, latch, death
roll, visual scale, height, weakpoint and terrain transition remains available.

Proposed boundary:

```text
Creature simulation
      |
      v
CreaturePresentationSnapshot
      |
      v
CreatureVisualDriver
      +--> AtlasVisual
      +--> Live3DVisual
      +--> Rig2DVisual
      +--> KeyPoseVisual

VisualStyle continues to own:
truth footprint | team ring | shadow | telegraph | weakpoint
hit flash | water disturbance | health/status | procedural fallback
```

## Canonical Alligator Contract

Initial timings:

| Clip Or State | Duration | Ownership |
| --- | ---: | --- |
| `idle` | `1.00 s` loop | presentation |
| `start` | `0.20 s` | velocity transition |
| `land_walk` | `0.72 s` loop | speed-normalized |
| `tight_turn` | `0.30 s / 90 deg` | signed turn rate |
| `reverse` | `0.32 s` | travel/body-axis conflict |
| `swim` | `0.80 s` loop | water cruise |
| `shore_enter` | `0.32 s` | terrain transition |
| `shore_exit` | `0.32 s` | terrain transition |
| `ambush_idle` | `1.00 s` loop | ambush state |
| `bite_startup` | `0.30 s` | simulation warning |
| `bite_active` | `0.10 s` | damage/latch event |
| `bite_recover_hit` | `0.40 s` | simulation recovery |
| `bite_recover_whiff` | `0.80 s` visible | simulation recovery; existing cooldown continues |
| `jaw_hold` | `0.60 s` loop | latch state |
| `death_roll` | `0.714 s` loop | existing `1.4` rotations/s |
| `target_hit_reaction` | `0.18 s` | target/body reaction; localized flash obeys the shorter VFX budget |
| `death` | `0.90 s` | presentation lifecycle |

These timings are prototype inputs. Playtest reaction and feel evidence may
change them before roster-wide adoption.

The Bite startup, active, hit, whiff and interrupted durations are live in the
Alligator roster data and covered by deterministic state tests. The remaining
clip rows are still visual-candidate requirements unless already supplied by
the existing procedural fallback state.

## Four-Way Asset Matrix

### Pre-Rendered 3D-To-2D

Asset contract:

- one master `.blend`;
- eight directions;
- trimmed frames within a provisional `256 x 192` frame box;
- RGBA atlases and optional normal atlases;
- manifest mapping clip, direction, frame, duration and event;
- linear filtering and mipmaps tested at normal camera.

Runtime:

- `AnimatedSprite2D` and `SpriteFrames`;
- phase explicitly synchronized from the presentation snapshot.

Current prior:

Lowest integration risk. Main threat is direction/state multiplication, atlas
size and video memory.

### Restrained Live 3D

Asset contract:

- the same master `.blend`, exported as `.glb`;
- one skinned mesh;
- provisional `5k-10k` triangles;
- `1k-2k` texture set;
- no gameplay collision and no root motion;
- imported clips retain canonical names.

Runtime:

- one arena-level transparent `SubViewport`;
- one orthographic `Camera3D`;
- synchronized 2D-to-3D stage;
- never one viewport per creature.

Current prior:

Best continuous turning and roster scaling. Main threats are water masking,
foreground sorting, material compatibility and the extra full-screen render
pass.

### Subtle 2D Rig

Asset contract:

- one painted `1k-2k` texture set;
- `Skeleton2D`;
- provisional 14-bone structure covering jaw, trunk, tail and limbs;
- weighted polygons preferred over visibly separated pieces.

Runtime:

- `AnimationPlayer` plus `AnimationTree`;
- continuous root heading driven from presentation state.

Current prior:

Strong long-body specialist. Immediate failure if seams, rubber bending or
paper construction are visible at gameplay scale.

### Hand-Authored Key Poses

Asset contract:

- eight directions;
- every canonical visible state listed in this gate, represented through
  authored poses and holds;
- provisional drawing count established after equivalent coverage is mapped;
- packed atlases;
- authored holds and controlled effects rather than automatic interpolation.

Runtime:

- `AnimatedSprite2D`.

Current prior:

Quality and pose-authority benchmark. It is not presumed scalable across all 21
creatures.

## Shared-Source Strategy

Use one approved Alligator concept and 3D rig for both pre-rendered and live-3D
candidates. Build hand-authored canonical poses first as the visible quality
bar. Derive the subtle 2D-rig texture from the same approved design.

This avoids comparing four different interpretations of the animal while still
producing four genuinely different runtime candidates.

Fairness controls:

- equivalent visible-state coverage;
- the same concept, camera, timing, scale and gameplay truth;
- the same maximum iteration count or authoring-hour budget;
- declared source-resolution and texture/atlas limits;
- blinded normal-camera evaluation before reviewers know the pipeline;
- shared 3D source work recorded as a production-efficiency advantage rather
  than hidden from the comparison.

## Fair Capture Matrix

Implementation status: open. The repository contains `neutral_smoke` plus a
diagnostic `alligator_attack_reel`. The reel uses a real attack timeline but
synthetic presentation inputs, fixed screen-space scale and explanatory
overlays, so it does not satisfy any player-camera candidate row below.

For every candidate at `1280 x 720`, Mobile renderer, fixed seed and camera:

1. one Alligator completing every canonical state;
2. six Alligators fighting around water and shoreline;
3. a normal mixed-creature 3v3 objective fight;
4. day, dusk and night passes;
5. truth footprint, capsule, heading, phase and contact-point debug captures.

Performance procedure:

- warm up for 300 frames;
- measure 1,800 frames;
- run enough repetitions to report the median run;
- record `p50`, `p95`, `p99` and worst frame time;
- record draw calls, primitives, texture/video/buffer memory and node/resource
  counts;
- record cold load, PCK growth and import duration;
- retime one attack and record turnaround effort.

## Failure Thresholds

Until minimum target hardware, build type, quality settings and framerate are
locked, performance values below are record-only comparison targets. Visual
truth and deterministic alignment remain hard failures.

A candidate fails the gate when:

- contact pose and hit event differ by more than one 60 Hz tick;
- visible head/contact point departs from gameplay truth by more than four
  pixels;
- an eight-direction change jumps the head over `25%` of body radius or
  chatters between sectors;
- ordinary effects hide positional truth beyond `250 ms`;
- the shared human protocol fails any separate threshold: heading below `90%`,
  attack-phase classification below `85%`, or shoreline/medium identification
  below `95%`, using twenty blinded randomized trials per task and participant;
- the 2D rig visibly resembles cutout construction;
- live 3D cannot sit naturally in water or behind foreground cover;
- close-up quality fails at the normal camera.

These human thresholds have not been run. Automated state, telegraph and
determinism checks are prerequisites, not substitutes for blinded visual
classification and reaction evidence.

Record until hardware is locked:

- `p95 > 16.67 ms`;
- `p99 > 20 ms`;
- `p95` regression beyond `10%`;
- active-trio video-memory growth beyond `96 MiB`.

## Primary Technical Sources

- [Motion Twin Dead Cells pipeline](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-):
  low-resolution 3D rigs rendered to 2D frames, normal maps and inexpensive
  animation retakes.
- [Klei 2D Animation](https://gdcvault.com/play/1020165/2D-Animation-at-Klei):
  symbols, atlasing, reuse and stategraphs as workflow evidence.
- [Supergiant Hades production](https://www.youtube.com/watch?v=cYJ6d1ifSqA):
  concept-to-model-to-rig quality path.
- [Godot viewports](https://docs.godotengine.org/en/4.6/tutorials/rendering/viewports.html):
  3D rendered into a 2D composition.
- [Godot SpriteFrames](https://docs.godotengine.org/en/4.6/classes/class_spriteframes.html):
  per-frame animation duration support.
- [Godot Skeleton2D](https://docs.godotengine.org/en/4.6/tutorials/animation/2d_skeletons.html):
  bone deformation option and triangulation risks.
- [Godot AnimationTree](https://docs.godotengine.org/en/4.6/tutorials/animation/animation_tree.html):
  2D and 3D animation control.
- [Godot performance monitors](https://docs.godotengine.org/en/4.6/classes/class_performance.html):
  frame, render and memory telemetry.

## Current Prior, Not Decision

```text
integration prior .......... pre-rendered atlas
roster-scaling prior ....... restrained live 3D
family-specific exception .. subtle 2D rig
quality-control benchmark .. hand-authored poses
```

The Alligator gate eliminates unsuitable candidates and carries at least two
viable candidates into Kingfisher. It does not select the roster-wide default.
The default, and any approved family-specific exceptions, are selected only
after Kingfisher, Mosquito and mixed 3v3 evidence.
