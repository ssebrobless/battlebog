# Battle Bog VFX And Material Grammar

Status: research-derived prototype targets

Compiled: 2026-07-27

## VFX Formula

```text
THE MACHINES ARENA          HADES II
aim/path/target truth       material/direction/decay
             \                 /
              v               v
        BATTLE BOG EFFECT GRAMMAR
brief peak + biological material + persistent positional truth
```

Battle Bog transfers hierarchy, timing and material differentiation. It does
not transfer source palettes, motifs, reticles, glyphs or signature effect
shapes.

## Starting Budgets

| Property | Prototype Target |
| --- | --- |
| Ordinary hit peak | `60-130 ms`, localized to contact |
| Ordinary aftermath | `250-400 ms`; material-specific residue may test to `500 ms` |
| Signature aftermath | `0.8-1.5 s` only with persistent truth |
| Ordinary impact footprint | at most `1.25` creature widths |
| Telegraph interior | `15-30%` opacity with stronger boundary |
| Full-bright core | at most `15-20%` of total effect footprint |
| Full-bright body occlusion | below `100 ms` ordinary; below `250 ms` signature |
| Positional-truth occlusion | below `250 ms` ordinary; below `500 ms` signature |
| Crowd suppression | reduce secondary particles/trails `40-60%` when three major effects overlap |

The two occlusion limits are intentionally separate. Anatomy should return
quickly after the contact peak; truth rings and target position may persist
through a longer material aftermath.

## Material Vocabulary

| Material | Contact | Aftermath |
| --- | --- | --- |
| Water | thin bright contact sheet, droplets | directional wake, widening ripples |
| Mud | low clods, matte splash | short smear and settling debris; little bloom |
| Shell or stone | hard localized flash | angular chips and compact dust |
| Hide or scales | directional compression/slash accent | body reaction without metallic sparks |
| Feathers and air | curved pressure streak | feather separation and soft turbulence |
| Vegetation | bend and displaced leaves | settling motion rather than explosion |
| Swarm | density displacement | group-envelope deformation and individual recovery |

All material classes must remain distinguishable in grayscale through motion,
shape and decay rather than hue alone.

## Projectile Rules

- use a bright compact head and lower-opacity directional trail;
- preserve enough contour contrast to survive the local background;
- do not use a full source-to-target beam for a traveling projectile;
- keep launch pose and projectile origin aligned to anatomical aim;
- suppress trailing flavor before projectile truth;
- aggregate rapid repeated hits rather than stacking identical flashes and
  numbers.

## Anti-Patterns

- persistent neon outlines replacing anatomy;
- full-body white bleaching;
- ordinary arena-sized spheres or screen-wide fans;
- effects remaining at full brightness over newer warnings;
- hue carrying team, danger and material simultaneously;
- importing Hades-level spectacle density into six-player combat;
- one generic impact reused for water, mud, shell, hide and feathers.

## Source Anchors

- [Machines Arena normal match](https://www.youtube.com/watch?v=VZN3grRMwuU):
  aim `0:35-0:41`, sphere `0:59-1:03`, crowd peak `5:26-5:34`.
- [Machines Arena visual update](https://themachinesarena.ghost.io/patch-notes-025/):
  developer presentation changes.
- [Hades II normal surface run](https://www.youtube.com/watch?v=ndjNBYOWohc):
  projectile/cast `2:15-2:19`, mixed materials `3:20-3:24`.
- [Hades II official showcase](https://www.youtube.com/watch?v=-SnaCUsUF3E):
  curated effect range, not timing evidence.
- [Hades clarity update](https://www.supergiantgames.com/blog/hades-the-nighty-night-update-patch-notes/):
  directional effects, rapid-hit differentiation, reduced obscuration and
  aggregated numbers as documented lineage.

## First Validation Slice

Use identical timing and camera for:

1. Alligator bite on hide.
2. Alligator tail slap in water.
3. Alligator tail slap in mud.
4. Shell contact.
5. Feather/air dive impact.
6. Three simultaneous major effects in mixed 3v3.

Capture native color, grayscale and color-vision transforms. A material fails
if testers need color to identify it or if contact truth becomes less precise
than the procedural baseline.
