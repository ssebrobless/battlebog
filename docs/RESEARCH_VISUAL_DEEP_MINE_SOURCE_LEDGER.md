# Battle Bog Visual Deep-Mine Source Ledger

Status: approved portfolio, source collection and measurement pending

Started: 2026-07-27

Depends on:

- `docs/BATTLE_BOG_VISUAL_DIRECTION_BRIEF.md`
- `docs/RESEARCH_VISUAL_REFERENCE_MINING_CANDIDATES.md`
- `docs/RESEARCH_WILDLIFE_MOVEMENT_EVIDENCE.md`
- `docs/BATTLE_BOG_COMBAT_READABILITY_CONSTITUTION.md`
- `docs/BATTLE_BOG_CREATURE_SILHOUETTE_AND_SCALE_CONSTITUTION.md`
- `docs/BATTLE_BOG_WORLD_ART_CONSTITUTION.md`
- `docs/BATTLE_BOG_ALLIGATOR_PIPELINE_GATE.md`
- `docs/BATTLE_BOG_VISUAL_IMPLEMENTATION_ROADMAP.md`
- `docs/BATTLE_BOG_VISUAL_VALIDATION_SPEC.md`
- `docs/BATTLE_BOG_VFX_AND_MATERIAL_GRAMMAR.md`
- `docs/BATTLE_BOG_HUD_INFORMATION_AND_SWITCHING_CONSTITUTION.md`
- `docs/BATTLE_BOG_ORDINARY_ATTACK_TIMELINE_SPEC.md`
- the completed Battle Bog Visual Reference Quiz export

This ledger turns the user's visual preferences into bounded research jobs.
It is not a list of games whose style should be copied. Each source has one
specific responsibility, an explicit rejection boundary and a Battle Bog
output it must help produce.

## Research Shape

```text
USER-CALIBRATED DIRECTION
          |
          v
SOURCE QUALIFICATION
  P1 developer evidence
  P2 official gameplay
  S1 normal player POV
  S2 spectator footage
  T  edited presentation
          |
          v
BOUNDED CLIP EXTRACTION
  combat | creature | world | information | pipeline
          |
          v
NEUTRAL OBSERVATIONS
  timing | occupancy | direction | contrast | motion | state
          |
          v
CROSS-SOURCE RULE
  3+ unrelated games + real animal + Battle Bog truth
          |
          v
ALLIGATOR -> KINGFISHER -> MOSQUITO -> REAL 3v3
```

## Evidence Discipline

Every future observation must include:

- source URL, game version when known and capture date;
- source class: `P1`, `P2`, `S1`, `S2`, `T` or `C`;
- camera type: normal player, spectator, cinematic or close-up;
- clip bounds or timestamp;
- evidence type: `Documented`, `Observed` or `Inferred`;
- confidence: high, medium or provisional;
- one transfer rule and one non-transfer rule.

Source classes:

- `P1`: primary developer, engine-owner or conference technical source;
- `P2`: official uninterrupted gameplay at representative camera;
- `S1`: normal raw player gameplay;
- `S2`: spectator or tournament footage with altered information;
- `T`: curated or edited official showcase/trailer;
- `C`: community guide, wiki or analysis requiring corroboration.

Classify each extracted sequence separately. Do not use combined classes such as
`T/P2`; an edited segment remains `T` even when published officially.

Trailers and hero showcases can establish intended shape, color and effect
language. They cannot establish reaction time, screen occupancy, camera load or
normal HUD density. Candidate timestamps below remain unverified until reviewed
frame by frame.

## Lane A: Combat Grammar

### A1. Battlerite - Primary Clarity Floor

Research job:

- direct-control aim and facing;
- camera steadiness during six-player pressure;
- startup, active, contact, whiff and recovery separation;
- ground telegraph duration and ownership;
- material-specific hit confirmation;
- contextual rather than permanently noisy combat UI.

Sources:

| Source | Class | Extraction Job |
| --- | --- | --- |
| [Stunlock networking movement dev blog](https://blog.stunlock.com/dev-blog-008/) | `P1` | Document the design requirement that direct movement feel immediate while authoritative combat truth remains separate |
| [Raw 3v3 full match](https://www.youtube.com/watch?v=7pQxQiIIAdk) | `S1` | Select 10 hit and 5 whiff sequences at normal camera; measure pose commitment, telegraph lead, impact persistence and recovery |
| [3v3 Grand Finals player footage](https://www.youtube.com/watch?v=mDCP_SOcX_U) | `S1` | Inspect camera displacement, target reacquisition, simultaneous effects and low-health information under sustained pressure |

Transfer:

- immediate locomotion response;
- attack commitment visible in both pose and world effect;
- clean distinction among anticipation, contact and recovery;
- restrained screen movement and contextual information.

Reject:

- arena sparseness as a world-art target;
- champion-specific silhouettes or VFX motifs;
- online prediction architecture as a requirement for the PvAI milestone.

Output:

`BATTLE_BOG_COMBAT_READABILITY_CONSTITUTION.md`, including measurable startup,
active and recovery ranges for prototype attacks.

### A2. SUPERVIVE - Energy And Layering Ceiling

Research job:

- altitude and overlap;
- entering, leaving and reacquiring crowded fights;
- terrain hierarchy around objectives;
- off-screen and uncertain information;
- effect escalation without loss of team, target or danger truth.

Sources:

| Source | Class | Extraction Job |
| --- | --- | --- |
| [Official full-match gameplay](https://www.youtube.com/watch?v=Fs9pGnI345E) | `P2` | Verify candidate anchors around 0:00, 3:05, 7:11, 9:24, 11:37, 14:11 and 17:26; retain only sequences showing ordinary player camera and unbroken state transitions |
| [Ranked no-commentary match](https://www.youtube.com/watch?v=1MMXAN-NIWs) | `S1` | Compare ordinary traversal, approach, vertical separation, re-entry and normal HUD load against the official match |

Transfer:

- layered body, shadow, projection and information cues;
- objective events that change what players know and where they look;
- energetic ordinary abilities, not only boss spectacle;
- terrain contrast that survives crowded combat.

Reject:

- revive and inventory information Battle Bog does not use;
- spectacle that obscures startup or punish timing;
- wholesale visual identity, palette or effect silhouettes.

Output:

an altitude/depth cue stack and an effect-priority table for ordinary attacks,
air attacks, submerged attacks and objectives.

### A3. Specialist Combat Sources

| Reference | Source | Class | Narrow Job | Boundary |
| --- | --- | --- | --- | --- |
| The Machines Arena | [Raw 4K gameplay](https://www.youtube.com/watch?v=dz46CRMcV3Y) | `S1` | Cursor-facing poses, projectile origin/path, impact and stable camera | Robotic materials and weapon identity are not transferable |
| Hades II | [Official gameplay reveal](https://www.youtube.com/watch?v=-SnaCUsUF3E) | `T`/`P2` | Painted dimensional quality and material-impact ceiling | Do not measure ordinary combat timing from edited sequences |
| Pokemon UNITE | [Normal Cinderace match](https://www.youtube.com/watch?v=IAAmPqSdP2I) | `S1` | Creature attacks, dives and teamfight occupancy | Mobile controls and plastic terrain are rejected |

## Lane B: Creature Construction

### B1. Pokemon UNITE - Primary Creature Readability

Research job:

- recognizable creature anatomy at normal play scale;
- heroic exaggeration that preserves species identity;
- believable but compressed size tiers;
- readable facing, locomotion, dive and signature attack;
- roster consistency without a universal body envelope.

Primary sources:

- [Official roster](https://unite.pokemon.com/en-us/pokemon/) (`P2` intended
  roster presentation).
- [Official game overview](https://unite.pokemon.com/en-us/overview/) (`P2`
  match and objective context).
- [Charizard move page](https://unite.pokemon.com/en-us/pokemon/charizard/)
  (`P2`, airborne grab and slam).
- [Greninja move page](https://unite.pokemon.com/en-us/pokemon/greninja/)
  (`P2`, frog-like posture and overhead water attack).
- [Mew move page](https://unite.pokemon.com/en-us/pokemon/mew) (`P2`, elevation
  and stealth state).

Player footage:

- [Normal Cinderace match](https://www.youtube.com/watch?v=IAAmPqSdP2I)
  (`S1`).
- [World Championship Finals](https://www.youtube.com/watch?v=X547mcDEvDc)
  (`S2`; staging and crowd comparison only).

Extraction set:

1. Select one long-bodied, one winged, one heavy, one small and one
   quadrupedal creature.
2. Capture normal-camera rest, travel, turn, attack, hit and defeat states.
3. Measure screen height/width against truth footprint and nearby terrain.
4. Record which anatomical features communicate direction before effects.
5. Record how much anticipation is pose-based versus effect-based.

Transfer:

- bold anatomy, clean silhouettes and readable attack direction;
- roster-wide scale compression that retains meaningful tiers;
- signature motion attached to recognizable anatomy.

Reject:

- inflated mobile HUD;
- glossy toy surfaces;
- simple plastic terrain;
- frantic timing as Battle Bog's default pacing.

### B2. Temtem: Swarm - Softer Midpoint

Sources:

- [Official Steam page and gameplay media](https://store.steampowered.com/app/2510960/Temtem_Swarm/)
  (`P2`/`T` depending on clip).

Research job:

- economical surfaces and soft dimensional shading;
- compact, readable locomotion cycles;
- how color blocking survives many creatures and effects.

Transfer:

- surface economy and the softer half of the target midpoint.

Reject:

- forcing long necks, tails, wings, shells or swarms into rounded contained
  forms;
- treating all species as equally cute or equally compact.

### B3. Real-Animal Counter-Evidence

Game references answer readability. They do not establish authentic motion.
The current creature-by-creature evidence and unresolved footage gaps are
preserved in `docs/RESEARCH_WILDLIFE_MOVEMENT_EVIDENCE.md`.

| Source | Use |
| --- | --- |
| [Cornell Macaulay Library video](https://www.macaulaylibrary.org/type/video/) | Bird takeoff, banking, plunge, wing braking, perching and prey strikes |
| [Animal Diversity Web](https://animaldiversity.org/) | Anatomy, habitat and behavior context |
| [Smithsonian Open Access](https://www.si.edu/OpenAccess) | Natural-history and anatomical imagery with item-level rights review |

For each Battle Bog species, collect:

- body support and center of mass;
- acceleration and braking mechanism;
- turning mechanism;
- terrain contact sequence;
- attack preparation and follow-through;
- species-specific exception to its movement-family default.

No game observation becomes a creature rule until checked against real-animal
evidence.

## Lane C: Wetland World

### C1. Evercore Heroes - Bright Competitive Finish

Sources:

- [Official video library](https://evercoreheroes.com/videos) (`P2`/`T`).
- [Official world overview](https://evercoreheroes.com/world/) (`P2` intended
  world identity).

Research job:

- bright dimensional terrain around readable units;
- navigable, interactable and decorative layer separation;
- normal combat against richer materials than a simple arena;
- darker scenes that remain readable enough to inform Battle Bog night.

### C2. Albion Online - Primary Swamp Systems Specialist

Sources:

- [2026 visual overhaul overview](https://albiononline.com/news/visual-overhaul-shorts)
  (`P1`/`P2`).
- [Biome rework developer talk](https://albiononline.com/news/devtalk-biome-rework)
  (`P1`).
- [Creating a New World behind the scenes](https://albiononline.com/news/video-creating-new-world)
  (`P1`).

Documented observations:

- the overhaul explicitly strengthens biome identity through lighting,
  atmosphere, ground texture and small ambient details;
- the swamp example uses muddy still water, active plants and small wildlife;
- the biome rework distinguishes mild wetlands and flooded meadows from more
  intense regional variants;
- the world-production discussion connects flora, fauna and resources to biome
  identity rather than treating them as detached decoration.

Battle Bog hypothesis:

Use a restrained version of this layering so mud, shallow water, reeds, insects
and reactive foliage create continuous ecology while collision truth,
telegraphs and teams remain dominant.

### C3. Environment Specialists

| Reference | Source | Job | Reject |
| --- | --- | --- | --- |
| Ravenswatch | [Official site](https://ravenswatch.com/en/) and representative raw gameplay to be qualified | Night mood, painterly ecology and visibility boundary | Dark-fantasy identity and physically unreadable darkness |
| Wild Woods | [Official Steam page](https://store.steampowered.com/app/1975580/Wild_Woods/) | Friendly prop shape, habitat composition and environmental warmth | Humanoid animal construction |
| SUPERVIVE | [Official full match](https://www.youtube.com/watch?v=Fs9pGnI345E) | Competitive terrain hierarchy and overlap | Wholesale biome or palette identity |
| Heroes of the Storm | [World Finals footage](https://www.youtube.com/watch?v=aJFi3ANmR_w) | Objective and world-state transformation | Spectator HUD and source-specific map events |

World extraction must classify every element as:

- playable ground;
- terrain-affecting ground;
- collision blocker;
- vision/cover element;
- harvestable or objective;
- animated ambient layer;
- suppressible combat decoration.

Output:

a wetland material hierarchy, water/shoreline grammar, vegetation density
budget, combat suppression policy and day/dusk/night comparison.

## Lane D: Flight, Long Bodies And Swarms

| Problem | Primary Game Source | Biological Source | Required Measurement |
| --- | --- | --- | --- |
| Bird flight | [Flock official walkthrough](https://www.youtube.com/watch?v=35kmUJ9BmP8) | Cornell flight footage | Banking onset, turn arc, altitude cue stack, formation lag |
| Long body | [Rain World developer gameplay](https://www.youtube.com/watch?v=tVWPtsSPhzk) | species anatomy and locomotion video | head intent, body follow delay, terrain contacts, bend limit |
| Swarm | [Pikmin 4 gameplay](https://www.youtube.com/watch?v=gWBWglh3BFU) | mosquito emergence/flight footage | group envelope, individual variance, convergence and hit response |

Boundaries:

- Flock supplies motion vocabulary, not Battle Bog camera or art style.
- Rain World supplies biomechanical principles, not side-view composition or
  shipped visual identity.
- Pikmin supplies group legibility, not creature proportions or behavior.

The Kingfisher test fails if a player needs HUD text to understand altitude or
if the incoming strike becomes readable only after the reaction window closes.
The Mosquito test may legitimately use a specialist renderer rather than the
roster's primary creature pipeline.

## Lane E: Information And HUD

| Reference | Source | Narrow Job | Boundary |
| --- | --- | --- | --- |
| Dota 2 | [Normal-player match](https://www.youtube.com/watch?v=wCINzcDgeOY) | Configurable information depth, fog, minimap and last-known state | Do not inherit permanent density |
| Apex Legends | [Ranked POV](https://www.youtube.com/watch?v=6300yq0gKNs) | Directional alerts, redundant warnings and accessibility | First-person layout does not transfer directly |
| Dragon Age: Origins | [Tactics demonstration](https://www.youtube.com/watch?v=rE8BWSnSiYY) | Active switching and released-unit intent | Guide footage needs a longer normal-play corroboration |
| Battlerite | raw matches above | Quiet contextual combat HUD | Arena-only information is insufficient for Battle Bog macro state |
| SUPERVIVE | matches above | Objectives, off-screen events and layered information | Remove inventory and revive ownership |

Required Battle Bog output:

```text
SIMPLE HUD
  always: own health, hunger, abilities, controlled creature
  contextual: aim, hit, warning, interaction, off-screen event

EXPANDED HUD
  simple
  + squad stocks and intent
  + visibility and last-known state
  + breeding/boss-meter economy
  + objective timing and claim state
```

The HUD must answer:

1. What is happening?
2. Why does it matter?
3. Where should attention move?
4. What can still be done before the state resolves?

## Lane F: Production Pipeline

### Qualified Primary Sources

| Source | Class | Documented Value |
| --- | --- | --- |
| [Dead Cells 3D-to-2D deep dive](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-) | `P1` | Reusable 3D character work rendered into a 2D runtime result |
| [2D Animation at Klei](https://gdcvault.com/play/1020165/2D-Animation-at-Klei) | `P1` | Symbol-based animation, reuse, costume/color variation and a flexible authored 2D build process |
| [Hades character production](https://www.gamedeveloper.com/art/learn-how-supergiant-brought-i-hades-i-hand-painted-characters-to-life) | `P1` | 3D bases transformed into highly authored painted character results |
| [Godot AnimatedSprite2D](https://docs.godotengine.org/en/4.6/classes/class_animatedsprite2d.html) | `P1` | Native frame-animation runtime |
| [Godot 2D skeletons](https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html) | `P1` | Provisional-confidence bone-deformed 2D option; verify because the upstream page warns it may be outdated |
| [Godot 3D scene import](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_3d_scenes/index.html) | `P1` | Blender/glTF route for restrained live-3D tests |

### Fair Prototype Matrix

All four Alligator candidates use identical:

- gameplay radius and long-body capsule;
- world scale and 1280 x 720 camera;
- northwest light and southeast shadow;
- locomotion and attack timings;
- state names, pivot, sockets and truth overlays;
- mud, water, shoreline and night test scenes.

| Candidate | Required Proof | Decisive Risk |
| --- | --- | --- |
| Pre-rendered 3D-to-2D atlas | Eight directions, no distracting direction snap, measured atlas/build/import cost | State and direction multiplication |
| Restrained live 3D | Continuous direction, convincing water/height integration, visual fit with 2D overlays | Sorting, material/world mismatch and integration scope |
| Limited 2D rig | Directional anatomy and deformation without visible paper-doll construction | Foreshortening and cutout appearance |
| Hand-authored key poses | Best readable rest, turn, startup, hit and recovery at gameplay scale | Production multiplication if treated as roster default |

### Acceptance Measurements

- recognition at rest, travel, tight turn and crowded combat;
- first frame at which attack direction and commitment are understood;
- hit/whiff/recovery agreement with simulation truth;
- percentage of torso inside the authoritative footprint;
- extremity honesty relative to hurtbox and capsule;
- eight-way direction snap severity;
- altitude and submergence comprehension without HUD;
- atlas size, build size, import time, memory, draw calls and frame-time cost;
- authoring and revision time for one changed attack;
- grayscale and common color-vision readability;
- user playtest comprehension at normal camera.

No pipeline wins by convenience or close-up beauty. It wins only after the
Alligator, Kingfisher, Mosquito and 3v3 gates.

## Mine Order

```text
WAVE 1: TRUTH AND TIMING
Battlerite + SUPERVIVE + Pokemon UNITE
        |
        v
WAVE 2: FORM AND ECOLOGY
Temtem + Evercore + Albion + real animals
        |
        v
WAVE 3: SPECIAL PROBLEMS
Machines Arena + Hades II + Ravenswatch
Flock + Rain World + Pikmin
Dota + Apex + Dragon Age
        |
        v
WAVE 4: PIPELINE PROTOTYPES
Alligator (4) -> Kingfisher (2) -> Mosquito -> 3v3
```

Wave 1 should finish before final animation briefs because Battle Bog still
needs simulation-owned ordinary attack phases. Wave 2 can inform concept art
and test-scene construction in parallel. Wave 3 produces narrow rule cards,
not full style studies.

## Concrete Deliverables

1. `BATTLE_BOG_COMBAT_READABILITY_CONSTITUTION.md` - first research synthesis
   complete; code translation and playtest validation pending.
2. `BATTLE_BOG_CREATURE_SILHOUETTE_AND_SCALE_CONSTITUTION.md` - first research
   synthesis complete; prototype validation pending.
3. movement-family briefs plus one real-animal exception per species
4. flight, submergence and landing-point cue stack
5. `BATTLE_BOG_WORLD_ART_CONSTITUTION.md` - first research synthesis complete;
   representative world slice pending.
6. simple/contextual/expanded HUD ownership map
7. `BATTLE_BOG_ALLIGATOR_PIPELINE_GATE.md` - concrete four-way gate complete;
   Kingfisher and Mosquito briefs pending.
8. normal-camera screenshot and video regression specification
9. cross-source originality and similarity review

## Decisions Still Requiring Evidence

The quiz resolved the style portfolio. It intentionally did not resolve:

- the final creature rendering pipeline;
- exact startup and recovery timing ranges;
- the amount of live-3D material response compatible with the desired look;
- how much environmental motion can remain active in six-creature combat;
- the minimum target hardware and final performance budgets.

Those are prototype and measurement decisions, not additional taste questions.
