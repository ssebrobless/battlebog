# Battle Bog Visual Reference Mining Candidates

Status: quiz completed; selections interpreted in
`docs/BATTLE_BOG_VISUAL_DIRECTION_BRIEF.md`

Compiled: 2026-07-27

Interactive decision tool:
`tools/visual-reference-quiz/index.html`

This document defines what Battle Bog needs from visual reference research,
records the first open-ended candidate search, and proposes a shortlist for
discussion. It does not authorize copying another game's assets or visual
identity, and it does not lock a production-art pipeline.

The deep footage mine begins only after the candidate portfolio is discussed
and approved.

## Research Shape

```text
CURRENT GAME AUDIT
        |
        v
VISUAL NEEDS AND LOCKED CONTRACTS
        |
        v
OPEN-ENDED CANDIDATE DISCOVERY
        |
        v
SOURCE AND FIT CROSS-EXAMINATION
        |
        v
USER SELECTS REFERENCE PORTFOLIO
        |
        v
FOOTAGE / IMAGE MINE
        |
        v
ORIGINAL BATTLE BOG DESIGN RULES
        |
        v
REPRESENTATIVE PROTOTYPES
        |
        v
PRODUCTION DECISION
```

## Current Visual State

Battle Bog is mechanically much further along than its production art.

### What Already Exists

- One unified `480 x 170` world-unit competitive map with streams, central
  water, bridges, habitats, encounter zones, structures, food, obstacles and
  mirrored side layouts.
- Twenty-one selectable creatures across five families.
- Creature-specific footprints, model scale, height, movement profiles,
  terrain transitions, flight states, attack cues and gameplay roles.
- Eleven procedural body archetypes with species-specific skins and selected
  silhouette features.
- Distinct movement primitives including hops, scuttles, slithers, heavy
  pivots, bounds, paddles, waddles, flight, hover, swarms and inchworm motion.
- Fixed gameplay footprints, truth rings, long-body capsule support, contact
  shadows, altitude separation and low-flight punish-window cues.
- Event-driven hit flashes, impact effects, damage numbers, telegraphs,
  weakpoints and render-only hitstop.
- Visibility states for visible, revealed, heard, last-known, suspected and
  hidden enemies.
- A minimap, squad state, hunger, stocks, ability resources, boss states,
  objective events and match results.
- Cached static terrain, throttled water and UI redraws, off-screen creature
  redraw suppression and a performance harness.

### What Does Not Yet Exist

- No production creature sprite sheets, rigs, animation clips, atlases,
  materials or shaders.
- No production environment tiles, textures, decals or prop atlases.
- No animation schema mapping gameplay states to authored clips, facings,
  pivots, sockets or attachment points.
- No screenshot or short-video regression suite for actual pixel readability.
- No committed visual-production performance baseline.
- No deliberate final HUD hierarchy, accessibility layer or unified Battle
  Bog menu identity.

The only conventional tracked bitmap asset found during the audit was the
application icon. Ordinary creatures, wildlife, food, terrain, structures,
water and most effects are drawn procedurally with CanvasItem primitives.

## Central Diagnosis

```text
MATURE GAMEPLAY STATE
        |
        +--> authored movement parameters
        +--> visibility and objective data
        +--> deterministic collision truth
        +--> performance-aware redraw rules
        |
        v
PROCEDURAL PRESENTATION ADAPTER
        |
        v
PLACEHOLDER-LEVEL FINAL PIXELS
```

The safest likely upgrade is a hybrid presentation:

1. Authored creature and environment art communicates anatomy, material,
   personality and place.
2. Existing procedural overlays continue to communicate collision truth,
   team, danger, altitude, weakpoints, visibility and objective state.
3. Gameplay timing remains simulation-owned. Animation exposes timing; it
   does not silently redefine it.

This is a research hypothesis, not a locked pipeline decision.

## Important Non-Visual Blocker

The audit found that many ordinary attacks currently emit a warning and apply
damage in the same simulation call. Bosses more consistently implement
warning, active, aftermath and recovery phases.

Prettier animation cannot create a real reaction window when the simulation
does not provide one. Before final combat animation is authored, ordinary
damaging abilities need explicit startup, active and recovery ownership. The
reference mine should measure good timing and pose language, but implementation
must first make those phases real.

## Locked Visual Contracts

Reference material is useful only when it can be translated without breaking
these Battle Bog rules:

1. One design unit remains 16 pixels unless a separately approved scale
   decision changes it.
2. Gameplay footprints and hurtboxes remain authoritative.
3. The team truth ring stays aligned to the actual combat radius.
4. Torso mass stays mostly inside the footprint; thin extremities may overhang.
5. Visual scale, collision scale and flight height remain separate concepts.
6. Lighting reads from northwest with a shared southeast shadow direction.
7. Environment saturation and contrast remain subordinate to creatures,
   teams, telegraphs and interaction cues.
8. Team and telegraph colors retain exclusive high-saturation roles.
9. Static world art is cached; animation is isolated, throttled or
   event-driven.
10. Deterministic simulation is not altered by decorative animation.
11. Telegraphs and other fair counterplay cues cannot disappear merely
    because the attacker is hidden.
12. Visual production waits for the PvAI human gate, although reference
    research and pipeline experiments may be prepared beforehand.

The existing decision mentioning real 16-pixel sprite sheets is a strong prior,
not a reason to skip pipeline comparison. If evidence favors another approach,
the decision must be revised explicitly rather than bypassed accidentally.

## Concrete Visual-Needs Matrix

| Priority | Need | Current State | Reference Question | Required Outcome |
| --- | --- | --- | --- | --- |
| P0 | Production asset pipeline | Procedural Canvas drawing only | Which authored pipeline supports 21 creatures, 360-degree intent and small screen footprints? | A measured prototype decision, import contract and asset-state schema |
| P0 | Species identity | 21 creatures share 11 body archetypes | How do polished games preserve anatomy and personality at normal gameplay zoom? | Readable silhouettes and species-specific pose vocabulary |
| P0 | Combat anticipation | Many attacks lack real pre-hit time | How early is an attack readable, and how are hit and recovery frames separated? | Simulation timing contract plus authored pose requirements |
| P0 | Pixel validation | Tests mostly inspect state dictionaries | What actually remains readable in crowded live frames? | Screenshot/video regression suite and human acceptance checks |
| P1 | Movement authenticity | Strong parameters, limited authored anatomy | Which gait details survive at 10-67 pixel creature radii? | Movement-family animation briefs and creature-specific exceptions |
| P1 | Flight and depth | Generic rings, brackets, shadows and scale changes | How do players read altitude, landing point, dive path and punish timing early? | Species-specific air poses plus persistent ground truth |
| P1 | Crowded 3v3 combat | Effects, bars and numbers can stack without priority | How do games budget effects and preserve target identity under pressure? | Priority tiers, suppression rules and occlusion limits |
| P1 | Material hit language | Generic circles, lines, cones and flashes | How do fur, feather, shell, scale, chitin, mud and water react differently? | Original material-response vocabulary |
| P1 | Living wetland | Rectilinear streams, repeated props, generic ripples | How do wetland materials and motion feel alive without burying combat? | Terrain kit, prop families and reactive ambient-motion budget |
| P1 | Diegetic information | Rings, ellipses and labels expose mature systems | How can reeds, mud, water and wildlife communicate uncertainty and events? | World cue grammar for sound, suspicion, reveal and aftermath |
| P1 | HUD hierarchy | Functional but telemetry-heavy and abbreviated | How does the UI answer what, why, where and how long during action? | Combat HUD, objective tracker, broadcasts and minimap hierarchy |
| P2 | Day/night embodiment | Vision values change more than the world does | How do phases alter information and mood while preserving fairness? | Lighting and ambient-state rules with telegraph contrast guarantees |
| P2 | Habitat identity | Functional rectangular bases and boundaries | How do home areas read instantly and show stock, damage and activity? | Distinct habitat silhouettes and stateful prop language |
| P2 | Accessibility | No presentation-wide settings layer | How are critical cues redundant beyond color and sound? | UI scale, color-independent shapes and reduced-effects rules |
| P2 | Roster presentation | Gameplay renderer loops in a diagnostic preview | How do selection screens show identity without misrepresenting play scale? | Authored idle/ability preview and gameplay-scale continuity |

## Footage Acceptance Standard

A candidate is not valuable merely because its key art looks attractive.

Useful footage should show:

- the normal player camera and ordinary HUD;
- unedited movement starts, stops, reversals and tight turns;
- attacks that hit and attacks that miss;
- readable startup, active contact and recovery;
- crowded fights at native resolution;
- objective warning, approach, contest, interruption, claim or steal, reward
  and aftermath;
- transitions between visible, uncertain and reacquired information;
- land/water entry, wakes, splashes and shoreline contact;
- takeoff, sustained flight, dive, landing and punish windows;
- calm traversal as well as combat;
- low health, low hunger or other critical resource states;
- death, respawn, creature switching and results where relevant.

Trailers can establish intended art direction but cannot be used for timing,
camera-density or HUD measurements.

## Source Confidence Labels

Every deep-mine entry should carry one label:

- `P1`: primary technical source from the developer, engine owner or official
  conference presentation.
- `P2`: official gameplay or an official full match at a representative camera.
- `S1`: credible raw player gameplay with the normal HUD.
- `S2`: tournament or spectator footage that may alter the player UI.
- `T`: edited trailer, useful only for intended presentation.
- `C`: community guide, wiki or analysis that needs corroboration.

Each captured observation should also distinguish:

- `Observed`: directly visible in cited footage.
- `Documented`: explicitly stated by a primary source.
- `Inferred`: a Battle Bog interpretation that still needs prototype testing.

## Selection Principle

No single game should become Battle Bog's visual template. The portfolio should
select different references for different jobs:

```text
COMBAT GRAMMAR .......... anticipation, hits, recovery, crowd priority
CREATURE LANGUAGE ....... silhouette, gait, flight, long bodies, swarms
WORLD LANGUAGE .......... wetland materials, water, vegetation, uncertainty
INFORMATION DESIGN ...... objectives, minimap, warnings, squad state
PRODUCTION PIPELINE ..... repeatable authored assets at acceptable cost
NATURAL REFERENCE ....... real animal anatomy and behavior
```

The final synthesis must derive original Battle Bog rules from multiple
references. It must not reproduce a source game's character designs, textures,
UI layouts, animation frames, proprietary files or recognizable style package.

## Recommended Reference Portfolio

The first discovery pass considered more than thirty games. The cross-examined
portfolio below is the smallest set that still covers Battle Bog's major
questions without treating one game as a wholesale style target.

### Core Deep-Mine Games

| Game | Primary Job | Why It Earns Deep Study | Main Guardrail |
| --- | --- | --- | --- |
| Battlerite | Direct-control 3v3 combat | Closest camera, movement, aim and teamfight structure for anticipation, hits, whiffs, recovery and effect priority | Its arenas do not teach Battle Bog's macro loop or wetland world |
| SUPERVIVE | Layered information and crowded objectives | Best combined reference for vertical states, off-screen information, objective escalation, revival priority and high-load fights | It is already a major inspiration; extract rules without inheriting its visual identity |
| Pokemon UNITE | Competitive creature readability | Recognizable creatures, wild objectives, scoring/deposit pressure and dense fights at a related camera scale | Do not inherit toy-like gloss, extreme proportion inflation or mobile-control UI |
| Don't Starve Together | Reusable authored 2D fauna and wetland vocabulary | Strong silhouettes, modular creature construction, compact animation, marsh props and readable ambient motion | Its paper-cutout identity is distinctive and its combat is less competitive |
| Rain World | Animal body mechanics | Best specialist-quality core source for long bodies, terrain contact, weight, swimming, lunges and procedural-looking motion | Side-view composition does not transfer directly to Battle Bog |
| V Rising | World hierarchy, phase lighting and creatures | Organic terrain, day/night embodiment, water, creature traffic, bosses and readable combat over detailed environments | Its 3D production scope and dynamic lighting budget are much larger |

### Specialist Samples

These need targeted clips and measurements, not a complete-game mine.

| Game | Narrow Question |
| --- | --- |
| Flock | Banking, ascent/descent, altitude, formation lag and readable airborne groups |
| Pikmin 4 | Swarm cohesion, target convergence, carrying formations, water entry and group hit response |
| Darkwood | Sound-only threats, suspected position, concealed movement, water danger and night transformation |
| Dota 2 | Fog, minimap information, silhouette discipline and extreme teamfight density |
| Dragon Age: Origins | Immediate control switching while released party members resume autonomous behavior |

### Technical and Pipeline Sources

These sources explain production methods. They are not automatic style targets.

| Source | What It Can Establish |
| --- | --- |
| [Klei: 2D Animation at Klei](https://gdcvault.com/play/1020949/2D-Animation-at-Klei) | Symbol animation, reusable components, atlases, animation libraries and state graphs |
| [Dead Cells 3D-to-2D production deep dive](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-) | Reusable 3D rigs rendered to low-resolution 2D frames and normal maps |
| [Cult of the Lamb developer explanation](https://steamcommunity.com/app/1313140/discussions/0/3448087385671383167/) | Illustrated 2D rigs in a depth-aware 3D world |
| [Hades character-production video](https://www.youtube.com/watch?v=cYJ6d1ifSqA) | High-end 3D-derived painted sprite production |
| [Riot rendering pipeline](https://technology.riotgames.com/node/55) | Top-down live-3D outlines, shadows, fog, particles and value hierarchy |
| [Dota 2 character-art guide](https://help.steampowered.com/en/faqs/view/0688-7692-4D5A-1935) | Top-down silhouette, directionality, value and detail placement |
| [Godot AnimatedSprite2D](https://docs.godotengine.org/en/4.6/classes/class_animatedsprite2d.html) | Native sprite-sheet runtime |
| [Godot 2D skeletons](https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html) | Native cutout and bone-deformation option |
| [Godot 3D scene import](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_3d_scenes/index.html) | Blender/glTF path for restrained live-3D experiments |

### Coverage Matrix

`P` means primary reference for that question. `S` means supporting reference.

| Reference | 3v3 | Crowds | Creature silhouette | Gait | Flight | Swarms | Long body | Water/wetland | Night/uncertainty | HUD/objectives | Switching | Pipeline |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Battlerite | P | P | S | - | - | - | - | - | - | S | - | S |
| SUPERVIVE | S | P | S | - | P | - | - | S | S | P | - | S |
| Pokemon UNITE | S | P | P | S | S | S | S | S | - | P | - | S |
| Don't Starve Together | - | S | P | P | S | S | S | P | S | - | - | P |
| Rain World | - | - | P | P | S | S | P | P | S | - | - | S |
| V Rising | S | S | P | P | S | S | P | P | P | S | - | P |
| Flock | - | - | S | P | P | P | S | - | - | - | - | - |
| Pikmin 4 | - | P | P | S | S | P | - | S | - | S | - | S |
| Darkwood | - | - | S | S | - | - | - | P | P | S | - | S |
| Dota 2 | - | P | P | - | S | S | S | S | P | P | - | P |
| Dragon Age: Origins | - | S | S | - | - | - | - | - | - | S | P | S |

## Initial Footage Ledger

These links were checked for public availability during the discovery pass.
Sequence labels and timestamps remain candidate anchors until the deep mine
performs frame-level verification.

### Combat and Objectives

- Battlerite:
  - [Raw 3v3 full match](https://www.youtube.com/watch?v=7pQxQiIIAdk)
    (`S1`): normal player camera for timing, HUD and clutter.
  - [3v3 Grand Finals player footage](https://www.youtube.com/watch?v=mDCP_SOcX_U)
    (`S1`): sustained competitive pressure and round flow.
- SUPERVIVE:
  - [Official full-match gameplay](https://www.youtube.com/watch?v=Fs9pGnI345E)
    (`P2`): objectives, verticality, revives and crowded fights.
  - [Ranked no-commentary match](https://www.youtube.com/watch?v=1MMXAN-NIWs)
    (`S1`): normal player camera and HUD.
- Pokemon UNITE:
  - [2025 World Championship Finals](https://www.youtube.com/watch?v=X547mcDEvDc)
    (`S2`): objective lifecycle and team staging only.
  - [Normal Cinderace match](https://www.youtube.com/watch?v=IAAmPqSdP2I)
    (`S1`): player-scale creature and HUD observations.
- Useful contrast:
  - [The Machines Arena 4K raw gameplay](https://www.youtube.com/watch?v=dz46CRMcV3Y)
    (`S1`): direct aim, projectiles and compact match camera.
  - [Heroes of the Storm World Finals](https://www.youtube.com/watch?v=aJFi3ANmR_w)
    (`S2`): objective broadcasts and map consequences, not player-HUD timing.

SUPERVIVE's live service ended in February 2026. Its archived footage remains
valuable, but new local captures are no longer an available research path.

### Creatures and Motion

- [Rain World developer gameplay](https://www.youtube.com/watch?v=tVWPtsSPhzk)
  (`P2`): long-body and terrain-contact motion. This is an older beta capture;
  a final-build raw source is still required.
- [Pikmin 4 raw editorial gameplay](https://www.youtube.com/watch?v=gWBWglh3BFU)
  (`S1`): swarm cohesion, target convergence and water entry.
- [Flock official walkthrough](https://www.youtube.com/watch?v=35kmUJ9BmP8)
  (`P2`): useful flight vocabulary, but too short for sustained measurement.
- [Pokemon UNITE official gameplay reveal](https://www.youtube.com/watch?v=oElrP4oAwjA)
  (`T`): intended creature presentation only; do not measure timing from it.

Game footage will not provide sufficient biological accuracy by itself. The
later mine should pair it with:

- [Cornell Macaulay Library video](https://www.macaulaylibrary.org/type/video/)
  for bird and wildlife behavior;
- [Animal Diversity Web](https://animaldiversity.org/about/) for anatomy and
  behavior context;
- [Smithsonian Open Access](https://www.si.edu/OpenAccess) for anatomical and
  natural-history imagery with item-level rights review.

### Wetland, Water and World State

- [Don't Starve Together marsh guide](https://www.youtube.com/watch?v=DQKCJpaCgZg)
  (`C`/gameplay): reeds, threat spacing and marsh vocabulary.
- [Don't Starve Together swamp traversal](https://www.youtube.com/watch?v=5FCYDaONyqs)
  (`S1`): continuous traversal and prop density.
- [V Rising Cursed Forest gameplay](https://www.youtube.com/watch?v=YkyZv8BwQkM)
  (`S1`): phase lighting, fog, vegetation and combat hierarchy.
- [Darkwood no-commentary longplay](https://www.youtube.com/watch?v=f8Sfh7_U6UM)
  (`S1`): uncertainty, darkness and concealed water threats.
- [Cult of the Lamb Anura walkthrough](https://www.youtube.com/watch?v=QvxOtfJspTk)
  (`S1`): organic room construction, shoreline framing and 2D-in-3D depth.
- [Terra Nil full walkthrough](https://www.youtube.com/watch?v=TedKHTfSmiI)
  (`S1`): habitat formation and ecological transitions.
- [Death's Door Flooded Fortress sequence](https://www.youtube.com/watch?v=De5EIVFl_KM)
  (`S1`): water composition and restrained combat staging.

### Information and Squad State

- [Dota 2 normal-player match](https://www.youtube.com/watch?v=wCINzcDgeOY)
  (`S1`): HUD structure and fog states. A recent high-level POV is still needed
  before drawing competitive teamfight conclusions.
- [Apex Legends ranked POV](https://www.youtube.com/watch?v=6300yq0gKNs)
  (`S1`): pings, squad portraits and downed-state communication.
- [Dragon Age tactics demonstration](https://www.youtube.com/watch?v=rE8BWSnSiYY)
  (`C`/gameplay): switching and party-AI behavior. A longer uninterrupted
  switching session is still needed.

## Deprioritized and Backup Candidates

| Candidate | Why It Is Not Core |
| --- | --- |
| Heroes of the Storm | Strong objective staging, but Battlerite and SUPERVIVE cover more immediate Battle Bog needs |
| The Machines Arena | Excellent direct-aim contrast; organic creature and wetland transfer is weak |
| Cult of the Lamb | Valuable construction and pipeline reference; most playable motion is humanoid and its style is highly distinctive |
| Nobody Saves the World | Economical form differentiation, but supplied footage is trailer-only and motion authenticity is limited |
| Rotwood | Strong animation candidate, but its exact technical pipeline was not verified |
| Terra Nil | Excellent ecology formation, no live competitive combat |
| Death's Door and TUNIC | Excellent composition, but diorama depth and occlusion are risky for Battle Bog |
| Hades | Production-quality ceiling, not an assumed roster budget |
| Dead Cells | Excellent pipeline precedent, side-view runtime does not prove directional scalability |
| League of Legends | Useful silhouette and hierarchy source, but Dota and SUPERVIVE cover the selected questions more directly |
| Snake Pass and Lost Ember | Useful animal-motion specialists; camera transfer is weak |
| Super Animal Royale | Excellent tiny top-down readability; shared bipedal gun handling suppresses species-specific gait |
| The Wild at Heart and Oddsparks | Useful swarm backups; Pikmin provides stronger footage |
| Invisible, Inc. | Strong uncertainty design, but turn-based pacing limits direct presentation transfer |

## Pipeline Hypotheses

No production winner is selected yet.

| Pipeline | Main Strength | Decisive Risk | Current Role |
| --- | --- | --- | --- |
| Hand-drawn directional sheets | Maximum authored personality and pixel control | Manual multiplication across directions, states and revisions | Small quality-control benchmark |
| Pre-rendered 3D-to-2D sheets | Reusable rigs, inexpensive retiming and low integration risk with the current Canvas world | Direction and atlas multiplication remain | Integration favorite |
| Native 2D cutout rigs | Texture reuse and Godot-native deformation | Paper-doll appearance, foreshortening and directional anatomy | Family-specific contender |
| Restrained live 3D | Continuous facing, reusable animation, altitude and long bodies | Sorting, fog, water, style matching and larger integration change | Roster-scaling favorite |

### Direction and Atlas Risk

A deliberately conservative estimate of seven basic clips and about 47 frames
per direction produces roughly:

```text
8 directions  -> about 376 frames per creature
16 directions -> about 752 frames per creature
```

Across 21 creatures, water, flight, takeoff, landing, terrain transitions,
attacks and interruption states could plausibly raise this to:

- 10,000-14,000 frames at eight directions;
- 20,000-28,000 frames at sixteen directions.

Pre-rendering automates frame creation and revision. It does not remove storage,
import, atlas or state-coverage costs. This is why live 3D remains a serious
comparison candidate.

## Pipeline Prototype Gate

### Gate 1: Alligator, Four-Way Comparison

Build the same compact animation contract as:

- pre-rendered 3D at an initial eight directions;
- native 2D cutout;
- restrained live 3D;
- a hand-drawn key-pose benchmark.

Required states:

`idle -> start -> crawl -> tight turn -> reverse -> swim -> shoreline
transition -> primary startup -> active -> recovery -> hit -> death`

This exposes long-body turning, capsule alignment, water contact, lighting and
direction snapping.

### Gate 2: Kingfisher, Best Two Pipelines

Test:

`takeoff -> sustained flight -> bank -> plunge warning -> projected landing
point -> impact -> low punish window -> recovery`

A candidate fails if altitude is understandable only from the HUD, if direction
snaps during a dive, or if the incoming attack is readable only after the
reaction window has effectively closed.

### Gate 3: Mosquito Swarm

Test distributed bodies, individual variation, altitude, cohesion, target
convergence, hit response and effect density.

The correct result may be a primary creature pipeline plus a specialized
procedural or particle swarm renderer. Pipeline consistency does not require
every animal to use identical internals.

### Gate 4: Real 3v3 Vertical Slice

Before all 21 creatures enter production, the leading solution must survive
one frog, one bird and one long-bodied ground creature in an objective fight
with:

- normal 1280 x 720 player camera;
- actual team rings and telegraphs;
- mud, water, reeds and night states;
- grayscale and common color-vision checks;
- collision and capsule overlays;
- screenshot and short-video regression captures;
- atlas, build-size, import-time, draw-call, CPU, GPU, median, p95 and p99
  frame-time measurements;
- human recognition, air-attack reaction and punish-window comprehension tests.

The minimum target machine must be defined before final performance budgets
are locked.

## Originality Protocol

1. Record the game, version, platform, capture date, URL, channel, source class,
   camera type, clip bounds and rights note.
2. Record visible behavior separately from interpretation.
3. Translate observations into neutral variables: anticipation time,
   silhouette occupancy, turn radius, shadow separation, effect lifetime,
   vegetation response or information-state transition.
4. Combine at least three unrelated game sources with real-animal evidence and
   Battle Bog's existing constraints.
5. Author concepts from the resulting Battle Bog brief, not by tracing or
   reproducing source frames.
6. Reject direct palette sampling, recognizable silhouettes, signature motifs,
   copied VFX shapes, traced poses and replicated animation sequences.
7. Run a similarity review across silhouette, proportions, palette, effects
   and key poses before accepting production art.
8. Keep research captures outside shipped assets and record item-level
   licensing or rights status.
9. Require a second reviewer before a mined finding becomes a production rule.

## Proposed Deep-Mine Outputs

For each approved core game:

1. Source ledger with confidence labels.
2. Normal-camera clip index.
3. Frame and timing measurements.
4. Silhouette and screen-occupancy observations.
5. Movement, combat, world and UI pattern cards.
6. Explicit anti-patterns and non-transferable features.
7. Battle Bog translation hypotheses.
8. Cross-source synthesis after all games are analyzed.

Specialist references receive smaller question-specific ledgers.

The synthesis should produce:

- a Battle Bog creature silhouette constitution;
- movement-family and species-exception briefs;
- combat anticipation, hit and recovery rules;
- flight/depth and landing-point rules;
- material-specific impact vocabulary;
- wetland terrain, water, vegetation and habitat rules;
- HUD, minimap, objective and uncertainty rules;
- candidate art-pipeline requirements;
- representative prototype briefs and acceptance tests.

## Discussion Decisions

The visual-reference quiz resolved the portfolio decisions below. The resulting
direction is recorded in `docs/BATTLE_BOG_VISUAL_DIRECTION_BRIEF.md`, and the
extraction plan is recorded in
`docs/RESEARCH_VISUAL_DEEP_MINE_SOURCE_LEDGER.md`.

1. Battlerite, SUPERVIVE, Pokemon UNITE, Temtem: Swarm and Evercore Heroes are
   full visual anchors.
2. Don't Starve Together, Rain World and V Rising are not full style anchors.
   Their approved uses are narrow workflow, biomechanics and boundary studies.
3. The Alligator gate keeps all four pipeline forms until direct gameplay-scale
   comparison.
4. Specialist games remain bounded to the questions assigned in the visual
   direction brief.
5. Minimum target hardware remains unresolved and must be selected before final
   production performance budgets.

Deep footage extraction may now proceed. Production asset generation and
pipeline migration remain prototype-gated.
