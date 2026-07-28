# Battle Bog Weak-Model Execution Runbook

Status: normative no-guess handoff for roster completion

Compiled: 2026-07-28

Minimum planning ancestor: `710b5d4`

Required execution tag: `battle-bog-roster-plan-v2`

Historical R0 code checkpoint: `9e211c8`

## Purpose

This runbook closes the operational and sequencing choices left by the
roster-wide roadmap. A lower-reasoning executor may discover facts, write code
inside a declared slice and repair failures inside that same write set. It may
not choose game design, balance, biological identity, visual direction, legal
rights, target hardware, baseline truth or human acceptance.

```text
discover fact from code/spec ---> implement written contract ---> verify
          |                              |                        |
          +-- conflict/absence ----------+---------------> BLOCKED
                                                           |
                         never infer a default <------------+
```

If two authorities conflict, record both exact paths/lines and stop. If a
required human decision is absent, package its evidence and stop at the named
gate. Stopping at a declared gate is correct execution, not an incomplete plan.

## Authority Order

1. locked rows in `docs/BATTLE_BOG_DECISIONS.md`;
2. the detailed authority document named by the roadmap for that system;
3. this runbook for execution and evidence rules;
4. `docs/BATTLE_BOG_ROSTER_WIDE_CHARACTER_COMPLETION_ROADMAP.md` for order;
5. current implementation for factual behavior not overridden above.

An executor never silently resolves a disagreement between these levels.

## Checkout Preflight

Run before every slice:

```powershell
$branch = git branch --show-current
$head = git rev-parse HEAD
git merge-base --is-ancestor battle-bog-roster-plan-v2 HEAD
if ($LASTEXITCODE -ne 0) { throw "Required plan tag is not an ancestor." }
$taggedRunbook = git show "battle-bog-roster-plan-v2:docs/BATTLE_BOG_WEAK_MODEL_EXECUTION_RUNBOOK.md"
if ([string]::IsNullOrWhiteSpace($taggedRunbook)) { throw "Tagged runbook is missing." }
$status = @(git status --porcelain=v1 --untracked-files=all)
if ($status.Count -ne 0) { throw "Worktree is not clean. Stop without changing it." }
```

Record branch, full HEAD SHA and empty status in the slice scope record. Never
check out or reset to `9e211c8`. Never stash, clean, reset, amend, rebase,
force-push, overwrite or include a pre-existing change.

The executor creates:

`artifacts/execution/<slice>/<attempt-token>/scope.json`

Canonical attempt token:

`<UTC-yyyyMMddTHHmmssZ>-<start-sha8>-aNN`

`aNN` begins at `a01` and increments for each retry. Artifact roots are
immutable and never reused, renamed or shared by concurrent executors.
Every `<run-id>` and `<trial-id>` in other documents means the bare
`<attempt-token>`; the surrounding command supplies its phase prefix exactly
once.

`scope.json` contains:

```text
schema_version=1     slice_id          attempt_token
branch               start_sha         dependencies
deliverables         write_set         forbidden_paths
commands             artifact_root     stop_conditions
```

## Scope And Concurrency

One integration owner edits centralized files: `creature.gd`, `arena.gd`,
catalog loaders, roster JSON, shared helpers, shared manifests and validators.
Creature owners use separate git worktrees/branches and edit only their named
kit/entity/test paths. The integration owner cherry-picks reviewed creature
commits one at a time, resolves centralized changes, runs canonical evidence
and creates the slice checkpoint.

Parallel executors never run canonical tests or captures in the same worktree.
`run_all.ps1` uses shared test-log names and is serialized by the integration
owner. A helper is promoted only after both named semantic consumers pass.

A discovered bug stays in the current slice only if its cause and every changed
path are inside the declared write set. Otherwise write `blocked.json` and
stop. No opportunistic refactor, tuning, identity change, final asset, baseline
promotion or adjacent cleanup is allowed.

## Command Result Contract

R0.5 first adds `scripts/test/run_checked_command.ps1` and
`scripts/test/battle_bog_checked_command_contract_check.ps1` before changing
gameplay. Its exact CLI is:

```powershell
.\scripts\test\run_checked_command.ps1 `
  -Executable <string> -Arguments <string[]> -TimeoutSec <int> `
  -ExpectedMarker <string> -CommandId <filename-safe-string> `
  -ArtifactRoot <existing-attempt-root>
```

`-ExpectedMarker ""` means no marker. The wrapper starts a child process,
captures stdout/stderr, terminates the full process tree at the wall timeout,
writes one result object and prints
`BB_CHECKED_COMMAND_OK id=<CommandId>` only on pass. All later required
commands use it. Raw command blocks in other documents are the exact payload
for `-Executable/-Arguments`, not permission to bypass the wrapper.

Bootstrap the wrapper contract itself with:

```powershell
$job = Start-Job {
  & .\scripts\test\battle_bog_checked_command_contract_check.ps1
}
if (-not (Wait-Job $job -Timeout 120)) {
  Stop-Job $job
  throw "Checked-command bootstrap contract timed out."
}
$bootstrapOutput = Receive-Job $job
if ($job.State -ne "Completed" -or
    $bootstrapOutput -notmatch "BB_CHECKED_COMMAND_CONTRACT_OK") {
  throw "Checked-command bootstrap contract failed."
}
Remove-Job $job
```

The bootstrap contract prints exactly `BB_CHECKED_COMMAND_CONTRACT_OK`.
Balance contract checks print
`BB_BALANCE_MATRIX_CONTRACT_OK` and
`BB_BALANCE_SUMMARY_CONTRACT_OK`. R6 may edit only those two existing contract
scripts to add the markers before StageB5; their assertions cannot change.

Wall-time table:

```text
focused test invocation       300 s
full run_all suite           5400 s
visual list/validate/capture  300 s
performance run              2400 s
headless boot                 300 s
git/diff/contract helper       60 s
StageB5                       600 s
StageB15                     1800 s
StageCMain                  28800 s
StageCExtended              14400 s
```

Run required commands serially. For each command record exact text, start/end
UTC, source-tree fingerprint, exit code, matched-test count, completion marker,
stdout/stderr log paths and strict-output issues in `command-results.json`.

Completion rules are exact:

```text
run_all.ps1          exit 0, at least one PASS table row, no non-PASS row
visual list          BB_VISUAL_LIST_COMPLETE
visual validate      BB_VISUAL_VALIDATE_OK
visual capture       BB_VISUAL_CAPTURE_COMPLETE
contract scripts     their documented BB_*_CONTRACT_OK marker
direct Godot         exit 0 within 300 wall seconds and no actionable error
git diff --check     exit 0 and empty output
```

Stop at the first:

- nonzero exit;
- harness or wall-clock timeout;
- `TIMEOUT` from `run_all.ps1`;
- missing completion marker;
- zero matched tests;
- actionable Godot error;
- missing, empty or invalid artifact;
- dirty path outside the slice write set.

A later pass cannot erase an earlier failure. Before each command, compute
`source_tree_fingerprint` from `git ls-files -co --exclude-standard`. Reject
reparse points. Exclude `.godot/` and `artifacts/`, normalize separators to
`/`, sort paths with ordinal case-sensitive comparison, and encode each record
as UTF-8 without BOM:

`<path>\0<lowercase-file-sha256>\0<byte-count>\n`

SHA-256 the concatenated record bytes. One diagnostic retry is allowed
on the identical source fingerprint, arguments and timeout in a fresh attempt
root. If the
cause is known and the retry passes, record it and rerun the whole gate once.
Unknown cause or a second timeout sets the gate to `BLOCKED`. Do not increase a
timeout merely to obtain green output.

A balance result whose simulation status is `timeout` is valid unresolved-match
evidence. It is not a harness timeout and remains in stage denominators.

## Artifact And Commit Contract

Every slice root ends with:

```text
scope.json
command-results.json
artifact-manifest.json
review.md
status-before-commit.txt
```

`artifact-manifest.json` records every other relative path, byte count and
SHA-256; it explicitly excludes itself to avoid a self-hash cycle.
Copy per-test logs into the slice root before another invocation can overwrite
shared logs.

Before commit:

1. all required commands passed;
2. all required artifacts passed their contract checks;
3. independent review says `PASS`;
4. every changed path is in the declared write set;
5. `git diff --check` passes;
6. a draft artifact index validates without claiming a commit SHA.

Commit only declared paths. Use message `Battle Bog <slice>: <deliverable>`.
After commit, write the full commit SHA to `commit.txt`, generate the final
`artifact-manifest.json` including `commit.txt`, and then make the root
immutable. Require an empty source worktree, then push the current branch.

On failure, preserve the attempt and write `review/triage.json`:

```text
category            severity
failing_command     failing_evidence
first_bad_sha       affected_scope
root_cause_status   disposition
```

Disposition is exactly `fix_same_slice`, `new_slice`, `rerun_unchanged` or
`blocked`. Unknown cause is `blocked`. A committed regression gets a new
corrective slice; never rewrite or destructively undo history.

## Gate States

Allowed states:

`OPEN -> RUNNING -> EVIDENCE_READY -> PASSED -> COMMITTED -> DONE`

`BLOCKED` may replace any non-DONE state. A human gate follows
`EVIDENCE_READY -> HUMAN_APPROVED -> PASSED -> COMMITTED -> DONE`; a gate with
no source edit omits `COMMITTED`.

An automated slice is `DONE` only when commands and artifacts pass, independent
review passes, a scoped commit exists, the recorded SHA matches, the worktree
is clean and the commit is pushed.

An explicitly artifact-only slice follows
`OPEN -> RUNNING -> EVIDENCE_READY -> PASSED -> DONE` and requires no commit.
R5 and R10.5 are not artifact-only because they write tracked freeze manifests.

A PvAI stage is `DONE` only when all planned jobs have valid provenance, every
anomaly is classified, thresholds pass and `promotion.json` says `promote`.

A creature is `COMPLETE` only when every Universal Definition-of-Done row links
to immutable passing evidence. R17 completes only when all 21 creatures are
complete and both R17A and R17B pass.

## Baseline Contract

Comparators are read-only. Promotion requires:

- clean source worktree;
- three matching captures from one HEAD/build/renderer/viewport contract;
- passing semantic truth;
- source-run manifest;
- reviewer ID and written reason;
- expected hash of any replaced baseline.

Promotion refuses dirty/failed/mixed-provenance runs and refuses an existing
target unless `-Replace -ApprovedBy <id>` is supplied. Baseline promotion gets a
dedicated commit, then comparator and full strict suite rerun from that commit.
Never update a baseline merely to make a regression pass. R4 cannot promote.

## Human Decision Records

Before a human-gated file changes, create an evidence packet and request every
listed field. Resume only after `docs/BATTLE_BOG_DECISIONS.md` records:

```text
gate_id        selected_option
rejected       approver
decision_date  evidence_path
```

Known gates:

| Gate | Required Human Fields | Enforcement Deadline |
| --- | --- | --- |
| R4H | Otter cohort range, follower travel/teleport, individual health, control transfer | before R4F.1 |
| R2BH | approve one exact clean procedural source run as initial baseline truth | before R2B.2 |
| R10 | approve each PvAI victory, defeat and soak review record | before R10.5 |
| R10A | shared Alligator concept and source rig for fair four-candidate production | before R11 |
| R12 | candidate comprehension/elimination decision | before R13 |
| R12H | hardware, OS, build type, renderer, VSync, quality, minimum FPS | before numeric performance can eliminate/select |
| R14 | default roster pipeline and named exceptions | before production assets |
| R14A | playable Owl species | before final Owl silhouette/motion |
| R17B | twelve-participant comprehension acceptance | before release |

Open the Otter and Owl packets during R0.5 so they are not first presented at
their enforcement deadline. The executor may continue nonblocked work.

## Phase Packets

Each packet is exhaustive for routing. Detailed gameplay values remain in the
roadmap and damaging-action inventory; detailed visual thresholds remain in the
validation and Alligator gate documents.

### R0.5 Frame-Data Conformance

Prerequisite: clean descendant of `710b5d4`.

Write set: the exact R0.5 set in the roadmap.

Do:

1. write failing `battle_bog_frame_data_check.gd`;
2. migrate Alligator config to
   `stats.action_timelines.alligator_bite`;
3. implement recovery start blocking and suppressed-input provenance;
4. implement authoritative primary/kit phase query;
5. implement source-qualified startup counter damage/feedback;
6. replace second hitstop with three render frames;
7. implement Death Roll startup/channel/exit;
8. update reel, manifest, render signature and compatibility tests.

Exact symbols to modify are
`AttackTimeline.normalize_config/current_phase_name`,
`Creature.tick_sim`, `_without_ability_buttons`, `request_primary_attack`,
`take_damage_event`, `begin_render_hitstop`, `_process`,
`_render_signature`, `_advance_primary_attack_timeline`,
`AlligatorKit._try_death_roll`, `_tick_death_roll`, catalog timeline
validation, and Arena's `counter_hit` VFX-event branch. Exact focused files are
new `battle_bog_frame_data_check.gd` plus existing
`battle_bog_attack_timeline_check.gd`,
`battle_bog_creature_attack_timeline_check.gd`,
`battle_bog_alligator_timeline_check.gd`,
`battle_bog_alligator_visual_pose_check.gd`,
`battle_bog_damage_meta_check.gd`,
`battle_bog_input_suppression_check.gd` and
`battle_bog_primary_attack_catalog_check.gd`, plus catalog-path/hitstop
expectations in `battle_bog_switch_transaction_check.gd` and
`battle_bog_movement_feel_check.gd`.

Exact phase APIs:

```text
AttackTimeline.current_phase_name() -> StringName
kit.get_action_phase_records() -> Array[Dictionary]
Creature.get_authoritative_action_phase_records() -> Array[Dictionary]
```

Each kit record has `action_id`, `sequence_id`, `phase` and
`counter_vulnerable`; Creature adds the primary record, rejects duplicate
`(action_id,sequence_id)` and sorts by that tuple. The legacy render tell is
consulted only when no authoritative record exists.

Death Roll transitions:

```text
Q just-pressed + live latch + both actors in water -> startup 0.35 s
startup completes                              -> channel, first damage now
channel                                       -> fixed-step 30 DPS for 5.00 s
5.00 s completes                              -> release latch, exit 0.40 s
stun/actor death/target loss/water invalid/
match end before completion                   -> release latch, exit 0.55 s
Q button-up or Primary suppression            -> no transition
```

Cooldown begins on accepted Q. Startup is counter-vulnerable; channel/exit are
not. Channel clamps its final damage contribution to exactly five seconds.

The recovering action owns `recovery_allows_dash_cancel`; an incoming dash
cannot override a `false` value. All current actions use `false`.

Counter feedback constants are
`COUNTER_FLASH_COLOR = Color(1.0, 0.88, 0.24, 1.0)` and
`COUNTER_FLASH_SEC = 0.12`. The body overlay begins at alpha `0.72`, decreases
linearly to zero, and draws after the normal hit flash but before team/threat
outlines. State tests assert color/progress; the reel captures first and final
nonzero counter-flash frames.

Pass: every roadmap R0.5 command succeeds in order. Artifact root:
`artifacts/execution/r0.5/<attempt-token>/`.
The first focused command is
`battle_bog_checked_command_contract_check.ps1`; it proves pass, nonzero exit,
missing marker, timeout/process-tree termination and result-JSON cases before
the wrapper is used for any gameplay check.

Failure routing: fixture-only error stays in R0.5; behavior conflict with a
locked decision is `BLOCKED`; no timing is tuned.

### R1A Split-Step Integration

Prerequisite: R0.5 `DONE`.

Write set: `attack_timeline.gd`, `creature.gd`,
`battle_bog_attack_movement_split_check.gd`,
`battle_bog_attack_timeline_check.gd`,
`battle_bog_creature_attack_timeline_check.gd`,
`battle_bog_alligator_timeline_check.gd`,
`battle_bog_movement_feel_check.gd`,
`battle_bog_tempo_latch_check.gd` and
`battle_bog_switch_transaction_check.gd`. No other compatibility test may be
edited in R1A.

Do: implement the exact boundary APIs and
`Creature._integrate_attack_movement_and_timeline(delta)` algorithm in the
roadmap. Test single/multiple boundaries, resolver reset/death, idle remainder,
dash/residual velocity, exact-once contact and latch duration.

Add `AttackTimeline.advance_pending_boundary(simulation_tick,resolver)`. It is
legal only when `time_to_phase_boundary() == 0.0`, consumes no time and returns
the same events `_complete_phase()` would emit. The split loop calls it before
moving another slice. More than eight boundaries emits a hard test-visible
error, aborts the tick remainder and never applies extra movement/damage.

Stamp new latches with `latch_created_simulation_tick`; `_tick_latch` does not
decrement one created on the current tick. Normal timeline completion gives
the remainder idle movement. Resolver interruption/reset, actor death,
respawn/species replacement or match freeze discards the remainder. Numeric
equivalence tolerance is `1e-5` seconds and `1e-4` pixels.

Pass: focused split test, all attack/Alligator tests, full strict suite,
headless boot and diff check. Root:
`artifacts/execution/r1a/<attempt-token>/`.

### R1B Presentation Snapshot

Prerequisite: R1A `DONE`.

Write set: the exact R1B row in the roadmap.

Do: create schema JSON first, then immutable class, Creature builder,
compatibility copy, JSON conversion and tests. Enums are closed; unknown keys
fail. Adapters do not exist yet and are not added.

Stable IDs:

```text
registered actor  slot:<team>:<slot-index>
fixture actor     fixture:<scenario-id>:<ordinal>
pet               pet:<owner-id>:<pet-kind>:<spawn-sequence>
child             child:<owner-id>:<action-id>:<spawn-sequence>
```

`travel_heading` is the last nonzero velocity heading and resets to body
heading on species replacement. `attention_heading` is the current normalized
aim. Latch anchor is the Decision #30 world contact point; grip ratio is
remaining/max. Weakpoint precedence is `hit > open > warning > closed`, then
lexical ID. Add render-only prototype death progress of `0.60 s`; increment the
death sequence at death, expose `death_t` from zero to one and do not alter
respawn/gameplay timing. Build/cache the base snapshot before every early return
from `tick_sim()`.

Allowed root vocabularies are written literally into the schema before class
code: locomotion `idle,start,travel,turn,reverse,stop,forced,dead`; transition
`none,land_to_mud,mud_to_land,mud_to_shallow,shallow_to_mud,shallow_to_deep,
deep_to_shallow,takeoff,landing,submerge,emerge`; elevation
`ground,perched,airborne,low,submerged`. Resource and kit-cue keys are copied
verbatim from a checked-in field-by-field matrix of the existing
`get_render_motion_state()` output; no key may be invented or dropped. The R1B
test compares every legacy key to its snapshot or named compatibility
derivation.

Pass: snapshot test covers constructor rejection, deep isolation, stable
same-tick identity, feedback derivation, JSON safety, lifecycle reset and every
closed enum; then movement/Alligator/full/headless/diff gates.

### R2A Evidence Fixture

Prerequisite: R1B `DONE`.

Exact write set:

```text
scenes/test/VisualRegressionArena.tscn
scripts/test/run_visual_regression.ps1
scripts/test/visual/visual_regression_arena.gd
scripts/test/visual/visual_manifest.gd
scripts/test/visual/scenario_catalog.gd
scripts/test/visual/scenarios/neutral_real_arena_scenario.gd
tests/visual/manifest.json
tests/visual/semantic_capture.schema.json
scripts/test/battle_bog_visual_regression_arena_check.gd
scripts/test/battle_bog_visual_capture_artifact_check.ps1
```

Extend existing fixture files; do not recreate them. Add exact camera and mode
parameters, event-relative windows, named anchors, semantic JSON schema,
neutral real-Creature smoke and contract checks. Diagnostic may contain labels;
Evaluator must not; Performance performs no screenshot readback.

R2A owns `tests/visual/semantic_capture.schema.json`; R2B consumes it.
`VisualRegressionArena` instances the normal `Arena.tscn` under the fixture,
selects canonical PvAI rules, disables random spawning not declared by the
scenario and applies inputs through `InputFrame`. `PvAI` maps to Camera2D zoom
`Vector2(2.6,2.6)` and `Competitive` to `Vector2(2.2,2.2)`.

Resolve named anchors in a dry simulation pass before capture. Anchor frame is
the first fixed tick whose semantic event occurs. Capture inclusively from
`anchor-before_frames` through the first frame after the named terminal state.
`HIT-1` is one fixed tick before `HIT+0`. Semantic JSON includes schema version,
scenario/action IDs, seed, camera/mode, frame/tick, actor/target IDs, snapshot,
phase/outcome, projected/contact truth, terrain/depth and named anchors.
Diagnostic may add semantic labels; Evaluator permits HUD/gameplay UI but no
phase, outcome, pipeline or answer label.

Pass commands:

```powershell
.\scripts\test\run_visual_regression.ps1 -Validate -RunId "r2a-validate-<attempt-token>"
.\scripts\test\run_visual_regression.ps1 -List -RunId "r2a-list-<attempt-token>"
.\scripts\test\run_visual_regression.ps1 -Scenario neutral_smoke -CameraPreset PvAI -CaptureMode Diagnostic -RunId "r2a-pvai-<attempt-token>" -Capture
.\scripts\test\run_visual_regression.ps1 -Scenario neutral_smoke -CameraPreset Competitive -CaptureMode Diagnostic -RunId "r2a-competitive-<attempt-token>" -Capture
.\scripts\test\run_all.ps1 -TestPattern 'battle_bog_visual_regression_arena_check.gd' -KeepGoing -StrictOutput
.\scripts\test\battle_bog_visual_capture_artifact_check.ps1 -ArtifactRoot "artifacts\visual-regression\r2a-pvai-<attempt-token>"
.\scripts\test\battle_bog_visual_capture_artifact_check.ps1 -ArtifactRoot "artifacts\visual-regression\r2a-competitive-<attempt-token>"
```

Then standard full/headless/diff closeout.

### R2B Comparator And Promotion

Prerequisite: R2A `DONE`.

Exact write set:

```text
scripts/test/visual/image_metrics.gd
scripts/test/compare_visual_regression.ps1
scripts/test/promote_visual_baseline.ps1
scripts/test/battle_bog_visual_comparator_check.ps1
tests/visual/baselines/windows-x86_64-godot4.6-gl_compatibility/
```

Implement named comparator/promotion files and semantic schema. Hard-code the
current provisional raster thresholds from
`BATTLE_BOG_VISUAL_VALIDATION_SPEC.md`; do not tune them. First prove all
refusal cases, then promote one reviewed procedural neutral baseline, then
prove identical pass and synthetic failures for MAE, ROI SSIM and changed
pixels.

R2B ends after contract, metric, synthetic-baseline and refusal tests pass.
`R2BH` asks the user to approve one specific clean procedural source run.
Only `R2B.2` may promote that exact run, followed by comparator,
full/headless/diff. The executor never approves visual truth.

Pass: R2B tooling tests, R2BH `HUMAN_APPROVED`, R2B.2 promotion,
post-promotion comparator, full/headless/diff. Root:
`artifacts/execution/r2b/<attempt-token>/`.

Metric definitions:

```text
MAE            mean absolute normalized sRGB RGB difference; alpha excluded
SSIM           BT.709 sRGB luminance, 11x11 Gaussian, sigma 1.5, reflected edge
changed pixel  max absolute RGB channel delta > 0.08
critical ROI   integer-clamped union of semantic body/contact/telegraph bounds
platform slug  windows-x86_64-godot4.6-gl_compatibility
```

Baseline manifest stores schema, platform, renderer, viewport, scenario,
camera/mode, source SHA/run, frame/anchor, PNG/JSON hashes and ROI. First
promotion has no old hash; replacement requires the exact recorded old hash.

### R2C Procedural Alligator Evidence

Prerequisite: R2B.2 `DONE`.

Exact write set:

```text
scripts/test/visual/scenarios/alligator_player_camera_attack_scenario.gd
scripts/test/visual/scenarios/alligator_shoreline_transition_scenario.gd
scripts/test/visual/scenarios/alligator_latch_death_roll_scenario.gd
scripts/test/visual/scenarios/alligator_death_respawn_scenario.gd
scripts/test/visual/scenarios/alligator_six_actor_density_scenario.gd
tests/visual/manifest.json
scripts/test/battle_bog_visual_capture_artifact_check.ps1
```

Create exactly the five Alligator scenarios named by the roadmap. Capture each
at PvAI and Competitive cameras in Diagnostic and Evaluator modes. Evaluator
artifacts contain no phase/outcome/answer labels. Prove dry/mud/shallow/deep
interleave, Bite hit/whiff/interruption, latch/Death Roll, death/respawn and six
actor density.

Pass: 20 scenario-mode-camera capture roots, every named anchor/pair present,
semantic truth valid, comparator pass where a baseline exists, then standard
closeout. Write one immutable aggregate index under
`artifacts/visual-regression/r2c-<attempt-token>/` for R2F input.

All scenarios use seed `307`, Blue Alligator actor ID `fixture:<scenario>:0`,
aim `Vector2.RIGHT`, target ID `fixture:<scenario>:1`, zero cooldown/resource
debt and scripted per-tick inputs. Attack hit places the target hull tangent to
the committed Bite shape; whiff moves it one body radius beyond. Interruption
occurs halfway through startup. Shoreline traverses in order
`dry -> mud -> shallow -> deep -> shallow -> mud -> dry`; latch/Death Roll
starts both actors in deep water; death/respawn uses lethal enemy damage during
startup; density uses three fixed Blue and three fixed Red roster slots.

Visual bands are deterministic: `dry` is land farther than `0.25 u` from water;
`mud` is land within `0.25 u`; `shallow` is water with edge distance
`<=0.75 u`; `deep` is water beyond `0.75 u`. These are presentation bands over
existing land/shallow/water simulation truth and never change gameplay terrain.

### R2D Performance Evidence

Prerequisite: R2A and R2C `DONE`.

Exact write set:

```text
scripts/test/run_visual_performance.ps1
scripts/test/visual/performance_sampler.gd
scripts/test/battle_bog_visual_performance_contract_check.ps1
tests/visual/performance.schema.json
scripts/test/visual/scenarios/alligator_six_actor_density_scenario.gd
tests/visual/manifest.json
```

Use `alligator_six_actor_density`; create the performance runner/sampler/schema and contract
check. Required fields are frame-time p50/p95/p99/worst, over-33.3-ms count,
draw calls, primitives, video/process memory, node/resource counts, run count,
warm-up/measured frames, scenario, renderer, build, VSync, GPU and commit.

Pass: five runs, 300 warm-up, 1,800 measured, readback disabled and identical
provenance. Numbers are record-only until R12H; missing/invalid evidence fails.

Use scenario ID `alligator_six_actor_density` everywhere. Run five separate
Godot processes with VSync disabled and no `--fixed-fps`; each process performs
300 normal-loop warm-up frames and measures the next 1,800 after
`RenderingServer.frame_post_draw`. Frame duration is consecutive
`Time.get_ticks_usec()` delta. Percentiles use sorted nearest-rank
`ceil(p*n)-1`. Sample Godot `Performance` monitors after each measured frame.
R2D records runtime telemetry only. Candidate cold load, package growth, import
duration and retime effort are added to each R11 candidate packet.

### R2E Visual Adapter Boundary

Prerequisite: R1B `DONE`.

Exact write set:

```text
scripts/sim/presentation/visual_adapter.gd
scripts/visual/adapters/procedural_visual_adapter.gd
scripts/test/battle_bog_visual_adapter_boundary_check.gd
```

Implement only the interface and boundary check described by the roadmap. Add a
minimal procedural adapter proving snapshot/static-metadata input. Do not build
candidate adapters.

The procedural file is
`scripts/visual/adapters/procedural_visual_adapter.gd`. Static scan covers
`scripts/visual/adapters/` and rejects identifiers/imports for Creature, kits,
AttackTimeline, collision/damage APIs, `get_tree`, `get_node` and NodePath.
Creating/returning the adapter-owned `CanvasItem` is allowed; traversing from it
is not.

Pass: focused boundary test, static forbidden-read scan, full/headless/diff and
saved logs under `artifacts/visual-adapter/r2e-<attempt-token>/`.

### R2F Blinded Review Packager

Prerequisite: R2B.2 and R2C `DONE`.

Exact write set:

```text
scripts/test/package_blinded_review.ps1
tests/visual/human_trials/trial_manifest.schema.json
scripts/test/battle_bog_blinded_review_contract_check.ps1
```

Implement exact CLI from the roadmap. Package pinned-ffmpeg 60-fps clips.
Participant package contains anonymous IDs only. Evaluator package owns the
pipeline/scenario/answer mapping. Contract check searches all participant bytes
and metadata for answer-key hashes, pipeline IDs and labels.

Pass: eight participant IDs, 20 trials per critical task, deterministic seed
307 randomization, no leakage, full/headless/diff.

Pinned executable:

```text
C:\Users\fishe\AppData\Local\Microsoft\WinGet\Packages\
Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\
ffmpeg-8.0.1-full_build\bin\ffmpeg.exe
version: ffmpeg 8.0.1-full_build
SHA-256: 74DB6C184A03DBA2BDFE23E1A1F41CF5A8385BC1DE6A7A1B26DB1DC541ABEF93
license: sibling ffmpeg-8.0.1-full_build\LICENSE
```

Fail if path/version/hash/license differs; do not download or choose another
build. Encode MP4/H.264 `libx264`, `yuv420p`, CFR 60, no audio, `crf 18`,
`preset medium`, GOP 120, metadata stripped. Critical task IDs are
`heading,phase,contact,shoreline,reacquisition`; each participant receives 20
seed-307 Latin-square-counterbalanced trials per task. Exclude only missing
responses over 10%, responses below 100 ms or above 5,000 ms, or failed
pipeline-blindness confirmation; retain raw and exclusion reason.
`participant-package/` contains clips and anonymous trial manifest.
`evaluator-package/answer-key.json` alone maps trial to pipeline/answer.

### R3.5 Action Contract Normalization

Prerequisite: R2F `DONE`. The normative execution queue is serial. Subagents may
research future facts in separate worktrees, but no later phase is promoted or
started before the prior queue item is `DONE`.

Write set: `docs/action-contracts/`, new
`docs/action-contracts/action_contract.schema.json`,
`docs/action-contracts/validator_result.schema.json`, new
`scripts/test/battle_bog_action_contract_check.ps1`, inventory and roadmap
status lines only. The JSON Schema encodes every type, nested key, enum,
cardinality and `additionalProperties:false` rule from the inventory.

Do:

1. split every discovery row into independently owned parent/child `action_id`s;
2. populate every required field from current code/roster and written prototype
   records;
3. preserve current behavior unless a written prototype overrides it;
4. use the default lifecycle policy unless a written exception exists;
5. mark any unresolved conflict `BLOCKED`;
6. run independent code-search completeness review.

Pass: validator reports every non-human-gated R4 action ID `CONTRACT_READY`;
`otter_gang_up_cohort` may be `HUMAN_BLOCKED` with `gate_id=R4H`. There is no
missing damage source, duplicate config authority or unresolved nongated field,
and reviewer says `PASS`. R4F.0/R4F.2 may proceed while the Otter cohort remains
blocked; R4F.1 cannot.

### R4 Combat Migrations

Prerequisites: R1B, R2A and R3.5 `DONE`; named prior helper consumers passed.

Order:

```text
R4A Mosquito + Firefly projectile pair
R4B Newt + Crayfish alternation pair, then Duck
R4C Alligator + Bullfrog melee pair, then Water Snake latch
R4D Kingfisher + Owl aerial pair, then Cane Toad local channel
R4E.1 Beaver + Bog Turtle
R4E.2 Water Shrew + Mink
R4E.3 Chorus Frog + Great Blue Heron
R4E.4 Snapping Turtle + Wolf Spider
R4F.0 Otter Bite/latch/Tail Whip
R4F.2 Leech
R4H human Otter cohort decision
R4F.1 Otter Gang Up
```

Each action uses its normalized contract, focused test and action-specific
scenario. Use class anchors from the inventory, not one generic creature
capture. R4C reuses/updates the R2C Alligator scenario IDs and never duplicates
them.

Canonical capture RunId:

`r4-<slice>-<action-id>-<scenario-id>-<attempt-token>`

Canonical closeout:

`artifacts/combat-migration/r4-<slice>-<attempt-token>/`

Pass: every slice action reaches `PROVEN`; helper pair and compatibility tests,
action captures, full/headless/diff and independent semantic review pass before
the next slice.

R4A exact implementation write set additionally names
`scripts/sim/entities/mosquito_projectile.gd`,
`scripts/sim/entities/mosquito_field.gd`,
`scripts/sim/entities/firefly_projectile.gd`,
`scripts/sim/creature.gd`,
`battle_bog_wave3_mosquito_swarm_check.gd` and
`battle_bog_wave3_firefly_check.gd`. Replace same-tick-spawn expectations with
the written release tick; do not preserve that legacy timing.

`ProjectileReleaseResolver` API:

```text
configure(action_id:StringName, spawn_callback:Callable) -> bool
accept(sequence_id:int, origin_px:Vector2, heading:Vector2,
       payload:Dictionary) -> bool
resolve_release(sequence_id:int) -> Dictionary
cancel(sequence_id:int, reason:StringName) -> bool
```

It deep-copies values, rejects duplicate sequence IDs, calls spawn exactly once
at release, returns `released/whiff` plus child ID, and is reentrancy-safe by
marking resolved before callback. Target choice stays kit-owned at acceptance
or written release phase. Firefly P5 is an explicit override: choose once at
release, never reacquire, continue heading if invalid.

Creature exposes monotonically increasing `spawn_generation`; control switching
does not change it, while respawn/species replacement does. Mosquito children
store owner ID/generation and retire on generation mismatch or match end, not
on control suppression or source death.

### R5 Structural Freeze

Prerequisite: all R4 slices `DONE`.

Run every focused test, action-contract validator, full strict suite, headless
boot and diff check. Write:

`artifacts/combat-freeze/r5-<attempt-token>/contract.json`

It contains commit SHA; every action status; command results; and SHA-256 for
roster data, combat helpers, kits, pets and child entities. Pass only when every
action is `PROVEN` or `PROVEN_NON_DAMAGING`. This freezes APIs/ownership, not
balance values.

Also write tracked
`docs/checkpoints/BATTLE_BOG_R5_COMBAT_FREEZE.json` with the same source hashes,
evidence-root hash and parent commit, validate it with
`battle_bog_action_contract_check.ps1`, and commit only that file. R5 is a
source checkpoint, not an artifact-only phase.

### R6-R9 PvAI Stages

Prerequisite: R5 `DONE`.

R6 preflight write set is exactly
`scripts/test/battle_bog_balance_matrix_contract_check.ps1` and
`scripts/test/battle_bog_balance_summary_contract_check.ps1` for the two marker
lines above. Run both through the checked wrapper before StageB5 and commit only
those marker additions.

Run exactly one roadmap stage command. `promotion.json` schema:

```text
schema_version       stage
run_id               parent_promotion
commit               build_fingerprint
rules_fingerprint    planned_jobs
valid_jobs           evaluated_thresholds
anomalies            reviewer
decision             decision_reason
```

Every anomaly contains ID, severity, classification, disposition and evidence.
`promote` is illegal with missing jobs, provenance drift, threshold failure or
unclassified anomaly.

Decision table:

```text
launcher/harness failure       rerun only after known external cause; fresh root
checksum drift                 blocked; no promotion
threshold/behavior miss        tune_then_rerun
complete pass                  promote
unknown cause                  blocked
```

Any gameplay tuning reruns focused/full tests and restarts at R6. Throughput
optimization is allowed only when a canonical stage cannot finish inside its
documented harness timeout and must preserve checksum sequences.

### R10 Human PvAI Sessions

Prerequisite: R9 `DONE`.

Roots:

```text
artifacts/pvai-human/r10-victory-<attempt-token>/
artifacts/pvai-human/r10-defeat-<attempt-token>/
artifacts/pvai-human/r10-soak-<attempt-token>/
```

Each contains `video.mp4`, `events.jsonl`, `session.json` and `review.md`.
Exercise every switching state and inactive-squad behavior listed in the
roadmap. Any S0/S1 blocks R11. A fix reruns StageB5, the affected longer stage
and failed human session. S2 may remain only with owner/disposition.
`session.json` records reviewer, review decision and user approval evidence;
all three sessions must reach `HUMAN_APPROVED`.

### R10.5 Gameplay Content Freeze

Prerequisite: clean promoted R6-R10 loop.

Write a freeze manifest with the R5 hashes plus current balance, movement, AI,
terrain, flight and objective hashes. Any later gameplay-affecting change
invalidates affected evidence and returns to R6. Presentation-only adapter/asset
changes do not.

The tracked path is
`docs/checkpoints/BATTLE_BOG_R10_5_GAMEPLAY_FREEZE.json`; the exact write set is
that file plus
`scripts/test/battle_bog_gameplay_freeze_contract_check.ps1`. Validate parent
promotions, three human approvals and source hashes with the
`scripts/test/battle_bog_gameplay_freeze_contract_check.ps1`, run full strict
suite/headless/diff, then commit both paths.

### R10A-R14 Representative Pipeline

R10A obtains the approved shared Alligator concept/source rig. R11 creates
exact candidate IDs/directories:

```text
atlas_3d
live_3d
skeleton_2d
authored_keyposes
```

Each lives under `assets/battle_bog/candidates/<candidate_id>/alligator/` with
adapter under `scripts/visual/adapters/<candidate_id>/`, editable source,
runtime export, manifest, rights record and procedural fallback. All use the
same snapshot, camera, simulation, concept and evidence matrix.

R11 exact write set is:

```text
assets/battle_bog/candidates/<candidate_id>/alligator/**
scripts/visual/adapters/<candidate_id>/alligator_adapter.gd
tests/visual/candidates.json
tests/visual/manifest.json
scripts/test/build_visual_candidate.ps1
scripts/test/battle_bog_visual_candidate_contract_check.ps1
```

`<candidate_id>` iterates the four literal IDs above. The build script accepts
`-CandidateId`, `-CreatureId alligator`, `-SourceDecision R10A`,
`-AttemptToken`; it packages already authored source/runtime files and never
generates or redesigns art. Candidate authoring follows the approved R10A source
and the exact four-way asset matrix in `BATTLE_BOG_ALLIGATOR_PIPELINE_GATE.md`.
The contract check prints `BB_VISUAL_CANDIDATE_CONTRACT_OK`.

R11 is `DONE` only after all four contract checks, the R2C capture matrix per
candidate, R2D telemetry per candidate, full/headless/diff and independent
parity review pass. Root:
`artifacts/visual-candidates/r11-<attempt-token>/`.

R12 tasks are heading, phase, contact, shoreline and reacquisition. Any hard
threshold failure eliminates a candidate. One remediation pass is allowed. If
fewer than two survive, stop for human direction.

R12H locks the performance environment or records that numbers remain
descriptive and cannot eliminate/select. R13 uses diagnostic, simulation-timed
Kingfisher poses and Mosquito bodies to stress candidates; it cannot claim
final biological animation. Mixed 3v3 uses one fixed manifest for all survivors.
R14 records the human default and exceptions.

R13 exact source write set is:

```text
assets/battle_bog/candidates/<survivor-id>/kingfisher/**
assets/battle_bog/candidates/<survivor-id>/mosquito_swarm/**
scripts/visual/adapters/<survivor-id>/kingfisher_adapter.gd
scripts/visual/adapters/<survivor-id>/mosquito_swarm_adapter.gd
scripts/test/visual/scenarios/pipeline_mixed_3v3_scenario.gd
tests/visual/candidates.json
tests/visual/manifest.json
```

Use seed `307`; mixed roster is Blue
`Alligator, Kingfisher, Mosquito Swarm` versus the mirrored Red roster, PvAI
camera `2.6` and Competitive camera `2.2`. Run the same R11 candidate contract,
R2 capture/comparator, R2D completeness and full/headless/diff commands for each
survivor. Root: `artifacts/visual-candidates/r13-<attempt-token>/`. R13 is
`DONE` only when every survivor has both creature stress cases and mixed 3v3.

R14 writes a human decision row and tracked
`docs/checkpoints/BATTLE_BOG_R14_PIPELINE_SELECTION.json` naming default,
exceptions, rejected candidates and R11-R13 evidence hashes. That file is the
only R14 write set.

### R14A-R15 Roster Production

R14A records Owl identity. R14B closes or formally defers each research row.
A deferral permits unrelated work but cannot pass R16/R17. Release scope is
always all 21 creatures under this roadmap; changing that requires a new,
explicitly approved roadmap version and is not an R14B option.

R14A exact write set:

```text
data/battle_bog_roster.json
docs/RESEARCH_WILDLIFE_MOVEMENT_EVIDENCE.md
docs/checkpoints/BATTLE_BOG_R14A_OWL_IDENTITY.json
scripts/test/battle_bog_owl_identity_contract_check.ps1
```

The human decision supplies species common name and scientific name. Record
gate ID, approver/date, selected/rejected options and evidence. Update only the
Owl `species_common_name` and `species_scientific_name` fields and matching
research row; do not change gameplay values.
The contract prints `BB_OWL_IDENTITY_CONTRACT_OK` and proves roster/research/
decision agreement. Then run catalog, Owl timeline/movement, full/headless/diff,
commit and push. Evidence root:
`artifacts/human-gates/r14a-<attempt-token>/`. R14A is `DONE` only after
`HUMAN_APPROVED` and the pushed scoped commit.

R14B exact write set:

```text
docs/RESEARCH_WILDLIFE_MOVEMENT_EVIDENCE.md
docs/RESEARCH_VISUAL_DEEP_MINE_SOURCE_LEDGER.md
docs/checkpoints/BATTLE_BOG_R14B_MOVEMENT_GAPS.json
scripts/test/battle_bog_movement_research_gate_check.ps1
```

For each of the seven roadmap gaps, record `CLOSED` with source IDs and exact
supported observations, or `DEFERRED` with missing evidence and blocked
creature/animation. The validator prints
`BB_MOVEMENT_RESEARCH_GATE_OK`, rejects unsupported biological claims and
requires every source ID in the source ledger. Run it, `git diff --check`,
independent evidence review, commit and push. Root:
`artifacts/research/r14b-<attempt-token>/`. R14B is `DONE` when every row is
classified and reviewed; each `DEFERRED` row still blocks its creature and
R16/R17.

R14C finalizes V0 Alligator and V1 Kingfisher/Mosquito. R15 processes V2-V5 in
roadmap order. Before each creature, generate
`docs/production/<creature_id>.md` containing:

```text
selected_adapter      approved_brief
source_paths          runtime_paths
directions            clips/states
pivots                gameplay events
scenario_ids          focused tests
rights_record         procedural fallback
research_dependencies write_set
```

One creature is one checkpoint. A failed creature does not modify the next.
The creature packet, selected adapter contract and research evidence supply all
art direction; the executor does not invent anatomy or motion.

R14C exact source write set:

```text
assets/battle_bog/production/{alligator,kingfisher,mosquito_swarm}/**
scripts/visual/production/{alligator,kingfisher,mosquito_swarm}_adapter.gd
docs/production/{alligator,kingfisher,mosquito_swarm}.md
tests/visual/manifest.json
tests/visual/roster_evidence_manifest.json
```

R15 repeats the same template for exactly one creature at a time:

```text
assets/battle_bog/production/<creature_id>/**
scripts/visual/production/<creature_id>_adapter.gd
docs/production/<creature_id>.md
tests/visual/manifest.json
tests/visual/roster_evidence_manifest.json
```

The only allowed `<creature_id>` order is the V2, then V3, then V4, then V5
table order. Each checkpoint runs
`battle_bog_visual_candidate_contract_check.ps1` in production mode, its
creature timeline/movement tests, every action/capability capture, accessibility
transforms, R2D evidence completeness, full/headless/diff and independent
biological/readability review. Root:
`artifacts/visual-production/<creature_id>-<attempt-token>/`. `DONE` requires a
scoped pushed creature commit and valid evidence index.

### R16 Evidence Matrix

Prerequisites: R14C and every R15 creature packet `DONE`; no deferred release
research.

Create `tests/visual/roster_evidence_manifest.json` and
`scripts/test/validate_roster_evidence.ps1`. The manifest explicitly lists
required scenarios; no implicit cross-product is accepted. Every creature has:

- PvAI and Competitive camera;
- blue and red team;
- day, dusk and night;
- normal, grayscale, protanopia, deuteranopia and tritanopia;
- every applicable capability scenario;
- focused combat, movement, lifecycle and inactive-squad evidence.

Pass only when all 21 creature evidence indexes validate and link to immutable
commits/artifact hashes.

### R17A-R17B Release

Create `tests/visual/release_manifest.json` with fixed rosters, seeds, cameras
and objective schedule. R17A writes
`artifacts/release/r17a-<attempt-token>/release.json`.

R17A passes only with all 21 creatures complete, no deferred research, no
S0/S1, all automated truth/accessibility/determinism gates and complete
performance telemetry. Numerical thresholds apply only if R12H locked them.

R17B packages and runs the twelve-participant, twenty-trials-per-task protocol.
It passes only at the thresholds in the validation spec. A failure returns to
the owning creature/wave, then reruns R16 and affected R17 tasks.

## Completion Statement

This plan is executable without autonomous product decisions only when the
executor obeys fail-closed stopping. Code discovery, implementing a specified
contract and repairing an in-scope defect are expected reasoning tasks. Every
remaining subjective or authority-changing choice is an explicit human gate.
