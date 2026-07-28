# Battle Bog Visual Deep-Mining Execution Plan

Status: execution-ready research plan; mining has not started

Compiled: 2026-07-28

Purpose: turn the completed visual-preference quiz into a resumable,
multi-agent evidence mine that ends in original, comparable Battle Bog look
prototypes and a production decision.

Depends on:

- `docs/BATTLE_BOG_VISUAL_DIRECTION_BRIEF.md`
- `docs/RESEARCH_VISUAL_REFERENCE_MINING_CANDIDATES.md`
- `docs/RESEARCH_VISUAL_DEEP_MINE_SOURCE_LEDGER.md`
- `docs/RESEARCH_WILDLIFE_MOVEMENT_EVIDENCE.md`
- `docs/BATTLE_BOG_VISUAL_IMPLEMENTATION_ROADMAP.md`
- `docs/BATTLE_BOG_VISUAL_VALIDATION_SPEC.md`
- `docs/BATTLE_BOG_ALLIGATOR_PIPELINE_GATE.md`
- the completed Battle Bog Visual Reference Quiz export at
  `C:\Users\fishe\.codex\attachments\b88923de-f20e-4f6e-821e-6b6a96fc055b\pasted-text.txt`

## Outcome

```text
QUIZ-LOCKED PREFERENCES
          |
          v
QUALIFIED SOURCES ──▶ CLIPS + STILLS + MEASUREMENTS
          |                       |
          v                       v
  SOURCE RULE CARDS ──▶ CROSS-SOURCE SYNTHESIS
                                  |
                    +-------------+-------------+
                    |             |             |
                    v             v             v
               CREATURES        WORLD       COMBAT/HUD
                    |             |             |
                    +-------------+-------------+
                                  |
                                  v
                  FOUR ORIGINAL LOOK CANDIDATES
                                  |
                                  v
                    USER LOOK-SELECTION GATE
                                  |
                                  v
                  PRODUCTION BIBLE + PIPELINE GATE
```

The mine is complete only when it produces:

1. a qualified, deduplicated source ledger;
2. time-coded evidence records with observations separated from inferences;
3. cross-source Battle Bog rule cards;
4. four original look candidates shown under identical gameplay conditions;
5. a recorded user selection or an explicit instruction to revise candidates;
6. an implementation brief for the selected direction.

The mine is not complete merely because many images or videos were collected.

## Thread Boundary

This task owns:

- reference discovery and qualification;
- footage and still analysis;
- real-animal visual and movement evidence;
- textual synthesis;
- non-shipping look studies;
- visual-direction selection;
- the selected direction's art bible and production brief.

The separate gameplay task owns:

- the roster-wide PvAI and combat roadmap;
- simulation, AI and gameplay implementation;
- deterministic gameplay fixtures;
- production runtime adapters;
- final in-engine asset integration.

The two tasks may proceed in parallel. This task may generate concept studies
before the PvAI exit gate. It must not migrate runtime art or alter gameplay
truth before the roster roadmap permits visual production.

## Authority Order

When instructions conflict, use this order:

1. locked decisions in `docs/BATTLE_BOG_DECISIONS.md`;
2. the user's completed visual quiz;
3. `docs/BATTLE_BOG_VISUAL_DIRECTION_BRIEF.md`;
4. gameplay and visual constitutions;
5. this execution plan;
6. source-specific observations and agent proposals.

An agent may not overwrite a higher-authority decision. It records the
conflict in `conflicts.jsonl` and continues on unaffected jobs.

## Locked Taste Inputs

The mine must preserve these decisions:

- creature anatomy is heroic and highly stylized while retaining real-species
  identity;
- size tiers remain meaningful but extreme real-world differences are
  compressed for play;
- creature families do not share one body envelope;
- real-animal locomotion remains the authenticity source;
- combat density sits between Battlerite clarity and SUPERVIVE energy;
- the world is a lush, reactive wetland with competitive hierarchy;
- night changes mood and information without destroying legibility;
- the HUD has simple, contextual and expanded ownership;
- the rendering pipeline remains undecided until direct comparison.

Hard rejection boundaries:

- no recognizable imitation of any reference game's total style;
- no V Rising Gothic or hyperreal overall direction;
- no Pokemon UNITE plastic terrain or mobile-control HUD;
- no visible Don't Starve Together or Cult of the Lamb cutout construction;
- no Temtem-wide toy containment;
- no overly humanoid animals;
- no universal creature shape;
- no reference asset reuse, tracing, palette sampling or animation copying.

## Portfolio And Quotas

Every quota is a minimum accepted-evidence count, not a search count. Rejected,
duplicate, edited beyond usefulness or wrong-camera sequences do not count.

A clip is one unique uninterrupted `6-20 s` sequence. A clip may support
multiple observations, but it counts toward exactly one quota bucket recorded
as `primary_question_id`. Reusing the same frames from another upload does not
create a new clip.

### Full Mines

| Job | Reference | Accepted Evidence Quota | Required Distribution |
| --- | --- | ---: | --- |
| `FM-BAT` | Battlerite | 24 clips | 6 startup/commitment, 4 active/contact, 4 whiff/recovery, 6 six-player pressure, 4 contextual HUD/attention |
| `FM-SUP` | SUPERVIVE | 24 clips | 5 altitude/overlap, 5 target reacquisition, 5 objective escalation, 5 terrain hierarchy, 4 uncertainty/off-screen information |
| `FM-UNI` | Pokemon UNITE | 30 clips | five body families, each with rest, travel, turn, attack, hit and defeat |

Question IDs:

| Job | Question IDs |
| --- | --- |
| `FM-BAT` | `BAT-STARTUP`, `BAT-CONTACT`, `BAT-WHIFF`, `BAT-PRESSURE`, `BAT-HUD` |
| `FM-SUP` | `SUP-ALTITUDE`, `SUP-REACQUIRE`, `SUP-OBJECTIVE`, `SUP-TERRAIN`, `SUP-UNCERTAINTY` |
| `FM-UNI` | `UNI-LONG`, `UNI-WING`, `UNI-HEAVY`, `UNI-SMALL`, `UNI-FLEXIBLE`; add one state tag from `REST`, `TRAVEL`, `TURN`, `ATTACK`, `HIT`, `DEFEAT` |

Pokemon UNITE body families are:

1. long-bodied;
2. winged or airborne;
3. heavy or shelled;
4. small or swarm-adjacent;
5. frog-like or flexible quadruped.

If one family cannot be represented faithfully in the game, the miner records
`coverage_gap`; it does not substitute an unrelated humanoid.

### Specialist Mines

| Job | Reference | Accepted Evidence Quota | Only Approved Question |
| --- | --- | ---: | --- |
| `SP-TEM` | Temtem: Swarm | 12 clips | soft surface economy, compact motion and crowd color blocking without rounded containment |
| `SP-EVE` | Evercore Heroes | 12 clips | bright world finish, rich terrain/unit hierarchy and readable darker scenes |
| `SP-MAC` | The Machines Arena | 8 clips | aim-facing, projectile origin/path, hit confirmation, camera stability |
| `SP-HAD` | Hades II | 8 clips | material impact, dimensional painted quality, signature-effect ceiling |
| `SP-RAV` | Ravenswatch | 8 clips | night mood, painterly ecology, readable darkness boundary |
| `SP-WIL` | Wild Woods | 8 clips | environment shapes, props and approachable habitat composition |
| `SP-ALB` | Albion Online | 10 records | wetland materials, water, regional ecology and biome-production logic |
| `SP-FLO` | Flock | 10 clips | takeoff, sustained flight, bank, brake, descend and formation lag |
| `SP-RAI` | Rain World | 10 clips | long-body follow, terrain contacts, bend limits and procedural exceptions |
| `SP-PIK` | Pikmin 4 | 10 clips | swarm envelope, individual variance, convergence, water entry and hit response |
| `SP-HOT` | Heroes of the Storm | 6 clips | competitive day/night or objective-state world transformation |
| `SP-DOT` | Dota 2 | 8 clips | configurable HUD depth, fog, minimap and last-known information |
| `SP-APX` | Apex Legends | 6 clips | directional warnings, redundant alerts and accessibility |
| `SP-DAO` | Dragon Age: Origins | 8 clips | active-unit switching and released-unit autonomy/intent |
| `SP-DEA` | Dead Cells | 6 primary records | 3D-to-2D production method and revision economics |
| `SP-KLE` | Klei pipeline | 6 primary records | modular 2D workflow without adopting visible cutout style |

Question IDs:

| Job | Question IDs |
| --- | --- |
| `SP-TEM` | `TEM-SURFACE`, `TEM-MOTION`, `TEM-CROWD` |
| `SP-EVE` | `EVE-BRIGHT`, `EVE-HIERARCHY`, `EVE-DARK` |
| `SP-MAC` | `MAC-AIM`, `MAC-PROJECTILE`, `MAC-HIT`, `MAC-CAMERA` |
| `SP-HAD` | `HAD-MATERIAL`, `HAD-IMPACT`, `HAD-PAINT` |
| `SP-RAV` | `RAV-NIGHT`, `RAV-ECOLOGY`, `RAV-READABILITY` |
| `SP-WIL` | `WIL-PROP`, `WIL-PATH`, `WIL-HABITAT` |
| `SP-ALB` | `ALB-WATER`, `ALB-LAYER`, `ALB-AMBIENT`, `ALB-BIOME` |
| `SP-FLO` | `FLO-TAKEOFF`, `FLO-FLIGHT`, `FLO-BANK`, `FLO-BRAKE`, `FLO-FORMATION` |
| `SP-RAI` | `RAI-HEAD`, `RAI-FOLLOW`, `RAI-CONTACT`, `RAI-BEND` |
| `SP-PIK` | `PIK-ENVELOPE`, `PIK-VARIANCE`, `PIK-CONVERGE`, `PIK-WATER`, `PIK-HIT` |
| `SP-HOT` | `HOT-DAYNIGHT`, `HOT-OBJECTIVE` |
| `SP-DOT` | `DOT-FOG`, `DOT-LASTKNOWN`, `DOT-MINIMAP`, `DOT-HUD` |
| `SP-APX` | `APX-DIRECTION`, `APX-REDUNDANCY`, `APX-ACCESSIBILITY` |
| `SP-DAO` | `DAO-SWITCHOUT`, `DAO-AUTONOMY`, `DAO-INTENT`, `DAO-SWITCHBACK` |
| `SP-DEA` | `DEA-SOURCE`, `DEA-RENDER`, `DEA-REVISION` |
| `SP-KLE` | `KLE-MODULE`, `KLE-ATLAS`, `KLE-STATE`, `KLE-REVISION` |

Specialist miners stop at their assigned question. They do not create general
style summaries.

Temtem and Evercore remain important quiz-approved anchors, but their approved
responsibilities are narrower than the three full mines. They receive extended
specialist jobs rather than open-ended full-game studies.

Quota-counting source classes:

- `FM-*`: `P2` and `S1`; `O`, `S2`, `T` and `C` may support but do not count
  toward clip quota;
- `SP-DEA` and `SP-KLE`: `P1` only;
- `SP-ALB`: `P1`, `P2` and `O`;
- every other visual `SP-*`: `P2` and `S1`; `O` and `T` may count only for
  shape, material, world-intent or presentation questions that do not claim
  timing, occupancy or normal camera load;
- `C` never satisfies a specialist quota without one corroborating
  quota-eligible record.

### Discovery Gaps

The current portfolio does not adequately cover every required Battle Bog
problem. Run bounded discovery before M3 for:

| Job | Missing Evidence | Discovery Stop |
| --- | --- | --- |
| `DG-SUB` | top-down submergence, emergence, underwater targeting and shoreline attacks | qualify 3 candidates, then collect 8 clips from the highest-scoring candidate |
| `DG-LON` | top-down long-bodied 360-degree turning and attacking | qualify 3 candidates, then collect 6 clips from the highest-scoring candidate |
| `DG-DIV` | competitive bird dives with early landing and punish information | qualify 3 candidates, then collect 6 clips from the highest-scoring candidate |
| `DG-SWI` | one-player switching among autonomous nonhumanoid allies | qualify 2 candidates, then collect 8 clips from the highest-scoring candidate |
| `DG-WET` | lush reactive wetland that yields during crowded combat | qualify 3 candidates, then collect 8 clips from the highest-scoring candidate |
| `DG-MAT` | feather, fur, shell, scale, chitin, mud and water response | qualify 3 candidates, then collect 8 clips across at least 4 materials |

Candidate qualification records the same source, rights and rejection fields as
an accepted source. Discovery does not add a new style anchor. The winning
candidate receives one narrowly bounded specialist job.

Score each qualified discovery candidate:

| Criterion | Score |
| --- | ---: |
| directly answers the assigned gap | `0-3` |
| representative camera and uninterrupted state | `0-3` |
| source class appropriate for the claim | `0-3` |
| adds evidence absent from the frozen portfolio | `0-3` |
| source is revisitable at a canonical URL | `0-1` |
| rights class permits the required research analysis | `0-1` |

Scoring anchors:

- direct answer: `3` full required transition, `2` relevant partial
  transition, `1` static/end-state only, `0` unrelated;
- camera: `3` normal uninterrupted representative view, `2` representative
  view with minor occlusion, `1` spectator/edited view, `0` cinematic or
  unusable;
- source class: `3` quota-eligible primary class, `2` quota-eligible
  secondary class, `1` corroboration-only class, `0` claim-ineligible;
- novelty: `3` fills an absent state, `2` replaces lower-quality evidence,
  `1` independently corroborates, `0` duplicate;
- revisitability: `1` canonical URL remains accessible, otherwise `0`;
- rights: `1` at least `R1A_TRANSIENT_ANALYSIS`, otherwise `0`.

The integration owner selects the highest total only after independent source
qualification review. Tie-break in this order:

1. claim-eligible `P2`, `S1`, `B1` or `B2`;
2. unedited;
3. `60 FPS` or greater;
4. `1920 x 1080` or greater;
5. earlier publication date;
6. lexicographically smaller canonical-URL SHA-256.

A candidate scoring below `9/14` cannot win. If every candidate is below `9`,
the job records `coverage_gap` after screening twenty candidates.

`DG-MAT` is the only multi-source discovery exception. Retain every qualified
candidate scoring at least `9`, then collect eight clips across at least two
candidates and four of: feather, fur, shell, scale, chitin, mud, water.

### Biological Evidence

Create exactly 21 packets:

`alligator`, `beaver`, `bog_turtle`, `bullfrog`, `cane_toad`,
`chorus_frog`, `crayfish`, `duck`, `firefly`, `great_blue_heron`,
`kingfisher`, `leech`, `mink`, `mosquito_swarm`, `newt`, `otter`, `owl`,
`snapping_turtle`, `water_shrew`, `water_snake`, `wolf_spider`.

Each packet requires:

- one anatomy source;
- six motion evidence records: support/center of mass, acceleration, braking,
  turning, terrain contact/transition and attack/feeding/defense;
- body-support and center-of-mass notes;
- acceleration, braking and turning notes;
- terrain-contact sequence;
- one species-specific exception to its movement-family default.

Evidence fallback order is exact species, then congener, then same family with
matching body plan, then a named morphological analogue. Each fallback lowers
confidence one level. Same-family and analogue evidence cannot create a
high-confidence species rule. Every packet uses at least two publishers and
one exact-species motion source when one is publicly available.

Canonical jobs:

| Creature | Job ID |
| --- | --- |
| Alligator | `BIO-ALL` |
| Beaver | `BIO-BEA` |
| Bog Turtle | `BIO-BOG` |
| Bullfrog | `BIO-BUL` |
| Cane Toad | `BIO-CAN` |
| Chorus Frog | `BIO-CHO` |
| Crayfish | `BIO-CRA` |
| Duck | `BIO-DUC` |
| Firefly | `BIO-FIR` |
| Great Blue Heron | `BIO-HER` |
| Kingfisher | `BIO-KIN` |
| Leech | `BIO-LEE` |
| Mink | `BIO-MIN` |
| Mosquito Swarm | `BIO-MOS` |
| Newt | `BIO-NEW` |
| Otter | `BIO-OTT` |
| Owl | `BIO-OWL` |
| Snapping Turtle | `BIO-SNA` |
| Water Shrew | `BIO-SHR` |
| Water Snake | `BIO-SNK` |
| Wolf Spider | `BIO-SPI` |

Every biological job has quota `7`: one `<JOB>-ANATOMY` record and one each of
`<JOB>-SUPPORT`, `<JOB>-ACCEL`, `<JOB>-BRAKE`, `<JOB>-TURN`,
`<JOB>-TERRAIN`, `<JOB>-ATTACK`. Allowed source classes are `B1`, `B2` and
`B3`. At least one record is `B1`, at least two are `B2`, and no more than two
are `B3`.

Institution or collection reputation does not establish item-level reuse
rights. Record the rights status for every item.

### Boundary Studies

Boundary studies use the exact accepted-record count below. Their output is
only a rejection card.

| Job | Reference | Count | Question ID | Allowed Classes | Boundary To Preserve |
| --- | --- | ---: | --- | --- | --- |
| `BD-VRI` | V Rising | 4 | `BD-VRI-SCOPE` | `O`, `P2`, `S1`, `T` | avoid Gothic identity, hyperreal materials, costly darkness and production scope |
| `BD-DST` | Don't Starve Together | 3 | `BD-DST-CUTOUT` | `O`, `P2`, `S1`, `T` | workflow may transfer; visible paper construction may not |
| `BD-CUL` | Cult of the Lamb | 2 | `BD-CUL-CUTOUT` | `O`, `P2`, `S1`, `T` | reject recognizable illustrated-cutout construction |
| `BD-UNI` | Pokemon UNITE terrain/HUD | 4 | `BD-UNI-PLASTIC` | `O`, `P2`, `S1`, `T` | reject plastic terrain and mobile-control scale |
| `BD-TEM` | Temtem body treatment | 4 | `BD-TEM-CONTAIN` | `O`, `P2`, `S1`, `T` | reject universal round containment and toy finish |
| `BD-WIL` | Wild Woods creatures | 3 | `BD-WIL-HUMANOID` | `O`, `P2`, `S1`, `T` | reject humanoid animal construction |

## Source Qualification

Use exactly one source class per evidence record:

- `P1`: developer, engine owner, conference or official technical source;
- `P2`: official uninterrupted representative gameplay;
- `O`: official static page, roster image or intended presentation;
- `S1`: normal raw player gameplay;
- `S2`: spectator or tournament footage;
- `T`: edited trailer, showcase or montage;
- `C`: community guide, wiki or analysis.
- `B1`: scientific, museum, university or collection anatomy/behavior source;
- `B2`: unedited wildlife footage with species identification and context;
- `B3`: edited documentary or wildlife showcase used only for visible form and
  motion.

The class applies to the extracted sequence, not the publisher. An edited clip
from an official account is `T`.

### Allowed Claims By Class

| Claim | Minimum Evidence |
| --- | --- |
| normal camera occupancy or reaction timing | `P2` or `S1` |
| six-player clutter and target reacquisition | `P2` or `S1`; `S2` may corroborate only |
| intended shape, color or showcase effect | `T` accepted |
| intended static shape, roster framing or official world identity | `O` accepted |
| production method | `P1` |
| current gameplay behavior | two independent `P2`/`S1` sources or one source plus local capture |
| community-described mechanic | `C` plus one corroborating source |
| biological motion rule | observed animal footage plus anatomy/behavior context |

High-confidence biological motion requires at least one `B1` context source
and one `B2` motion source. `B3` may corroborate but cannot establish timing.

Reject a candidate sequence when:

- the camera is cinematic, spectator or zoomed and the job requires normal POV;
- a cut hides startup, contact, recovery or a state transition being measured;
- overlays obscure the relevant body or effect;
- frame pacing prevents reliable timing;
- the version or platform materially changes the behavior and is unknown;
- the same sequence already exists at equal or better quality;
- the source cannot be cited or revisited.

## Run Identity And Storage

Use a UTC run ID:

`visual-mine-YYYYMMDDTHHMMSSZ`

Raw and copyrighted research material stays under ignored `artifacts/`.
Curated textual findings and project-owned generated studies may be promoted
into `docs/` or `assets/concepts/` after review.

```text
artifacts/visual-mine/<run-id>/
├── run-manifest.json
├── tool-manifest.json
├── job-board.json
├── sources/
│   └── <job-id>/
│       ├── source-ledger.jsonl
│       ├── local-capture-index.jsonl
│       └── raw/                         ignored research cache
├── evidence/
│   └── <job-id>/
│       ├── evidence.jsonl
│       ├── measurements.jsonl
│       ├── contacts/                    research-only stills
│       └── clips/                       research-only excerpts
├── rule-cards/
│   └── <job-id>.md
├── synthesis/
│   ├── creature-rules.md
│   ├── movement-rules.md
│   ├── combat-rules.md
│   ├── world-rules.md
│   ├── information-rules.md
│   ├── pipeline-rules.md
│   └── prototype-input-brief.md
├── prototypes/
│   ├── candidate-a/
│   ├── candidate-b/
│   ├── candidate-c/
│   └── candidate-d/
├── review/
│   ├── conflicts.jsonl
│   ├── rejected-evidence.jsonl
│   ├── cross-checks.jsonl
│   ├── similarity-review.json
│   └── selection-record.json
└── logs/
    └── command-results.jsonl
```

Agents append only to their assigned job directory. One integration owner
writes `run-manifest.json`, `job-board.json`, `synthesis/` and `review/`.

## Tooling Substrate

M0 creates these exact tracked files:

```text
tools/visual_mine/
├── schemas/
│   ├── run-manifest.schema.json
│   ├── job-board.schema.json
│   ├── source-record.schema.json
│   ├── evidence-record.schema.json
│   ├── measurement-record.schema.json
│   ├── cross-check-record.schema.json
│   ├── prototype-record.schema.json
│   ├── similarity-review.schema.json
│   └── selection-record.schema.json
├── fixtures/
│   ├── valid/minimum-run/
│   └── invalid/
│       ├── combined-source-class/
│       ├── missing-rights-class/
│       ├── observation-with-recommendation/
│       ├── duplicate-counted-twice/
│       └── generation-input-without-r2/
├── new_visual_mine.ps1
├── validate_visual_mine.ps1
├── summarize_visual_mine.ps1
└── README.md

docs/visual_mine/
├── portfolio-v1.json
├── source-seeds-v1.json
├── job-packet-template.md
└── prototype-brief-template.md
```

PowerShell owns orchestration. A bundled parser may be called only through the
PowerShell entrypoints and must be documented in `tools/visual_mine/README.md`.

Schema policy:

- JSON Schema draft `2020-12`;
- UTF-8 without BOM;
- `additionalProperties: false` at every object level;
- every field shown in this plan is required, including fields whose permitted
  value is `null`;
- timestamps are UTC RFC 3339 with `Z`;
- hashes are lowercase 64-character SHA-256;
- JSONL validates one independent object per nonblank line;
- every invalid fixture contains `expected-error.json` naming one required
  `VMxxx` code;
- validators report file, one-based line where applicable, JSON pointer and
  error code.

Required commands:

```powershell
pwsh -NoProfile -File tools/visual_mine/validate_visual_mine.ps1 -SelfTest

$runId = "visual-mine-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))"
pwsh -NoProfile -File tools/visual_mine/new_visual_mine.ps1 `
  -RepositoryRoot (Get-Location).Path `
  -RunId $runId `
  -Portfolio docs/visual_mine/portfolio-v1.json `
  -SourceSeeds docs/visual_mine/source-seeds-v1.json

pwsh -NoProfile -File tools/visual_mine/validate_visual_mine.ps1 `
  -RunRoot "artifacts/visual-mine/$runId"

pwsh -NoProfile -File tools/visual_mine/summarize_visual_mine.ps1 `
  -RunRoot "artifacts/visual-mine/$runId" `
  -OutputPath "artifacts/visual-mine/$runId/review/progress-summary.md"
```

Command-result rules:

- every script uses nonzero exit status for schema, quota, duplicate, rights or
  ownership failure;
- every invocation appends command, UTC start/end, exit code and output hash to
  `logs/command-results.jsonl`;
- `-SelfTest` accepts every `fixtures/valid` case and rejects every
  `fixtures/invalid` case by its expected error code;
- initialization refuses an existing run root;
- validation never rewrites evidence;
- summary output is derived and may be regenerated.

Required validator error codes:

`VM001_SCHEMA`, `VM002_ENUM`, `VM003_ID`, `VM004_DUPLICATE`,
`VM005_RIGHTS`, `VM006_QUOTA`, `VM007_OWNERSHIP`,
`VM008_OBSERVATION_LANGUAGE`, `VM009_REVIEW`, `VM010_HASH_DRIFT`.

## Required Records

### Run Manifest

`run-manifest.json` contains:

```json
{
  "schema_version": 1,
  "run_id": "visual-mine-YYYYMMDDTHHMMSSZ",
  "created_utc": "YYYY-MM-DDTHH:MM:SSZ",
  "repository_commit": "<40-character sha>",
  "quiz_export_sha256": "<sha256>",
  "authority_documents": [
    {"path": "docs/BATTLE_BOG_VISUAL_DIRECTION_BRIEF.md", "sha256": "<sha256>"}
  ],
  "portfolio_version": 1,
  "time_budget_hours": 12,
  "storage_budget_gib": 80,
  "status": "collecting",
  "coordinator": "<agent-or-user-id>"
}
```

Allowed `status` values:

`planned`, `collecting`, `cross_checking`, `synthesizing`,
`prototyping`, `awaiting_user_selection`, `selected`, `blocked`, `complete`.

### Job Board

`job-board.json` contains one record per job:

```json
{
  "schema_version": 1,
  "job_id": "FM-BAT",
  "lane": "full_mine",
  "question_ids": ["BAT-STARTUP"],
  "accepted_quota": 24,
  "quota_distribution": {"BAT-STARTUP": 6},
  "allowed_source_classes": ["P2", "S1"],
  "owner_id": null,
  "validator_id": null,
  "lease_expires_utc": null,
  "heartbeat_utc": null,
  "status": "queued",
  "accepted_count": 0,
  "reviewed_count": 0,
  "blocking_reason": null
}
```

Allowed `lane` values:

`full_mine`, `specialist`, `discovery`, `biology`, `boundary`, `validation`,
`synthesis`, `prototype`, `similarity_review`.

Allowed `status` values:

`queued`, `assigned`, `collecting`, `quota_met`, `cross_checking`,
`needs_rework`, `blocked`, `coverage_gap`, `budget_exhausted`, `complete`,
`cancelled`.

Only the integration owner changes job ownership or status. Agents update their
heartbeat through the coordinator rather than editing the board concurrently.

### Tool Manifest

`tool-manifest.json` records:

- operating system;
- PowerShell version;
- `ffmpeg` and `ffprobe` absolute paths and version strings;
- browser or research tool name and version when exposed;
- image-generation tool/model identifier only when M6 begins;
- acquisition method per source class;
- whether a tool transmits pixels to an external service;
- installation source, license and SHA-256 for any added executable.

M0 records `ffmpeg 8.0.1` as the observed version and records `yt-dlp` as
`not_installed`. It rechecks rather than trusting this note.

### Source Record

Each line of `source-ledger.jsonl` contains:

```json
{
  "schema_version": 1,
  "source_id": "SRC-<job-id>-<canonical-url-sha12>",
  "job_id": "<job-id>",
  "title": "<source title>",
  "publisher_or_channel": "<name>",
  "url": "<canonical URL>",
  "source_class": "S1",
  "game_version": "unknown",
  "platform": "PC",
  "published_date": "unknown",
  "accessed_utc": "YYYY-MM-DDTHH:MM:SSZ",
  "camera_type": "normal_player",
  "edited": false,
  "rights_status": "R1A_TRANSIENT_ANALYSIS",
  "rights_evidence_url": null,
  "local_retention": "none",
  "qualification": "accepted",
  "qualification_reason": "<one sentence>",
  "sha256": null,
  "null_reasons": {"/sha256": "not_retained"}
}
```

Enums:

- `camera_type`: `normal_player`, `spectator`, `cinematic`, `close_up`,
  `technical_presentation`, `not_applicable`;
- `rights_status`: `R0_LINK_ONLY`, `R1A_TRANSIENT_ANALYSIS`,
  `R1B_LOCAL_MEASURE`, `R2_MODEL_INPUT_OK`, `R3_SHIP_OK`, `RX_BLOCKED`;
- `local_retention`: `none`, `research_cache_only`,
  `approved_direct_input`, `project_owned`;
- `qualification`: `candidate`, `accepted`, `rejected`, `superseded`.

Rights classes are separate from evidence reliability:

- `R0_LINK_ONLY`: keep URL, citation and timestamps; do not inspect through an
  automated visual-analysis context or retain pixels;
- `R1A_TRANSIENT_ANALYSIS`: a human or analysis agent may inspect publicly
  accessible material through a permitted viewer for research; do not forward
  pixels, crops, embeddings, derived pose/depth controls or palettes to
  generation and do not retain a local copy;
- `R1B_LOCAL_MEASURE`: a minimal lawfully obtained research capture may be
  measured by deterministic local tools; keep outside Git and model context;
- `R2_MODEL_INPUT_OK`: item-level rights and provider terms permit direct AI
  visual input;
- `R3_SHIP_OK`: license and authorship permit inclusion or adaptation in the
  shipped product with all obligations recorded;
- `RX_BLOCKED`: ownership, license, acquisition or platform terms are
  unresolved or incompatible.

Only `R2_MODEL_INPUT_OK` or project-owned material may receive
`approved_direct_input`. Derived masks, pose skeletons, optical flow, depth
maps, crops, embeddings and palette extractions inherit the source item's
rights class.

### Evidence Record

Each accepted clip, still or document section receives one record:

```json
{
  "schema_version": 1,
  "evidence_id": "EVD-<source-sha12>-<question-id>-<start-ms>-<end-ms>",
  "source_id": "SRC-<job-id>-<canonical-url-sha12>",
  "primary_question_id": "<assigned question>",
  "question_id": "<assigned question>",
  "media_type": "clip",
  "start_sec": 123.400,
  "end_sec": 127.950,
  "extended_clip_reason": null,
  "page_or_section": null,
  "camera_type": "normal_player",
  "game_state": "teamfight",
  "actors_visible": 6,
  "observation": "<only what is visibly or textually present>",
  "measurement_ids": ["MEA-<evidence-sha12>-<metric>-<method-sha8>"],
  "inference": "<interpretation or null>",
  "evidence_type": "Observed",
  "confidence": "high",
  "transfer_rule": "<one neutral Battle Bog rule>",
  "non_transfer_rule": "<one source trait to reject>",
  "duplicate_of": null,
  "review_status": "pending",
  "reviewer_id": null,
  "null_reasons": {
    "/extended_clip_reason": "not_applicable",
    "/page_or_section": "not_applicable",
    "/duplicate_of": "not_applicable",
    "/reviewer_id": "not_yet_reviewed"
  }
}
```

Enums:

- `media_type`: `clip`, `still`, `document`, `local_capture`;
- `extended_clip_reason`: `sustained_flight`, `world_state`, `hud_state`,
  `long_transition` or `null`;
- `evidence_type`: `Documented`, `Observed`, `Inferred`;
- `confidence`: `high`, `medium`, `provisional`;
- `review_status`: `pending`, `confirmed`, `rejected`, `conflicted`.

`observation` cannot contain recommendation language such as `should`,
`better`, `use` or `copy`. Those belong in `inference`, `transfer_rule` or the
later synthesis.

### Measurement Record

Each line of `measurements.jsonl` contains:

```json
{
  "schema_version": 1,
  "measurement_id": "MEA-<evidence-sha12>-<metric>-<method-sha8>",
  "evidence_id": "EVD-<source-sha12>-<question-id>-<start-ms>-<end-ms>",
  "metric": "startup_duration_ms",
  "value": 300.0,
  "unit": "ms",
  "method": "frame_count",
  "sample_rate_fps": 60.0,
  "start_definition": "<visible event>",
  "end_definition": "<visible event>",
  "uncertainty": 16.67,
  "repeat_count": 1,
  "notes": "<limitations>",
  "null_reasons": {}
}
```

Allowed measurement families:

- time: startup, active, recovery, effect persistence, reacquisition;
- screen occupancy: width, height, area and distance as viewport percentages;
- motion: turn arc, bank onset, body-follow delay, formation lag;
- contrast: subject/background and warning/floor relationships;
- density: actors, warnings, effects and environmental-motion count;
- information: appearance, persistence and removal of a state cue;
- production: authoring time, atlas size, memory, draw calls and revision time.

Do not report false precision. Frame-count measurements use uncertainty of at
least one source frame.

`null_reasons` is an object whose keys are JSON pointers to fields that are
`null`. Every null field must have exactly one entry, and no non-null field may
have one. Allowed values are:

`not_reported`, `not_visible`, `not_applicable`, `not_retained`,
`not_yet_reviewed`, `source_quality`, `rights_blocked`, `tool_unavailable`.

For evidence clips from `6-20 s`, `extended_clip_reason` is `null`. A clip over
`20 s` is accepted only for sustained flight, world state, HUD state or a long
transition and must use the matching non-null enum. Other clips over `20 s`
fail `VM001_SCHEMA`.

IDs are deterministic:

- canonicalize a URL by removing tracking parameters, normalizing the platform
  video ID and preserving the content-specific path;
- `source_id` uses the first twelve lowercase hexadecimal characters of the
  canonical URL SHA-256;
- clip bounds use integer presentation timestamps in milliseconds;
- `evidence_id` uses the source hash, question ID and clip bounds;
- `measurement_id` uses the first twelve characters of the evidence SHA-256,
  normalized metric name and first eight characters of a SHA-256 over method,
  region and start/end definitions.

An ID collision with different content is `VM003_ID`; do not add a suffix.

### Extraction Contract

- Timing footage is uninterrupted, normal speed, at least `1280 x 720` and
  `30 FPS`. High-confidence timing requires one `60 FPS` source.
- Rare biological footage may be as low as `854 x 480`, but remains
  provisional.
- Combat clips begin `2.000 s` before first visible commitment and end
  `2.000 s` after neutral recovery, capped at `20.000 s`.
- Movement clips begin `1.000 s` before first displacement and end `1.000 s`
  after stopping, using `4-15 s`.
- Sustained flight, world and HUD evidence may use `10-30 s`; these are
  exempt from the ordinary `6-20 s` counting range and must use
  `extended_clip_reason`.
- Required combat observations are context, first commitment, startup
  midpoint, last pre-contact frame, first contact, maximum effect, recovery
  onset and neutral.
- Required movement observations are rest, first displacement, half-speed,
  turn or transition apex and settled state.
- Required world/HUD observations are before, onset, midpoint, peak and after.
- Preserve native frame rate, resolution and timestamps. Do not interpolate,
  upscale, recolor or crop the authoritative measurement region.
- Unknown values use `null` plus `null_reasons`; do not estimate version, frame
  rate, scale or hidden event boundaries.

### Confidence Calculation

Calculate:

`score = provenance + fitness + replication + measurement + review - conflict`

- provenance: `P1/P2/B1=3`, `S1/B2=2`, `O/S2/T/C/B3=1`;
- fitness: fully appropriate for the claim `2`, accepted exception `1`,
  otherwise reject;
- replication: independent publisher `2`, second event from one publisher `1`,
  none `0`;
- measurement: independently reproduced within tolerance `2`, measured once
  `1`, nonnumeric `0`;
- independent review pass: `1`;
- unresolved contradiction: subtract `2`.

Scores `8-10` are `high`, `5-7` are `medium`, and `0-4` are `provisional`.
Inferences remain provisional until M5 regardless of score.

### Dedupe And Contradictions

- exact canonical URL or content SHA-256 matches are duplicates;
- retained research stills are duplicates at perceptual-hash Hamming distance
  `<= 6`;
- clips are near-duplicates when duration differs by `<= 500 ms` and frames at
  `10%`, `50%` and `90%` each have Hamming distance `<= 8`;
- retain, in order, claim-eligible camera, unedited footage, higher resolution,
  higher frame rate and earlier publication;
- open a contradiction when timing differs by more than
  `max(2 native frames, 15%)`, occupancy differs by more than `10%` relative,
  or categorical observations disagree;
- never average contradictory contexts; split by version, camera, load,
  creature or state, or preserve both hypotheses for prototyping.

## Agent Job Packet

Every mining agent receives exactly:

1. one `job_id`;
2. one approved question set;
3. a source seed list;
4. the accepted-evidence quota;
5. source classes allowed for its claims;
6. the output directory;
7. record schemas and enums;
8. rejection boundaries;
9. a no-edit ownership boundary outside its job directory;
10. the completion and escalation rules below.

An agent may discover additional sources inside its assigned question. It may
not broaden its reference into an unassigned style study.

Use this exact assignment prompt after replacing bracketed values:

```text
You own Battle Bog visual-mine job [JOB_ID] only.

Repository: C:\Users\fishe\Documents\hitmasters
Run root: [ABSOLUTE_RUN_ROOT]
Write scope:
- [ABSOLUTE_RUN_ROOT]\sources\[JOB_ID]
- [ABSOLUTE_RUN_ROOT]\evidence\[JOB_ID]
- [ABSOLUTE_RUN_ROOT]\rule-cards\[JOB_ID].md

Read:
- docs/BATTLE_BOG_VISUAL_DEEP_MINING_EXECUTION_PLAN.md
- docs/BATTLE_BOG_VISUAL_DIRECTION_BRIEF.md
- your entry in docs/visual_mine/portfolio-v1.json
- your sources in docs/visual_mine/source-seeds-v1.json

Collect only question IDs: [QUESTION_IDS].
Accepted-evidence quota: [QUOTA].
Permitted claims and source classes: [CLAIM_RULES].
Rejection boundaries: [BOUNDARIES].

Append schema-valid source, evidence and measurement records. Do not edit
another job, synthesis, review, source code or tracked assets. Do not put
copyrighted pixels into image generation, embeddings, derived visual controls,
Git or shipped assets. Count a unique 6-20 second clip toward one primary
question only. Record rejected and duplicate sources.

Finish only when the job completion rule passes. Otherwise return the exact
missing quota or escalation condition and leave resumable records in place.
```

### Concurrency Topology

Use bounded parallelism:

```text
1 integration owner
├── up to 5 source miners
├── up to 5 biological miners
├── up to 5 specialist/discovery miners
├── up to 5 independent validators
└── 2 similarity reviewers
```

Run at most five pixel-bearing research jobs concurrently. Additional agents
may process textual primary sources, validate schemas or synthesize sanitized
records. A miner never validates its own records. The integration owner does
not mine a source while coordinating active jobs.

When one agent finishes, assign the next queued job from the same wave. Do not
spawn multiple agents onto the same job directory.

Each active job receives a `60 min` lease and writes a heartbeat every
`5 min`. A job is reclaimable only after lease expiry plus `15 min` without a
heartbeat. Agents checkpoint after every accepted or rejected evidence item.
Use temporary `.partial` files and atomic rename for non-JSONL records.

### Agent Completion Rule

A source-mining job is complete only when:

- every quota row is satisfied;
- at least two independent sources support each production-facing rule;
- every accepted record has one transfer and one non-transfer rule;
- every accepted record has a second-review result;
- duplicates and rejected candidates are recorded;
- unresolved contradictions are listed;
- the miner writes its job rule card;
- the validator reports no schema or enum error.

### Escalation Rule

Set the job to `blocked` only when one of these occurs:

- the required normal-camera evidence does not publicly exist;
- rights status prevents the requested direct-input use;
- two high-confidence sources materially contradict;
- the assigned quota cannot be met after twenty qualified candidate sources;
- the authority documents conflict;
- the evidence would require bypassing access controls or source terms.

For a quota shortage, record the exact missing category and continue all other
categories. Do not invent substitutes.

## Mining Waves

### M0 - Substrate And Freeze

Before content mining:

1. calculate the repository and quiz-export hashes;
2. create the run manifest and job board;
3. validate the source, evidence and measurement schemas;
4. verify `ffmpeg` and `ffprobe`;
5. record acquisition tools and versions;
6. freeze the portfolio and quotas in the run manifest;
7. assign disjoint job directories;
8. record a default `12 h` run-time budget and `80 GiB` local-storage ceiling;
9. require at least `15 GiB` free before starting a pixel-bearing job.

`yt-dlp` is not currently available on the verified workstation. M0 must not
assume it exists. Acquisition must use lawful browser/manual capture or a
separately approved installation recorded in the tool manifest.

M0 passes when an empty test record for every schema validates and can be
resumed after interruption without changing IDs.

M0 ownership is exactly the files under `tools/visual_mine/` and
`docs/visual_mine/`. It must not edit gameplay, renderer or runtime-asset
files.

`portfolio-v1.json` is a mechanical transcription of the jobs, question IDs,
quotas, source classes and boundaries in this plan. `source-seeds-v1.json`
contains every active-portfolio URL already listed in
`RESEARCH_VISUAL_DEEP_MINE_SOURCE_LEDGER.md`. M0 does not discover or rank new
sources. Discovery begins only in the assigned M1, M2, M3 or `DG-*` job.

M0 closeout:

```powershell
pwsh -NoProfile -File tools/visual_mine/validate_visual_mine.ps1 -SelfTest
git diff --check
git status --short
```

Commit only M0-owned tracked files. The created `artifacts/` run root remains
ignored and is not staged.

### M1 - Primary Anchor Mine

Run `FM-BAT`, `FM-SUP` and `FM-UNI` in parallel.

Each miner produces:

- source and evidence ledgers;
- measurements;
- one contact sheet for human research review only from
  `R1B_LOCAL_MEASURE`, `R2_MODEL_INPUT_OK` or project-owned material; otherwise
  use a URL/timestamp review index with no retained pixels;
- one rule card;
- one rejection card.

Research contact sheets stay in `artifacts/` and are never direct inputs to an
image-generation model.

### M2 - Biological Mine

Run creature packets by movement family:

- amphibious crawlers and hoppers;
- long-bodied swimmers and crawlers;
- birds and continuous fliers;
- heavy, shelled and planted bodies;
- small skimmers and swarm bodies.

Species exceptions remain separate records. A family rule cannot erase a
species-specific gait, strike or terrain behavior.

### M3 - Specialist Mine

Run specialist jobs in parallel after their corresponding M1 question has a
draft rule:

- combat and impact;
- night and wetland world;
- flight, long body and swarm;
- information, HUD and switching;
- production pipeline.

Run the six discovery-gap jobs before assigning a newly discovered specialist.
Temtem and Evercore begin with M3 as extended specialist anchors.

Each specialist job may amend a draft rule only through a conflict record. It
does not edit the synthesis directly.

### M4 - Independent Cross-Check

A validator who did not mine the record reviews:

- source class;
- clip bounds or section;
- observation/inference separation;
- measurement method;
- transfer and rejection rules;
- duplicate status;
- rights status.

Reject records with missing fields. Mark disagreement `conflicted`; do not
silently rewrite the first miner's observation.

Reviewers remeasure `25%` of numeric evidence, with at least two records per
job. Every measurement supporting a high-confidence rule is remeasured.
Allowed disagreement is one native frame for time and `5%` relative for
screen-space measurements. Any rights error or more than `5%` failed audited
fields expands review to `100%` of that job. A third reviewer adjudicates
unresolved contradictions.

### M5 - Cross-Source Synthesis

Create one rule card per visual problem. A production-facing rule requires:

- three unrelated game references when three applicable sources exist;
- one real-animal source for creature shape or motion;
- one Battle Bog gameplay truth;
- at least one explicit rejected trait;
- one normal-camera acceptance test;
- one confidence label.

Rule-card form:

```text
RULE ID:
PROBLEM:
SOURCE OBSERVATIONS:
BIOLOGICAL CHECK:
BATTLE BOG TRUTH:
TRANSFER RULE:
REJECT:
MEASURABLE RANGE:
PROTOTYPE STATE:
FAILURE SIGNAL:
CONFIDENCE:
EVIDENCE IDS:
```

When sources disagree, prefer:

1. Battle Bog gameplay truth;
2. normal-camera evidence over edited presentation;
3. biological evidence for authentic motion;
4. the clearer low-load rule as the default;
5. the more expressive high-load rule as an optional escalation ceiling.

Do not average incompatible styles. Preserve the disagreement as two prototype
hypotheses.

### M6 - Prototype Input Brief

Translate accepted rule cards into neutral Battle Bog descriptors. The brief
must not name reference games in image-generation prompts.

Each descriptor must state:

- subject and species;
- heroic anatomical exaggeration;
- apparent scale tier;
- material and value hierarchy;
- camera and projection;
- terrain and water state;
- exact attack or movement phase;
- body, shadow and truth-marker relationship;
- team and warning information;
- effect occupancy ceiling;
- HUD mode;
- traits explicitly absent.

Copyrighted reference frames may be inspected only under their recorded
research rights class. They remain outside image generation, fine-tuning,
training, embedding, persistent visual-control extraction and prompt
attachments. Direct visual inputs are limited to project-owned or
`R2_MODEL_INPUT_OK` material.

## Four Look Candidates

Generate four original directions from the same neutral brief. These are
synthesis emphases, not imitations of a source.

| Candidate | Emphasis | Required Difference |
| --- | --- | --- |
| `A Competitive Naturalist` | crisp silhouettes, restrained materials, precise anticipation and quiet terrain under combat | lowest effect occupancy and strongest value separation |
| `B Luminous Ecology` | richer wetland material layers, reactive water/foliage and more dimensional altitude cues | richest environment that still yields to warnings |
| `C Heroic Fauna` | bold species anatomy, softer surfaces and strongest creature-first scale readability | clearest creature identity at the simplest surface detail |
| `D Painted Kinetics` | authored key poses, material-specific impacts and expressive ordinary abilities | strongest motion/impact statement within the readability ceiling |

All four use identical:

- `1280 x 720` player-camera framing;
- PvAI camera zoom `2.6`, with the mixed-fight stress duplicate at 3v3 zoom
  `2.2`;
- map location and geometry;
- northwest key light and southeast projected shadow;
- creature positions, truth footprints and team ownership;
- alligator, kingfisher, mosquito swarm and frog cast;
- attack phase and target;
- time of day;
- HUD information;
- text labels outside the image;
- output resolution and generation iteration budget.

Build one project-owned greybox control image and masks for:

- walkable terrain;
- water depth;
- creature positions and truth footprints;
- team ownership;
- telegraph geometry;
- HUD regions.

Every candidate may use those project-owned controls. Candidate-specific
composition changes outside the masks are a hard comparison failure.

### Required Prototype Board

Each candidate contains eight panels:

1. day traversal with all four body families;
2. dusk shoreline transition;
3. night objective approach;
4. alligator startup;
5. kingfisher incoming dive and projected landing point;
6. mosquito swarm overlap and hit response;
7. mixed 3v3 objective fight with simple HUD;
8. the same objective state with expanded HUD.

Each candidate also contains three motion studies:

- alligator `start -> turn -> bite startup -> active -> recovery`;
- kingfisher `takeoff -> bank -> dive warning -> impact -> low window`;
- mosquito `cohere -> spread -> converge -> hit -> reform`.

Still images may establish the look. Motion studies must later be authored as
storyboards, animatics or in-engine tests before animation decisions become
production rules.

For panels `4-8`, also produce grayscale, protanopia, deuteranopia and
tritanopia review transforms. These transforms are evaluation derivatives, not
new candidate iterations.

### Generation Protocol

For each panel:

1. generate one composition thumbnail from the neutral project brief;
2. reject composition errors before style refinement;
3. generate at most three refinement iterations;
4. retain the same seed when the tool supports it;
5. record prompt, negative constraints, model/tool, version, seed and output
   hash;
6. reject anatomy, camera or gameplay-truth errors;
7. do not repair a failed candidate by changing the shared scene;
8. package accepted panels under anonymous labels `A-D`.

Generated images are concept evidence, not production sprites and not proof of
runtime feasibility.

### Similarity Gate

Two reviewers who did not author the output compare every accepted generated
candidate against the mined source set. Rate each dimension `0-3`:

- silhouette;
- proportions;
- key pose;
- motion sequence;
- composition;
- palette and material grouping;
- VFX motif;
- UI arrangement.

Ratings:

- `0`: no source-specific resemblance;
- `1`: generic functional resemblance;
- `2`: recognizable source-specific resemblance;
- `3`: reproduction or near-reproduction.

Acceptance requires no `2` or `3`, no logo, trademark or signature motif and
agreement from both reviewers. Disagreement fails closed and returns the panel
to revision. This is an originality gate, not a legal safe harbor.

## Look Selection

The user has final taste authority. Automated and reviewer scores organize the
comparison but do not replace that choice.

Score every candidate from `1-5` on:

| Criterion | Weight |
| --- | ---: |
| creature/species readability | 20 |
| combat anticipation and hit clarity | 20 |
| motion and altitude implication | 15 |
| wetland richness without interference | 15 |
| HUD and information hierarchy | 10 |
| originality and source separation | 10 |
| plausible production path | 10 |

Before scoring:

- hide candidate emphasis names and generation metadata;
- randomize `A-D` display order;
- show the same panel order;
- include a `none are ready` option;
- ask the user to identify strongest candidate, strongest individual traits,
  unacceptable traits and desired hybrid.

Selection outcomes:

- `SELECT`: one candidate becomes the direction;
- `HYBRIDIZE`: combine only the specifically selected traits and regenerate
  two refined finalists plus one convergence candidate whose source traits are
  named explicitly;
- `REVISE`: rerun named failed panels without changing accepted decisions;
- `RESTART`: reopen M5 only when all candidates fail for the same missing rule.

Record the result in `selection-record.json`. No agent selects a direction on
the user's behalf.

A convergence record must use this form:

```text
CREATURE FORM FROM: <candidate + named trait>
WORLD HIERARCHY FROM: <candidate + named trait>
MATERIAL RESPONSE FROM: <candidate + named trait>
COMBAT/VFX FROM: <candidate + named trait>
HUD FROM: <candidate + named trait>
REJECTED TRAITS: <explicit list>
```

An instruction such as `blend A and B` is invalid.

## Selected-Look Deliverables

After `SELECT` or accepted `HYBRIDIZE`, create:

1. `docs/BATTLE_BOG_SELECTED_VISUAL_DIRECTION.md`;
2. creature anatomy and scale sheets for the four representative families;
3. color, value, material and lighting grammar;
4. day/dusk/night world boards;
5. water, shoreline and reactive-ecology rules;
6. telegraph, projectile, impact and recovery vocabulary;
7. simple/contextual/expanded HUD boards;
8. animation timing and species-motion briefs;
9. production-pipeline requirements;
10. an implementation delta against
    `docs/BATTLE_BOG_VISUAL_IMPLEMENTATION_ROADMAP.md`.

The selected look still enters the Alligator, Kingfisher, Mosquito and real
3v3 runtime gates. A concept preference does not automatically select live 3D,
pre-rendered atlas, 2D rig or hand-authored production.

## Stopping And Saturation

Do not run an unbounded overnight scrape.

A job stops when all completion rules pass or when an escalation rule is hit.
Additional sources are accepted after quota only when they add one of:

- a missing body family or game state;
- a contradictory high-confidence behavior;
- a better normal-camera version of existing evidence;
- a missing day/night, water, flight or crowd condition;
- a documented production method unavailable in current records.

After quota, ten consecutive qualified candidates that add none of those
conditions establish saturation for that job.

Problem lanes and required jobs:

| Lane | Required Jobs | Optional Depth Jobs |
| --- | --- | --- |
| combat clarity and impact | `FM-BAT`, `FM-SUP`, `SP-MAC`, `SP-HAD` | none |
| creature form and material | `FM-UNI`, `SP-TEM`, all `BIO-*`, `DG-MAT` | none |
| wetland world and night | `SP-EVE`, `SP-ALB`, `DG-WET` | `SP-RAV`, `SP-WIL` |
| flight, long body, swarm and depth | `SP-FLO`, `SP-RAI`, `SP-PIK`, `DG-SUB`, `DG-LON`, `DG-DIV` | none |
| information, HUD and switching | `SP-DOT`, `SP-DAO`, `DG-SWI` | `SP-HOT`, `SP-APX` |
| production method | `SP-DEA`, `SP-KLE` | none |

Required prototype-variable coverage:

| Variable | Complete Jobs That May Satisfy It | Minimum Complete |
| --- | --- | ---: |
| `PV-CREATURE-FORM` | `FM-UNI`, `SP-TEM`, `BIO-ALL`, `BIO-KIN`, `BIO-MOS` | 4 |
| `PV-COMBAT` | `FM-BAT`, `FM-SUP`, `SP-MAC`, `SP-HAD` | 3 |
| `PV-FLIGHT` | `FM-SUP`, `SP-FLO`, `DG-DIV`, `BIO-KIN` | 3 |
| `PV-SUBMERGENCE` | `DG-SUB`, `SP-ALB`, `BIO-ALL` | 2 |
| `PV-LONG-BODY` | `SP-RAI`, `DG-LON`, `BIO-ALL`, `BIO-SNK` | 3 |
| `PV-SWARM` | `SP-PIK`, `BIO-MOS`, `FM-UNI` | 2 |
| `PV-WORLD` | `SP-EVE`, `SP-ALB`, `DG-WET`, `FM-SUP` | 3 |
| `PV-NIGHT` | `SP-EVE`, `SP-RAV`, `FM-SUP` | 2 |
| `PV-HUD` | `FM-BAT`, `FM-SUP`, `SP-DOT`, `SP-DAO` | 3 |
| `PV-PIPELINE` | `SP-DEA`, `SP-KLE` | 2 |
| `PV-MATERIAL` | `DG-MAT`, `SP-HAD`, `SP-TEM` | 2 |

Only jobs with status `complete` count. `coverage_gap` and
`budget_exhausted` do not count. The validator computes each row and emits
`VM006_QUOTA` with the missing variable when a minimum is not met.

The overall mine stops before prototyping only when:

- all `FM-*`, required `SP-*`, `BIO-*`, `DG-*` and `BD-*` jobs are
  `complete` or have an independently confirmed `coverage_gap`;
- every prototype-variable minimum above passes;
- at least two of `SP-RAV`, `SP-WIL`, `SP-HOT`, `SP-APX` are `complete`;
- every incomplete optional job screened twenty qualified candidates and
  records `coverage_gap` or `budget_exhausted`;
- every production-facing rule has independent review;
- no unresolved conflict affects a prototype prompt.

The integration owner computes this gate from `job-board.json`; no percentage
or subjective lane-coverage judgment is permitted. Missing optional jobs remain
documented gaps and do not justify extending another source beyond its approved
responsibility.

## Resumption

On interruption:

1. read `run-manifest.json`;
2. verify repository and authority-document hashes;
3. read `job-board.json`;
4. resume only jobs in `assigned`, `collecting`, `cross_checking` or `blocked`;
5. recompute deterministic IDs and skip records whose ID and content hash
   already exist;
6. never rewrite accepted JSONL records;
7. append corrections using `supersedes_id`;
8. rerun schema validation before new collection;
9. create a new run when authority hashes or portfolio version changed.

Do not merge two run roots by copying files. The integration owner may import
accepted records through a new manifest that names their originating run and
hash.

## Promotion Boundary

Research artifacts may be promoted only as follows:

| Artifact | Destination | Required Gate |
| --- | --- | --- |
| textual rules and citations | `docs/` | cross-check complete |
| project-owned generated concept boards | `assets/concepts/` | provenance and similarity review |
| copyrighted contact sheets or clips | nowhere tracked | remain under ignored `artifacts/` |
| production sprites, models or animation | runtime asset tree | selected look plus runtime pipeline gate |
| gameplay or renderer code | source tree | owning roadmap phase and tests |

The integration owner confirms `git status` before promotion and stages only
the reviewed durable outputs.

## Immediate Execution Queue

```text
[next] M0A create schemas, validator and resumable run initializer
[next] M0B freeze source seeds and exact question IDs
[next] M0C create job packets and tool manifest
       |
       +──▶ M1 full-anchor miners
       +──▶ M2 biological family miners
              |
              v
            M3 specialists
              |
              v
            M4 independent cross-check
              |
              v
            M5 synthesis
              |
              v
            M6 neutral prototype brief
              |
              v
            M7 four candidate boards
              |
              v
          [human] look selection
              |
              v
            M8 selected-look bible and implementation delta
```

No new taste question is required before M0-M6. The next required user decision
is the look-selection gate after the four comparable candidate packages exist,
unless an escalation rule is triggered first.
