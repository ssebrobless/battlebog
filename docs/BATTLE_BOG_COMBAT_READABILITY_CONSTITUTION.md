# Battle Bog Combat Readability Constitution

Status: research-derived prototype targets

Compiled: 2026-07-27

Primary evidence:

- Battlerite normal-player and developer sources
- SUPERVIVE official and normal-player footage
- Pokemon UNITE and Temtem: Swarm creature footage
- `docs/RESEARCH_WILDLIFE_MOVEMENT_EVIDENCE.md`

Values in this document are starting ranges for prototype testing, not final
balance constants.

## Core Contract

```text
RESPONSIVE INTENT
      |
      v
ANIMAL PREPARATION
      |
      v
TACTICAL WARNING
      |
      v
CONTACT + MATERIAL IMPACT
      |
      v
AFTERSTATE
      |
      v
VISIBLE RECOVERY
```

Every discrete damaging attack must expose enough simulation-owned state for
authored animation to communicate:

`TEL_warning -> HIT_active -> FX_afterstate -> RECOVERY_weakpoint`

Animation may exaggerate these phases. It must not invent a reaction window
that the simulation does not provide.

Damage ownership is classified before presentation:

- discrete attacks use the full timeline;
- channels and contact DPS warn on channel entry, direction or proximity rather
  than replaying startup every tick;
- persistent hazards warn on creation and material-state changes;
- retaliation and passives expose trigger and aftermath;
- periodic damage exposes persistent status ownership rather than a new attack
  pose for every tick.

## Camera

- Preserve stable model scale during ordinary combat.
- Do not use routine impact zooms or camera shake to manufacture weight.
- Keep the controlled creature in a central safe region with mild cursor lead.
- Reserve stronger camera displacement for major forced movement or exceptional
  objective events.
- Validate every rule at the real `1280 x 720` player camera.

Battlerite footage maintained stable scale without obvious combat zoom punches
in the measured match. SUPERVIVE likewise used smooth near-central following
through ordinary fights.

## Creature Occupancy

Research ranges:

| Source | Ordinary Body Occupancy |
| --- | --- |
| Battlerite | about `6-11%` of screen height |
| SUPERVIVE | about `5-8%` of screen height |
| Pokemon UNITE | about `4-8%` of viewport width |
| Temtem: Swarm | about `3-4%` of viewport width |

Battle Bog starting targets:

- ordinary body width: `4-7%` of viewport;
- ordinary body height: approximately `5-10%` of viewport;
- long-body length: `8-16%` where the real species warrants it;
- tiny creatures may fall below these ranges only when silhouette, contact
  shadow, truth ring and movement signature compensate;
- large creatures should gain readable length or mass according to body plan,
  not uniform enlargement.

Visible scale, collision scale and flight height remain independent.

## Aim

Every creature exposes an anatomical `aim_axis` before release.

| Channel | Ownership |
| --- | --- |
| Travel | root, hips and trunk follow actual velocity and turn limits |
| Attention | head, eyes, bill, neck, forelimbs or claws track aim within anatomy |
| Strike | visible commitment aligns the body only when the attack needs it |

Humanoid shoulder twists, weapon windups and planted two-foot recoveries are not
universal solutions. Animal equivalents include neck draw, jaw opening, torso
compression, tail counterbalance, wing tuck, abdomen recoil, shell brace and
swarm deformation.

## Timing Targets

Starting prototype ranges:

| Phase | Light | Heavy Or Major |
| --- | ---: | ---: |
| Locomotion start | `120-220 ms` | `200-350 ms` |
| Attack anticipation | `250-450 ms` | `450-800 ms` |
| Localized hit peak | `70-130 ms` | test by material |
| Material aftermath | `250-400 ms` | test up to `500 ms` |
| Recovery | `180-300 ms` | `300-550 ms` |

Battlerite supplied a measured example in which a projectile remained trackable
for about `0.43 s`, a strong hit flash persisted about `0.10-0.17 s`, and the
associated bloom decayed around `0.33 s` after contact. These are reference
observations, not values to copy.

The crayfish research supplies a biological example: `0.20 +/- 0.08 s` of
preparatory pleopod movement before a `0.02-0.04 s` tail flip. Battle Bog should
make the preparation the warning and preserve the fast active burst.

Species exceptions may exceed the starting recovery envelope when their
gameplay purpose is explicit and tested. Alligator's provisional `0.80 s`
missed-bite recovery is one such candidate, not a roster-wide default.

## Telegraph Scale

Starting effect footprints:

- ordinary spatial attacks: `1.5-3` creature widths;
- major creature signatures: `4-6` creature widths;
- boss signatures may exceed this only while ground truth remains readable;
- bright boundaries and restrained interior fill are the default for danger
  regions;
- dangerous precision attacks earn explicit lines, corridors or landing
  projections;
- ordinary projectiles should first rely on pose, launch and trajectory.

SUPERVIVE effects reaching `5-9` character widths and obscuring ground for
multiple seconds are an upper-limit anti-pattern for ordinary Battle Bog
combat.

## Layer Priority

From highest persistence to first suppressed:

1. positional truth, target truth and team truth;
2. unavoidable or imminent tactical warnings;
3. controlled-creature and critical status information;
4. body silhouette and anatomical aim;
5. hit confirmation and displacement;
6. material-specific aftermath;
7. creature-flavor particles;
8. environmental ambience.

Ordinary effects should not fully hide a combatant for more than approximately
`250 ms`. A major signature should restore positional truth within about
`500 ms`.

The full-bright contact core has a stricter limit: under about `100 ms` for
ordinary attacks and `250 ms` for signatures. See
`docs/BATTLE_BOG_VFX_AND_MATERIAL_GRAMMAR.md`.

When three or more bodies overlap tightly:

- suppress secondary particles;
- aggregate repeated damage numbers;
- preserve truth rings, warnings and critical statuses;
- retain contact shadows and landing projections;
- reduce environmental reaction opacity or frequency.

## Positive Whiff Language

Absence of damage is insufficient feedback.

Misses need an authored recovery cue appropriate to the animal:

- tongue recoil;
- beak follow-through;
- claw skid;
- jaw overextension;
- tail overswing;
- shell imbalance;
- disturbed water without contact;
- wing braking beyond the target;
- swarm envelope overshoot.

The recovery must expose when control and punishability return.

## Flight And Underwater Truth

Every airborne attack combines:

- body offset and attack pose;
- contact shadow or projected landing area;
- motion connector such as feathers, wind streak or altitude line;
- clear transition into a low punishable state.

Every submerged attack combines:

- surface ripple;
- directional wake;
- muted submerged silhouette;
- expanding contact or emergence ring;
- visible body reaching the surface at `HIT_active`;
- a readable post-emergence recovery.

Prototype underwater emergence with roughly `0.6-0.9 s` of readable buildup,
then tune by creature and reaction test.

## Information Hierarchy

Always visible:

- controlled creature health and hunger;
- immediately available abilities;
- stocks;
- compact minimap;
- critical warnings.

Contextual:

- aim and cast state;
- deposit and breeding interaction;
- boss wake, contest, claim and steal;
- reveal, heard, last-known and suspected states;
- altitude and submergence when world cues alone are insufficient.

Expanded:

- detailed squad assignments, intent history and stock detail;
- boss-meter economy;
- route and objective timing;
- visibility history;
- strategic map detail.

Objective phases use three channels together:

1. world event;
2. minimap state;
3. concise event text.

## Source Anchors

- [Battlerite Ashka 3v3](https://www.youtube.com/watch?v=Im0De30GnEE):
  measured sequence around `2:32-2:34`.
- [Battlerite networking movement](https://blog.stunlock.com/dev-blog-008/):
  developer requirement for responsive direct control.
- [Battlerite Making Raigon](https://blog.stunlock.com/dev-blog-003/):
  consequence-scaled aim, control and counterplay cues.
- [SUPERVIVE normal ranked match](https://www.youtube.com/watch?v=1MMXAN-NIWs):
  ordinary fight `1:12-2:20`, crowded peaks `8:15-9:52`.
- [SUPERVIVE official full match](https://www.youtube.com/watch?v=Fs9pGnI345E):
  boss communication `10:40-11:10`.

## Failure Conditions

The combat presentation fails when:

- damage occurs before an actionable warning phase exists;
- direction can be read only from a cursor or HUD icon;
- height or submergence depends on one fragile cue;
- full-body flashes erase species identity;
- ordinary effects repeatedly conceal combatants beyond the occlusion target;
- a miss has no positive recovery signal;
- camera motion changes apparent scale during ordinary exchanges;
- environment detail hides traversable edges or warnings;
- AI receives visibility or attack truth players cannot obtain.
