# Battle Bog Wildlife Movement Evidence

Status: research synthesis, implementation translation pending

Compiled: 2026-07-27

Cross-checked primary text on 2026-07-27 for the newt transition sequence and
the crayfish tail-flip preparation/active timing.

Related:

- `docs/RESEARCH_MOVEMENT_FEEL.md`
- `docs/BATTLE_BOG_VISUAL_DIRECTION_BRIEF.md`
- `docs/RESEARCH_VISUAL_DEEP_MINE_SOURCE_LEDGER.md`

This document cross-examines Battle Bog's movement-family plan against
wildlife footage and locomotion research. It records motion principles, not
animation frames to copy.

## Governing Rule

```text
WILDLIFE TRUTH
      |
      v
species locomotion + medium transition
      |
      v
top-down compression + heroic exaggeration
      |
      +--> aim carried by head, neck or appendage
      +--> height carried by shadow, scale and occlusion
      +--> attacks warned by authentic preparation
      |
      v
TEL_warning -> HIT_active -> FX_afterstate -> RECOVERY_weakpoint
```

Locomotion remains biologically authored. Combat systems request intentions
but should not directly rotate or slide the visible creature in ways its body
cannot explain.

## Orientation Contract

Each authored creature needs three related but separate headings:

1. `travel_heading`: root, hips and trunk follow actual velocity using the
   species' turn limits.
2. `attention_heading`: eyes, head, bill, neck, claws or forelimbs aim within
   anatomical limits.
3. `strike_heading`: the body may align to an attack during visible startup,
   followed by overshoot, follow-through or recovery.

When attention exceeds the available anatomical range, locomotion initiates a
curved turn. Flyers bank toward velocity while head and telegraph communicate
aim. Long bodies use follow-the-leader spine points. Swarms aim by reshaping
their group envelope.

## Creature Signatures

| Creature | Authentic Movement Signature | Battle Bog Read |
| --- | --- | --- |
| Bullfrog | Low crouch, substantial loading, explosive hindleg extension, forelimb brace and body settle | Heavy `coil -> launch -> thump`; stillness is part of the threat |
| Chorus Frog | Lighter, shallower sequential hops and occasional surface skitter | Rhythmic skitter-hop; never merely a faster Bullfrog |
| Cane Toad | Short grounded hops, limited airtime and deliberate landing control | Squat, plodding and toxic despite competitive movement speed |
| Newt | High-duty-factor lateral walk; underwater walking during shoreline transition; axial undulation only after full immersion | Deliberate land crawl, hybrid shoreline state, then tail-driven swim |
| Snapping Turtle | Heavy bottom walk, gradual body turns, shell anchored during neck strike and visible neck retraction | Slow armored base plus sudden neck threat and conspicuous recovery |
| Bog Turtle | Compact cautious walk and paddle | Higher stride frequency and less mass than Snapping Turtle; provisional pending stronger footage |
| Alligator | Low walk for ordinary travel, semi-erect high walk for purpose, tail-led traveling wave in water | Low ambush posture, committed body lift and non-rigid long-body turns |
| Water Snake | Head-led path with growing posterior amplitude | Spine follows the traveled path; it never points instantly at the cursor |
| Mink | Elastic land bounds; comparatively stable trunk and strong alternating paddle in water | Needle-like bounds on land, controlled but effortful water chase |
| Otter | Land lope or bound with slides; limb paddling and dorsoventral body-tail undulation in water | Playful elastic pack motion with water rolls and slides |
| Beaver | Lumbering land gait; steady surface silhouette with propulsion mostly hidden below | Heavy trundle on land, competent quiet water travel |
| Water Shrew | Extremely fast staccato scurry, surface sprint and sudden dive | Tiny high-frequency skimmer; warning comes from sensory lock before the real fast strike |
| Great Blue Heron | Slow body-stable stalking; S-neck compresses while torso remains planted; head and bill release abruptly | Patient planted spear-wader with neck-owned aim |
| Owl | Broad restrained wingbeats and long glides | Quiet aerial assassin; trajectory, talons and shadow carry dive intent |
| Duck | Waddle, buoyant drift and concealed foot paddling | Comfortable generalist with a distinct run-and-lift takeoff |
| Kingfisher | Perch or hover, head lock, body alignment, committed plunge, splash and emergence | Twitchy precision diver with a readable full dive chain |
| Crayfish | Side-biased scuttle, independent claw display and prepared tail escape | Confident lateral motion followed by earned explosive reverse |
| Leech | Rear anchor, lengthen, front anchor, contract; swimming uses a rearward whole-body wave | Separate inchworm crawl and smooth undulatory swim states |
| Wolf Spider | Low alternating gait, burst-and-freeze pursuit, pounce and burrow-edge ambush | Low sudden hunter whose leg rhythm changes before commitment |
| Mosquito Swarm | Stable group centroid while individuals loop through a volume | Cohesive cloud; attack intent appears as density shifting toward one edge |
| Firefly Swarm | Individually traceable wandering inside a persistent envelope | Synchronized flashes, not synchronized flight paths |

## Authentic Telegraph Poses

| Creature | Warning Pose | Active | Recovery |
| --- | --- | --- | --- |
| Frog | Compress legs and shift mass rearward | Hindleg release and airborne arc | Forelimb brace and body settle |
| Heron | Plant feet and coil neck | Bill and head release | Neck recoil and balance reset |
| Turtle | Retract head and brace shell | Neck extension or body shove | Conspicuous retraction |
| Kingfisher | Head lock, body alignment and projected corridor | Accelerating plunge | Splash, emergence and low vulnerable reset |
| Owl | Approach-arc change, wing flare, talons lower and shadow strengthens | Dive contact | Braking wingbeat and landing/reclimb |
| Crayfish | Legs raise, abdomen straightens and tail cups | Tail flip | Slide stop and posture recovery |
| Water Shrew | Whisker scan, crouch or ripple lock | Biologically fast strike | Tiny stop or direction reset |

Literal realism is not always fair. When the real strike is too fast for a
player reaction, Battle Bog moves the readable commitment earlier into an
authentic sensory or loading pose.

## Medium Transitions

```text
LAND
  -> commitment
  -> shoreline contact
  -> hybrid locomotion
  -> WATER

WATER
  -> approach
  -> substrate contact
  -> weighted exit
  -> LAND

GROUND
  -> load
  -> lift
  -> shadow separation
  -> AIR

AIR
  -> target lock
  -> bank/alignment
  -> accelerating descent
  -> impact
```

Transitions do not begin merely because the collision center crossed a terrain
boundary. Each animal needs a brief hybrid state in which weight transfer,
drag, wake, splash, substrate contact and pose explain the medium change.

Flight must preserve three simultaneous readings:

- planar: trajectory and turn radius;
- body: wing cycle, banking and attack pose;
- height: shadow offset/scale, altitude marker and ground occlusion.

## Source Ledger

`REF` means copyrighted observation/research reference only. `OPEN` means the
source states reusable terms; item-level verification and attribution still
apply.

| Creature Or Action | Evidence | Source | Rights Note |
| --- | --- | --- | --- |
| Bullfrog swimming | Research, proxy frog | [JEB swimming kinematics](https://journals.biologists.com/jeb/article/213/4/621/10128/Kinematics-and-hydrodynamics-analysis-of-swimming) | `REF` |
| Chorus frog surface motion | High-speed proxy species | [Cricket frog surface-skitter video](https://movie.biologists.com/video/10.1242/jeb.249403/video-1) | `REF` |
| Chorus frog morphology | Exact species family | [USFWS chorus frog](https://www.fws.gov/media/chorus-frog) | Public domain |
| Cane toad hopping | Exact-species research | [ANU high-speed study](https://openresearch-repository.anu.edu.au/items/49814039-79f0-4e31-a872-d80ea501add6) | `REF` |
| Newt land/water transition | Exact-family research | [SICB transition study](https://sicb.org/abstracts/kinematics-of-the-transition-between-aquatic-and-terrestrial-locomotion-in-the-newt-taricha-torosa/) | `REF` |
| Alligator walking | Exact-species research | [JEB alligator locomotion](https://journals.biologists.com/jeb/article-abstract/201/18/2559/7758/Locomotion-in-Alligator-mississippiensis-kinematic) | `REF` |
| Water snake swimming | High-speed close proxy | [JEB swimming-snake movie](https://movie.biologists.com/video/10.1242/jeb.245929/video-1) | `REF` |
| Snapping turtle strike | Exact-family research | [Aquatic prey-capture study](https://cpb-us-e1.wpmucdn.com/sites.harvard.edu/dist/6/58/files/2022/03/LauderPendergast1992.pdf) | `REF` |
| Bog turtle morphology | Exact species, non-motion | [USFWS bog-turtle trail](https://www.fws.gov/media/bog-turtle-trail) | Public domain |
| Water shrew pursuit | Exact-species research | [Vanderbilt Catania Lab movies](https://as.vanderbilt.edu/catanialab/research/water-shrews/) | `REF` |
| Mink movement | Exact-species wildlife footage | [USFWS-hosted mink video](https://www.facebook.com/USFWS/videos/american-mink/2334739943579604/) | Verify item rights |
| Otter swimming | Exact-family research | [River-otter locomotion study](https://www.wcupa.edu/sciences-mathematics/biology/fFish/documents/1994JMOtter2.pdf) | `REF` |
| Beaver underwater | Rehabilitation footage | [Sonoma Wildlife Rescue video](https://www.youtube.com/watch?v=04PmnJUfKT4) | `REF` |
| Great blue heron foraging | Exact-species archive footage | [Macaulay Library asset 201486451](https://macaulaylibrary.org/asset/201486451) | Contributor media, `REF` |
| Owl silent flight | Wildlife documentary | [PBS owl flight](https://www.pbs.org/video/nature-owl-shows-silent-flight-superpower/) | `REF` |
| Duck paddling | High-speed research | [JEB duck-paddling movie](https://movie.biologists.com/video/10.1242/jeb.249274/video-1) | `REF` |
| Kingfisher dive | Close-proxy archive footage | [Macaulay Library video 201669261](https://macaulaylibrary.org/video/201669261) | Contributor media, `REF` |
| Crayfish tail flip | Exact-family research | [JEB escape response](https://journals.biologists.com/jeb/article/223/15/jeb219873/224515/Morphology-performance-and-fluid-dynamics-of-the) | `REF` |
| Leech locomotion | Exact-family review | [Leech locomotion review](https://pmc.ncbi.nlm.nih.gov/articles/PMC2323911/) | `REF` |
| Wolf spider burrowing | Exact-family study and video | [Spider burrowing study](https://pmc.ncbi.nlm.nih.gov/articles/PMC3281395/) | `REF` |
| Mosquito swarm structure | Exact-family 3D study | [Mosquito-swarm study](https://pmc.ncbi.nlm.nih.gov/articles/PMC10229557/) | `REF` |
| Firefly display | Exact-species dataset | [Dryad 130-minute recording](https://datadryad.org/dataset/doi%3A10.5061/dryad.3n5tb2rmb) | CC0 under [Dryad terms](https://datadryad.org/terms) |
| Continuous bird banking | Game motion reference | [Flock official page](https://annapurnainteractive.com/games/flock) | `REF` |
| Long procedural bodies | Game motion reference | [Rain World official site](https://rainworldgame.com/) | `REF` |
| Cohesive individual swarm | Game motion reference | [Pikmin 4 official site](https://pikmin4.nintendo.com/) | `REF` |

## Concrete Timing Evidence

The crayfish tail-flip source documents `0.20 +/- 0.08 s` of metachronal
pleopod preparation before a roughly `0.02-0.04 s` flip. Battle Bog should test
the preparation as its legible startup and treat the flip as the active burst,
rather than slowing the entire action into generic anticipation.

Other timing values remain unmeasured until clips are frame-verified. They must
not be inferred from edited trailers.

## Wave 2 Evidence Update

```text
CLOSED                  PARTIAL                 OPEN
firefly trajectories    beaver surface motion   exact chorus frog movement
leech gait contrast     mink shoreline hunting  bog turtle paddle/transition
owl strike mechanics    heron strike sequence   complete kingfisher dive chain
                        bog turtle release       owl landing recovery
                                                 wolf spider burrow ambush
```

### Closed Or Strongly Improved

- Firefly cohesion constrains distribution without synchronizing individual
  paths. Flight includes mostly straight trajectories plus meaningful curves
  and loops, while flash synchronization remains a separate behavior.
  [Open study and movies](https://pmc.ncbi.nlm.nih.gov/articles/PMC7536049/)
  are CC BY 4.0; the
  [3D trajectory dataset](https://datadryad.org/dataset/doi%3A10.5061/dryad.gb5mkkwvd)
  is CC0.
- Medicinal-leech evidence distinguishes `0.3-0.5 s` swimming cycles from
  much slower `2-20 s` anchor-based crawl cycles. A direct spontaneous
  transition remains missing, but the two gait states are no longer
  provisional. [Swimming kinematics](https://pmc.ncbi.nlm.nih.gov/articles/PMC3027469/)
  and [crawl/swim behavior](https://pmc.ncbi.nlm.nih.gov/articles/PMC2323911/)
  are strong family proxies.
- Barn-owl kinetics support a force-concentrated strike and a softer landing
  that spreads impulse through greater body displacement. Battle Bog should
  not reuse one landing animation for strike contact and ordinary descent.
  [Barn-owl kinetics](https://pmc.ncbi.nlm.nih.gov/articles/PMC4148188/)
  are available under CC BY 3.0.

### Partial Evidence

- [NPS beaver footage](https://www.nps.gov/media/video/view.htm?id=5E9B7477-0D02-43A4-98C7-8F7818DDA502)
  shows surface travel and turning at `0:00-0:18`. Wildlife mechanics describe
  relaxed simultaneous hind-foot strokes, alternating faster strokes, tucked
  forefeet and the tail primarily as rudder/dive plane. Do not animate the
  tail as a constant paddle.
- [PBS Kansas mink footage](https://www.pbs.org/video/positively-kansas-1111-jlbdho/)
  contains exact-species land/water hunting from `21:32-26:38`; water entry can
  reduce the animal to a surface ripple and underwater crevice hunting appears
  around `26:04`. Fixed-camera entry and exit remain weak.
- [Great blue heron ML435241](https://macaulaylibrary.org/video/435241) and a
  [180 fps fishing clip](https://www.youtube.com/watch?v=OvNQjqIIuaU) provide
  exact-species loading, release and recoil candidates. Frame extraction is
  still required.
- [PBS North Carolina bog turtle footage](https://www.pbs.org/video/bog-turtles-big-trouble-for-our-smallest-turtle-ci8xqd/)
  shows an exact-species bog release around `5:19-5:25`, supporting a low
  mud-dependent entrance but not paddle or full shoreline transition.

### Open Evidence

- Exact chorus frog travel-to-water footage remains unavailable. The cricket
  frog surface-skitter remains a biomechanical proxy only.
- Prior Battle Bog research uses Belted Kingfisher as its leading species
  reference, but a complete perch/hover/dive/submerge/emerge/reset chain is
  still unverified.
- Clean owl strike-to-recovery footage remains missing despite strong impact
  mechanics evidence.
- Scientific wolf-spider footage covers excavation rather than prey ambush.
  Unverified reposts must not become animation evidence.

## Highest-Priority Missing Footage

- exact chorus frog ordinary travel and water entry;
- overhead bog turtle walk, paddle and shoreline transition;
- beaver underwater turns and object transport;
- mink entry and exit from one fixed camera;
- complete high-frame-rate kingfisher perch/hover/dive/submerge/emerge chain;
- overhead owl dive, impact and recovery;
- great blue heron frame-level loading through recoil;
- wolf spider overhead burrow ambush;
- spontaneous leech crawl/swim transitions.

These are bounded research gaps. They do not block the first Alligator
prototype, but Kingfisher and family-wide movement briefs should not be locked
until the relevant gaps are filled.

## Implementation Translation

The evidence strengthens the existing small-primitives approach:

- deterministic family movement profiles own acceleration, braking and turn;
- creature-specific exceptions own posture and terrain transitions;
- authored animation exposes, but does not redefine, simulation timing;
- render overlays own gait, squash, wake, ripple, shadow and altitude cues;
- AI consumes the same turn, terrain and transition constraints as players;
- truth footprint and capsule remain independent of visual overhang.

The first prototype should add no universal animal controller. It should prove
these contracts on Alligator, then generalize only what Kingfisher and Mosquito
also need.
