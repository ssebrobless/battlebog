# Battle Bog PvAI Balance and Playtest Plan

Status: item 5 is automated and green. Item 6 harness tooling is green and the
first bounded `StageB5` evidence run is next. Multiplayer remains deferred and
visual production does not begin until the gates below are met.

```text
PvAI foundation
      |
      v
All Bots engine-driven deterministic harness
      |
      +--> exact-tick replay and invariant smoke
      +--> bounded, resumable viability/matchup stages
      +--> economy, activity, and objective timing review
      |
      v
human victory + defeat + 21-minute soak
      |
      v
no S0/S1 failures
      |
      v
visual reference mining and asset pilot
```

## Current Harness

- Mode: `All Bots`, using the canonical `competitive_3v3` rules.
- Controllers: exactly six AI controllers and zero local controllers.
- Inputs: exact ordered Blue/Red rosters and a nonnegative simulation seed.
- Output: one `battle_bog.balance_sim.v1` JSONL record per match.
- Simulation loop: Godot owns normal 60 Hz physics ordering, movement,
  deferred deletion, and match-completion lifecycle. A root-level final
  observer records exact completed ticks without manually dispatching gameplay
  callbacks.
- Replay evidence: periodic canonical SHA-256 checksums include the explicit
  seed and match RNG state for exact request identity. Parallel gameplay-only
  checksums exclude request metadata and inert RNG state, so cross-seed
  divergence is only evidence after randomness changes gameplay.
- Runtime telemetry: six stable-slot activity rows plus timestamped side/center
  boss lifecycle events are included in every match summary.
- Current integrated throughput: approximately 1.8x across a five-second run
  on the development machine. Longer native-loop throughput will be measured
  during the bounded Stage B runs. The matrix launcher now provides bounded
  parallel workers, immutable per-job results, build- and rules-bound resume,
  exclusive output-root ownership, and deterministic merging. Do not launch
  the full matrix as one unattended batch; promote one named stage at a time
  after reviewing the prior stage's diagnostics.

Commands:

```powershell
.\scripts\test\run_balance_sim.ps1 -ValidateOnly
.\scripts\test\run_balance_sim.ps1 -Smoke
.\scripts\test\run_balance_matrix.ps1 -Stage StageB5 -ValidateOnly
.\scripts\test\battle_bog_balance_matrix_contract_check.ps1
.\scripts\test\battle_bog_balance_summary_contract_check.ps1
```

## Canonical Squads

| ID | Roster |
| --- | --- |
| S1 | Snapping Turtle, Chorus Frog, Mink |
| S2 | Beaver, Duck, Firefly |
| S3 | Owl, Great Blue Heron, Kingfisher |
| S4 | Cane Toad, Newt, Crayfish |
| S5 | Alligator, Water Snake, Bullfrog |
| S6 | Otter, Mosquito Swarm, Leech |
| S7 | Bog Turtle, Water Shrew, Wolf Spider |

These squads cover all 21 playable creatures exactly once. Standard seeds are
`7, 19, 43, 71, 101, 149, 211, 307`.

## Automated Stages

### Stage A: Harness Integrity

1. Reject missing, duplicate, unknown, and malformed roster/seed values.
2. Prove all six routed inputs are AI-owned and local input is never consulted.
3. Prove F9/F10 cannot mutate an All Bots match.
4. Run the same roster/seed twice and require identical canonical and
   gameplay-only checksum series.
5. Change the seed and require equal gameplay-only state before any random
   gameplay event, then require divergence after a forced RNG-consuming
   center-boss roll.
6. Require clean exit, valid JSONL, six stable slot identities, finite values,
   matching rules fingerprint, and monotonic event sequences.

### Stage B: Focused Viability

Run S1-S7 mirror matches with seeds `7` and `101` in two explicit stages:

- `StageB5`: 14 jobs at five simulated minutes.
- `StageB15`: 14 jobs at fifteen simulated minutes.

Review:

- both teams consume food by 2:00;
- both teams deposit by 4:00;
- both teams complete breeding by 5:00;
- stocks, deaths, deposits, breeds, and boss counters satisfy invariants;
- no actor remains alive with no movement/action input for an unexplained
  extended streak;
- 15-minute runs reach side-boss play and the 10:00 center objective.

### Stage C: Side-Neutral Matrix

After Stage B and throughput optimization:

- `StageCMain`: all 21 unordered squad pairs in both side assignments across
  all eight seeds, for 336 jobs at fifteen simulated minutes.
- `StageCExtended`: the seven adjacent cycle pairings (`S1-S2` through `S6-S7`,
  plus `S7-S1`) in both side assignments across all eight seeds, for 112 jobs
  at twenty-five simulated minutes.

Target full plan: 476 matches
(`14 + 14 + 336 + 112`). `Stage Full` exists for manifest/cardinality
validation, but its 476 jobs exceed the default `MaxJobs=32` safety cap and
must not be launched without an explicit reviewed override.

Automated gates:

- at least 95% of 25-minute runs finish naturally;
- aggregate Blue result stays within 3 percentage points of 50%;
- mirrored matchup scores remain within 30-70%;
- both teams eat by 2:00 in at least 95% of runs;
- both teams deposit by 4:00 in at least 90% of runs;
- both teams breed by 5:00 in at least 85% of runs;
- at least 75% of 15-minute runs resolve a side-boss claim or steal;
- at least 60% resolve the 10:00 center boss by 15:00;
- priority 4-5 lopsided-flow summaries occur in no more than 15% of mirrored
  matches.
- persistent-idle anomalies are reviewed per slot and creature. The diagnostic
  threshold requires at least 30 alive seconds, a 15-second uninterrupted idle
  streak, at least 75% idle ticks, and no more than 5% movement-input ticks.

Threshold misses trigger review before tuning. They are not automatic license
to buff or nerf a creature without inspecting replay, telemetry, and matchup
context.

## Human Gate

Record three uninterrupted Play vs AI sessions at minimum:

1. A natural Blue victory.
2. A natural Blue defeat.
3. A 21+ minute objective soak covering both center-boss times.

Exercise and retain evidence for:

- exact six-slot/two-hut/9-stock boot;
- switching while moving, attacking, injured, hungry, on cooldown, dead, and
  exhausted;
- inactive allies foraging, fighting, retreating, defending, and returning;
- autonomous deposits and breeding by inactive Blue allies and Red bots, while
  the currently controlled creature requires explicit player deposit input;
- breeding completion, side-boss wake, fight, claim, contest, and steal;
- death, respawn, slot exhaustion, team exhaustion, immutable results, rematch,
  and menu return;
- HUD truth, including hidden enemy HP outside legal visibility.

Severity:

- S0: crash, softlock, wrong rules, duplicate controllers, corrupted stocks, or
  a match that cannot finish/restart.
- S1: unavailable core loop, persistent ally idling, impossible objective,
  incorrect winner, omniscient AI/HUD, or an essential action that cannot be
  understood.
- S2: intermittent behavior error, misleading feedback, severe HUD crowding, or
  missing causal event.
- S3: cosmetic and placeholder-art issues.

Visual production begins only after all three sessions complete, logs agree
with video, and no S0/S1 failure remains.
