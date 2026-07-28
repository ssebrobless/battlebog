# Battle Bog Visual Validation Specification

Status: implementation specification, thresholds provisional until baseline run

Compiled: 2026-07-27

## Validation Shape

```text
DETERMINISTIC SCENARIO MANIFEST
              |
              v
NORMAL GODOT LOOP
1280 x 720 | Mobile | fixed 60 Hz
              |
       +------+------+
       |      |      |
       v      v      v
      PNG   state   performance
    sequence  JSON    samples
       |      |      |
       +------+------+
              |
              v
PIXEL GATES + SEMANTIC GATES + HUMAN COMPREHENSION
```

Headless state tests remain necessary. They do not prove final rendered
readability.

## Existing Foundation

- project resolution and Mobile renderer are already configured;
- match randomness has an injectable simulation seed;
- the performance harness uses the normal main loop;
- Alligator, Kingfisher and Mosquito have useful deterministic state checks;
- height, shadow and airborne-warning dictionaries already have substantial
  test coverage;
- current PvAI zoom is `2.6`;
- current competitive 3v3 zoom is `2.2`.

Current limitations:

- the standard suite invokes headless `SceneTree` test scripts;
- the performance harness warms for only five frames and lacks percentiles;
- current creature checks manually tick logic and inspect dictionaries;
- there is no formal simple/expanded HUD API;
- deterministic neutral-fixture capture plumbing exists, but the gameplay
  fixture matrix, baseline comparator and performance sampler remain open.

## Capture Contract

Primary:

- `1280 x 720`;
- Mobile renderer;
- fixed simulation seed;
- fixed tick rate and render clock;
- fixed camera;
- PNG plus adjacent state JSON;
- exact scenario and frame identity in a manifest.

Run the primary fixture matrix at PvAI zoom `2.6`. Repeat the six-creature and
HUD stress fixtures at 3v3 zoom `2.2`.

Every attack capture includes 30 frames before warning and continues through
recovery. Frame names are authoritative-event-relative:

```text
TEL+0
HIT-1
HIT+0
RECOVERY+0
```

They are not guessed animation timestamps.

## Fixture Matrix

| Fixture | Required Evidence |
| --- | --- |
| Alligator | rest, start, walk, tight turn, reverse, shore entry, swim, bite phases, hit/whiff recovery, latch and death roll |
| Kingfisher | grounded, hover, high flight, aim change, dive warning, descent, low window, impact, miss and recovery |
| Mosquito | idle envelope, travel deformation, attack-edge concentration, release, resource states, trail and field |
| Six creatures | spread, convergence, three simultaneous attacks, peak effects, reacquisition and aftermath |
| Shoreline | dry, mud, shallow, deep, entry, exit, submerged warning and emergence |
| Lighting | identical state at day `0.30`, dusk `0.60`, night `0.85` |
| HUD | simple, contextual and expanded; calm and crowded |
| Accessibility | native, grayscale, protanopia, deuteranopia and tritanopia |

## Automated Raster And Semantic Gates

These are initial thresholds. The first procedural baseline run may reveal that
a threshold is platform-unstable; any revision must be documented rather than
silently weakening the gate.

Measurement definitions:

- body width/height use the tight opaque-body bounds and exclude shadow, truth
  ring, telegraph and detached particles;
- extremities are reported both included and excluded when they materially
  change the bound;
- long-body length uses maximum projected head-to-tail span in the named
  orientation;
- world prop occupancy uses segmented pixel area inside a declared central
  combat region;
- walkable-floor percentage uses gameplay navigation/collision area, not color
  segmentation;
- every percentage records viewport, zoom, orientation and measurement region.

| Gate | Starting Threshold |
| --- | --- |
| Raster contract | exactly `1280 x 720`, correct renderer/seed/tick/camera and no missing capture |
| Same-machine baseline | full-frame MAE `<= 0.010`; critical ROI SSIM `>= 0.985`; RGB delta `> 0.08` on `<= 1%` of pixels |
| Body occupancy | ordinary width `4-7%`, height `5-10%`; authentic long bodies `8-16%` |
| Timing alignment | visual phase within one 60 Hz tick of simulation event |
| Contact truth | visible contact within four pixels of gameplay contact |
| Direction continuity | head/contact point jump below `25%` of body radius per frame |
| Occlusion | truth hidden no longer than `250 ms` ordinary or `500 ms` signature |
| Shoreline | four depth bands distinguishable; shallow mask roughly `15-30%` |
| Night | median terrain value falls `20-30%`; creature/warning contrast regression under `10%` |
| Color vision | critical symbol/background contrast at least `3:1`; meaning also differs by shape/pattern |
| Simple HUD | no overlap; at most `18%` of frame and `5%` of central playfield |
| Expanded HUD | no overlap; at most `30%` of frame and `15%` of central playfield |

Store raster baselines by:

- Godot version;
- renderer;
- operating system;
- GPU.

Cross-machine runs use semantic thresholds. They do not fail solely on raw
raster differences. Baseline promotion is always explicit.

## Human Protocol

Iteration:

- eight participants;
- twenty randomized trials per critical task.

Release gate:

- twelve participants;
- twenty randomized trials per critical task.

Begin with ten neutral reaction-time trials. Retain both raw response and each
participant's calibrated delta.

Starting human-comprehension pass thresholds:

| Task | Threshold |
| --- | --- |
| Species recognition | `>=95%` isolated; `>=90%` in six-creature combat |
| Heading | `>=90%` within one adjacent eight-way sector |
| Phase classification | `>=85%` startup/active/recovery |
| Ordinary threat | `>=80%` correct direction; `>=75%` before active; median margin `>=100 ms` |
| Kingfisher low window | `>=85%`; false positive `<10%`; median margin `>=120 ms` |
| Mosquito attack edge | `>=85%` |
| Target reacquisition | `>=90%` within `1.0 s` after effect peak |
| Medium/height state | `>=95%` without HUD labels |
| Simple-HUD answer | `>=90%` within `2.5 s` |
| Expanded strategic answer | `>=90%` within `4 s` |
| Team under simulated CVD | `>=95%` |

Color-vision simulation is an automated guard. It does not replace testing with
participants who have real color-vision differences.

## Performance Protocol

For every candidate/scenario:

- five runs;
- 300 warm-up frames;
- 1,800 measured frames;
- screenshot readback disabled during performance measurement.

Record:

- `p50`, `p95`, `p99` and worst frame time;
- count over `33.3 ms`;
- draw calls and primitives;
- video and process memory;
- node and resource counts;
- scenario identity.

Until target hardware, build type, VSync, quality mode and minimum framerate
are selected, these are record-only targets rather than hard release gates:

- `p95 <= 16.67 ms`;
- `p99 <= 20 ms`;
- fewer than three frames over `33.3 ms`;
- `p95` regression no more than `10%`;
- draw-call regression no more than `10%`;
- active trio adds no more than `96 MiB` video memory without an approved
  quality exception.

Visual truth, deterministic event alignment and missing-artifact failures remain
hard gates on every machine.

## Proposed Repository Layout

```text
scenes/test/VisualRegressionArena.tscn
scripts/test/visual/visual_regression_arena.gd
scripts/test/visual/scenario_catalog.gd
scripts/test/visual/image_metrics.gd
scripts/test/run_visual_regression.ps1
tests/visual/manifest.json
tests/visual/baselines/<platform>/
tests/visual/human_trials/
artifacts/visual-regression/<run-id>/
```

## Implementation Order

1. normal-loop fixture, render clock and manifest;
2. neutral smoke capture and failure behavior;
3. Alligator state captures;
4. comparator and explicit baseline workflow;
5. Kingfisher event-relative clips and reaction runner;
6. Mosquito and six-creature stress;
7. shoreline, day/night and color-vision transforms;
8. formal HUD modes and HUD trials;
9. expanded performance harness and CI tiers.

## Human Trial Independence

Before release-gate data is accepted, define:

- who recruits and facilitates participants;
- whether multiple trials from one participant are repeated measures rather
  than independent people;
- randomization and counterbalancing;
- exclusion criteria and accessibility information collected;
- whether the evaluator knows which rendering pipeline produced a clip.

Pipeline comparisons should be blinded whenever practical.
