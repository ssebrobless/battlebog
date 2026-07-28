# Battle Bog Creature Silhouette And Scale Constitution

Status: user-calibrated, prototype targets

Compiled: 2026-07-27

## Target Midpoint

```text
POKEMON UNITE
gameplay-scale readability + attack direction
                |
                v
          BATTLE BOG
heroic real-animal anatomy + readable compression
                ^
                |
TEMTEM: SWARM
soft motion + approachable dimensional finish
```

Battle Bog is closer to Pokemon UNITE in gameplay-scale clarity. Temtem
contributes softness, surface economy and approachable dimensional rendering.
Both are overruled by real animal anatomy whenever mascot containment would
erase species identity.

## Shape Rules

1. Never fit every creature into the same sphere, bean or capsule.
2. Give every species at least two silhouette-breaking anatomical features.
3. Preserve negative space among legs, wings, necks, claws, tails and body.
4. Compress total size without compressing defining body ratios.
5. Allow thin extremities to overhang the gameplay footprint honestly.
6. Use color and VFX to reinforce recognition, never rescue an unclear body.
7. Support low, long, lateral, winged and distributed silhouettes.
8. Keep most torso mass inside the authoritative footprint.
9. Keep team truth rings aligned to gameplay truth rather than visible overhang.
10. Judge silhouettes at normal camera in motion and crowded combat.

## Scale Compression

Battle Bog preserves believable tiers without reproducing unusable real-world
size differences.

| Tier | Visual Strategy |
| --- | --- |
| Tiny | readable extremities, stronger contact shadow, energetic movement and modest minimum occupancy |
| Small | species ratio preserved; no mascot inflation of head/body unless functionally justified |
| Medium | baseline body occupancy and clearest animation vocabulary |
| Large | gain length, breadth or height according to anatomy |
| Distributed | swarm envelope communicates gameplay mass while individuals remain visible |

Starting occupancy:

- ordinary width: `4-7%` of viewport;
- ordinary height: `5-10%` of viewport;
- long-body length: `8-16%`;
- target family ranges may depart from these after reaction and recognition
  testing.

Collision truth remains separately visible through debug overlays and truth
rings during production.

## Family Translation

| Family | Reference Contribution | Battle Bog Requirement |
| --- | --- | --- |
| Frogs | Greninja crouched direction, jumps and water attacks | Restore long rear legs, real loading, grounded landing and species-specific hop cadence |
| Birds | Talonflame/Cramorant wing and beak direction | Add authentic banking, longer anticipation, landing projection and vulnerable recovery |
| Shells | Crustle/Blastoise shell mass and frontal orientation | Preserve lateral legs, claws, necks and non-cubic shell identity |
| Long reptiles | Gyarados screen length and head-led route | Compress thickness carefully; head leads and body follows the traveled curve |
| Small mammals | Greedent tail exaggeration and compact recognition | Replace mascot waddle with bound, scurry, paddle or skim appropriate to species |
| Insects | Buzzwole limb-led contact only | Use authentic anatomy; swarms require many-body cohesion rather than one humanoid insect |
| Swarms | Pikmin group readability and wildlife evidence | Stable envelope, visible individuals and directional density shift |

## Material Direction

Target:

- matte painted dimensional surfaces;
- restrained highlights;
- materials that distinguish wet skin, feathers, shell, scales, fur, chitin and
  translucent wings;
- fewer surface details than close-up concept art;
- strongest value and color breaks at the head, attacking anatomy and major
  silhouette junctions.

Reject:

- uniform plastic gloss;
- excessive roundness;
- hyperreal skin/fur rendering;
- detail that disappears or flickers at normal camera;
- effect glow used as the primary species identifier.

## Directional Read

At rest, a player should identify:

- which end is the attack end;
- current travel direction;
- current attention direction;
- approximate height or depth state;
- small, medium, large or distributed size tier.

During attack, the organ that will make contact must lead the read before the
effect appears.

## Reference Anchors

- [Pokemon UNITE roster](https://unite.pokemon.com/en-us/pokemon/):
  official model and ability presentation.
- [Greninja normal match](https://www.youtube.com/watch?v=VunavFGKZSA):
  crouched axis and projectile combat.
- [Talonflame normal matches](https://www.youtube.com/watch?v=kderui0-myo):
  wing direction and body-shadow separation.
- [Gyarados normal match](https://www.youtube.com/watch?v=fVtBENsxgwo):
  long-body occupancy and following curve.
- [Temtem: Swarm](https://store.steampowered.com/app/2510960/Temtem_Swarm/):
  softer creature finish and crowd context.
- [Crema aiming update](https://crema.gg/temtem-swarm/swarm-patch-0-5/):
  aimed frontal attack behavior.
- [Crema hitbox update](https://crema.gg/temtem-swarm/swarm-patch-0-4-9-2/):
  visible-body hitbox alignment precedent.

## Prototype Acceptance

For Alligator, Kingfisher and Mosquito, capture:

- rest, start, travel, tight turn and reverse;
- attention change without travel;
- ordinary startup, active, hit, whiff and recovery;
- land/water or ground/air transition;
- own-team, enemy-team and visibility variants;
- one-on-one and six-creature overlap;
- grayscale and common color-vision simulations;
- truth footprint, capsule, shadow and aim-axis debug overlays.

A model fails if:

- species recognition depends on effects or labels;
- distinctive anatomy is folded into a common body envelope;
- a long body rotates rigidly;
- visible scale implies a false collision or altitude state;
- direction snapping overwhelms the intended continuous motion;
- crowd readability requires bleaching the whole body;
- close-up quality does not survive the normal camera.

