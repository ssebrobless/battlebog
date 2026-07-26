# Battle Bog PvAI Balance and Playtest Plan

Status: item 5 is automated and green. Item 6 is active. Multiplayer remains
deferred and visual production does not begin until the gates below are met.

```text
PvAI foundation
      |
      v
All Bots deterministic harness
      |
      +--> replay and invariant smoke
      +--> viability and mirrored matchup matrix
      +--> economy and objective timing review
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
- Replay evidence: periodic canonical SHA-256 checksums include the explicit
  seed and match RNG state.
- Current throughput: approximately 1.9x in a five-second profile and 1.47x
  across a 45-second viability run on the development machine. Do not launch
  the full matrix until throughput reaches at least 10x or the orchestrator
  gains bounded parallel workers.

Commands:

```powershell
.\scripts\test\run_balance_sim.ps1 -ValidateOnly
.\scripts\test\run_balance_sim.ps1 -Smoke
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
4. Run the same roster/seed twice and require identical checksum series.
5. Change the seed and require a different checksum series.
6. Require clean exit, valid JSONL, six stable slot identities, finite values,
   matching rules fingerprint, and monotonic event sequences.

### Stage B: Focused Viability

Run S1-S7 mirror matches with seeds `7` and `101`, first for five simulated
minutes and then for fifteen after throughput work. Review:

- both teams consume food by 2:00;
- both teams deposit by 4:00;
- both teams complete breeding by 5:00;
- stocks, deaths, deposits, breeds, and boss counters satisfy invariants;
- no actor remains alive with no movement/action input for an unexplained
  extended streak;
- 15-minute runs reach side-boss play and the 10:00 center objective.

### Stage C: Side-Neutral Matrix

After Stage B and throughput optimization, run all 21 unordered squad pairs in
both side assignments across all eight seeds. Add extended 25-minute objective
runs for the seven adjacent squad pairings.

Target full matrix: 472 matches.

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
- assisted-manual Blue deposits and autonomous Red deposits;
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
