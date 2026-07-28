# Battle Bog Damaging Action Inventory

Status: implementation prerequisite for roster-wide combat migration

Compiled: 2026-07-28

Authority:

- `BATTLE_BOG_DECISIONS.md`, especially Decisions #23, #24 and #30;
- `BATTLE_BOG_ORDINARY_ATTACK_TIMELINE_SPEC.md`;
- `BATTLE_BOG_ROSTER_WIDE_CHARACTER_COMPLETION_ROADMAP.md`.

This ledger covers every current player-creature damage source. It must be
updated whenever a damaging action is added, removed or changes ownership.

## Timing Classes

```text
DISCRETE  startup -> active -> hit/whiff/interrupted recovery
DASH/AIR  startup -> travel -> contact-active -> recovery
CHANNEL   startup -> owned pulse cadence -> release/interrupted exit
REACTIVE  visible armed state -> trigger -> aftermath
FIELD     creation cue -> owned tick cadence -> lifetime -> teardown
SUMMON    summon warning -> summon-owned attack phases -> attribution
```

Decision #23 applies directly to `DISCRETE` and `DASH/AIR`. `CHANNEL`,
`REACTIVE`, `FIELD` and `SUMMON` are formal continuous/indirect timing
contracts, not exemptions from deterministic cadence, readable cues, tests or
captures.

Every action requires:

- creature, action, source file/function, simulation owner and config path;
- acceptance rule, startup, active/release, recovery and cadence;
- aim/geometry policy, movement policy and recovery lock;
- counter-hit policy and any spawned-child owner;
- hit, whiff or justified no-whiff rule;
- interruption, switch, death and match-freeze cleanup;
- player/PvAI routing, focused tests, captures, status and any child-tick
  cadence/lifetime rationale.

The roster table below is the independently code-searched discovery ledger.
Before a row is implemented, its migration pull request adds the exact fields
above to that row or a linked action record. The migration cannot begin until
an independent reviewer confirms no code path or policy remains unclassified.

## Roster Inventory

| Creature | Damaging Action | Owner | Class And Current State | Required Migration Evidence |
| --- | --- | --- | --- | --- |
| Bullfrog | Bite plus conditional Swallow | `scripts/sim/kits/bullfrog.gd::_bite`, `_try_swallow` | `DISCRETE`; immediate | hit/whiff/interruption, locked aim, eligible/ineligible execute |
| Bullfrog | Lunge impact | `bullfrog.gd::_update_lunge` | `DASH`; damage at dash completion | startup, travel, contact/miss and recovery |
| Chorus Frog | Tongue Poke | `scripts/sim/kits/chorus_frog.gd::tick` | `DISCRETE`; immediate line query | tongue-tip hit, shaft miss, locked direction and recoil |
| Newt | alternating Tail Swing | `scripts/sim/kits/newt.gd::_tail_swing` | `DISCRETE`; immediate | side at acceptance, rejection with tail loss, interruption |
| Newt | Toxic Secretion retaliation | `newt.gd::on_melee_contact_damage` | `REACTIVE` | armed cue, melee-only trigger, DOT cadence and expiry |
| Newt | Rib Exudation burst and DOT | `newt.gd::on_damage_taken` | `REACTIVE` | threshold crossing, exact burst/DOT and cooldown |
| Cane Toad | Poison Stream plus DOT | `scripts/sim/kits/cane_toad.gd::_tick_poison_stream` | `CHANNEL`; immediate `0.25 s` pulses | startup, first-pulse delay, release/stun exit, aim constraint and ammo exhaustion |
| Cane Toad | Bufotoxin retaliation | `cane_toad.gd::on_melee_contact_damage` | `REACTIVE` | persistent armed cue, melee-only trigger, stacks and teardown |
| Cane Toad | Toxic Skin retaliation | `cane_toad.gd::on_melee_contact_damage` | `REACTIVE` | active-window cue, stacks, overlap with Bufotoxin and cleanup |
| Snapping Turtle | Bite | `scripts/sim/kits/snapping_turtle.gd::tick`, `_land_bite` | `DISCRETE`; local `0.7 s` windup | replace local timer; hit/whiff/interruption and committed shape |
| Snapping Turtle | Grab-empowered Bite | `snapping_turtle.gd::tick`, `_land_bite` | `DISCRETE`; next-attempt modifier | ordinary/Grab geometry, pull/latch, consumption policy |
| Water Snake | Bite impact and bleed | `scripts/sim/kits/water_snake.gd::_bite` | `DISCRETE`; immediate | active-only hit, exact bleed application and miss |
| Water Snake | latched Bite DPS | `water_snake.gd::_tick_latched` | `CHANNEL` | acquire, hold, struggle, pulse cadence, release and invalid target |
| Water Snake | Ingestion execute | `water_snake.gd::_try_ingestion` | `REACTIVE/CHANNEL` finisher | eligibility cue, execute moment, cooldown and lifecycle safety |
| Bog Turtle | Headbutt plus self-recoil | `scripts/sim/kits/bog_turtle.gd::_headbutt` | `DISCRETE`; both immediate | active-only enemy/self damage, hit/whiff recovery and basking follow-up |
| Alligator | Bite | `scripts/sim/kits/alligator.gd::_request_bite`, `_resolve_bite` | `DISCRETE`; timeline prototype complete, Decisions #23-26 conformance open | correct recovery/action lock/counter/hitstop, then add real camera, shoreline and lifecycle evidence |
| Alligator | Death Roll DPS | `alligator.gd::_tick_death_roll` | `CHANNEL` | startup, pulse cadence, release/interruption and weakpoint evidence |
| Owl | ground Peck | `scripts/sim/kits/owl.gd::tick` | `DISCRETE`; immediate | grounded phases, aim lock, hit/whiff and recovery |
| Owl | Swoop | `owl.gd::_swoop` | `AIR`; same-tick damage before current render startup | target lock, early warning, descent, contact/miss, low window and braking |
| Great Blue Heron | Spear | `scripts/sim/kits/great_blue_heron.gd::_spear` | `DISCRETE`; immediate line | planted load, locked line, active spear, whiff opening, recoil and airborne rejection |
| Kingfisher | ground Peck | `scripts/sim/kits/kingfisher.gd::_peck` | `DISCRETE`; immediate | ground context, locked beak contact, hit/whiff and recovery |
| Kingfisher | air Peck | `kingfisher.gd::_peck` | `AIR`; immediate | airborne context, altitude/low-window truth and recovery |
| Kingfisher | movement-boosted Plunge | `kingfisher.gd::_peck` | `AIR`; immediate | accepted charge, corridor, water entry/contact, miss and reset |
| Duck | right Wing, left Wing, Bite | `scripts/sim/kits/duck.gd::tick` | `DISCRETE`; immediate chain | three-step alternation, Mobbing consumption and airborne rejection |
| Duck | Duckling Peck | `scripts/sim/pets/duckling.gd::_physics_process` | `SUMMON`; immediate pet hit | pet aim/startup/contact/recovery, owner attribution and retirement |
| Water Shrew | Bite | `scripts/sim/kits/water_shrew.gd::_bite` | `DISCRETE`; immediate | phases, hit/whiff, stack application and capture |
| Water Shrew | Proenkephalin-empowered Bite | `water_shrew.gd::_bite` | `DISCRETE`; next-hit control | primed cue, whiff persistence, active-only control and interruption policy |
| Beaver | Chomp | `scripts/sim/kits/beaver.gd::tick` | `DISCRETE`; immediate | hit/whiff/interruption, locked aim and enemy versus cover contact |
| Otter | Bite plus automatic latch | `scripts/sim/kits/otter.gd::_bite` | `DISCRETE/CHANNEL`; immediate entry | bite phases, latch acquisition, hold/release and invalid target |
| Otter | Gang Up Bite | `otter.gd::_bite` | `DISCRETE`; currently attempt-consumed | armed cue, whiff persistence and valid-latch consumption |
| Otter | Tail Whip | `otter.gd::_tail_whip` | `DISCRETE`; immediate | committed arc, alternation, multi-hit rule and recovery |
| Mink | Bite | `scripts/sim/kits/mink.gd::tick` | `DISCRETE`; immediate | hit/whiff/interruption and locked aim |
| Mink | Choke dash impact | `mink.gd::tick` | `DASH`; contact damage | warning, travel, contact/miss, latch and three-second miss recovery |
| Mink | Choke execute | currently `scripts/sim/creature.gd::_tick_latch` | `CHANNEL` finisher; wrong generic owner | move to Mink kit, countdown cue, release, execute and cooldown |
| Leech | Leech Projectile plus attach DOT | `scripts/sim/kits/leech.gd::_fire_primary`, `attach_leech` | `DISCRETE` release plus `CHANNEL` attachment | startup, release/resource spend, flight/miss, attach cadence and teardown |
| Leech | Sensory Crypt multi-attach DOT | `leech.gd::_sensory_crypt` | `DISCRETE/FIELD`; immediate multi-attach | launch/contact, water-body filtering, broadcast cue, cadence and teardown |
| Crayfish | alternating Pinch | `scripts/sim/kits/crayfish.gd::_pinch` | `DISCRETE`; immediate | side at acceptance, active-only damage and interruption |
| Crayfish | Caridoid Escape smack | `crayfish.gd::_escape` | `DASH`; immediate query plus backward dash | front geometry, backward travel, contact/miss and recovery |
| Mosquito Swarm | Piercing Swarm projectile and AOE | `scripts/sim/kits/mosquito_swarm.gd`; `scripts/sim/entities/mosquito_field.gd::_physics_process` | `DISCRETE` release plus `FIELD` | release, collision/max-range activation, pulse/overlap, lifetime and teardown |
| Mosquito Swarm | Breeding Grounds trail AOE | `mosquito_swarm.gd`; `mosquito_field.gd::_physics_process` | `FIELD` | trail creation spacing, pulse/overlap, ownership and expiry |
| Mosquito Swarm | Unswattable contact DPS | `mosquito_swarm.gd::_tick_contact` | `FIELD/REACTIVE` | enter/exit cue, exact pulse, re-entry and resource gain |
| Wolf Spider | Bite Lunge | `scripts/sim/kits/wolf_spider.gd::_start_lunge`, `_tick_lunge` | `DASH`; damage at completion/contact | aim-freeze, travel, contact/miss, latch and recovery |
| Wolf Spider | Burrow Charge | `wolf_spider.gd::_start_lunge`, `_tick_lunge` | `DASH`; emergence into charge | hidden warning, emergence, contact/miss and empty-charge policy |
| Wolf Spider | Spiderling Bite | `scripts/sim/pets/spiderling.gd::_physics_process` | `SUMMON`; immediate pet hit | pet phases, owner attribution, crowd density and retirement |
| Firefly | Firefly Spark | `scripts/sim/kits/firefly.gd::_fire_projectile`; `scripts/sim/entities/firefly_projectile.gd::_hit_scan` | `DISCRETE` release; later homing contact | release, acquisition/reacquisition, expiry whiff, collision and reveal |

## Prototype Migration Records

Notation in seconds:

- `D startup/active/whiff/interrupted`; hit recovery is `whiff * 0.60`.
- `X startup/travel/contact/whiff/interrupted`.
- `P startup/release/released-recovery/interrupted`.
- `ARM startup/arm-active/recovery/interrupted`.
- `CH startup/pulse-or-channel/release-exit/interrupted-exit`.

Any positive enemy-sourced damage during authoritative startup can counter-hit,
including projectile, summon, DOT and sustained field ticks. Self and
environment damage cannot. Recovery blocks new action starts. Spawned children
continue independently unless their row says otherwise.

### Discrete, Dash And Aerial Actions

| Action | Prototype Timing | Acceptance, Geometry And Outcome |
| --- | --- | --- |
| Bullfrog Swallow | child of Bite active | first normal Bite contact only; target smaller and at `<=10%` HP; execute for `10x` max HP and heal 25%; inherit Bite movement/recovery; no second counter bonus |
| Bullfrog Lunge | `X 0.12/0.18/0.06/0.30/0.36`; hit `0.18` | require charge; lock heading; fixed 3 u dash; endpoint 3x2 impact hits each legal target once and knocks 1 u; no steering; 3 s recharge |
| Snapping Turtle Grab | `ARM 0.10/0.04/0.15/0.20`; empowered Bite uses roadmap timing | arm without cooldown; accepted empowered attempt consumes Grab on hit or whiff; +1.5 u reach; first latchable hit pulls to jaw and latches 1.6 s; 5 s cooldown starts on attempt |
| Kingfisher Air Peck | `D 0.32/0.10/0.50/0.40`; hit `0.30` | lock heading and airborne variant; local 1 u beak; free ground-anchor travel; air plane; open 0.7 s low window at active |
| Kingfisher Plunge | `X 0.25/0.20/0.12/0.65/0.50`; hit `0.39` | require airborne plus 2 u accumulated travel; lock target within 2 u; no steering; endpoint 1 u beak contact; consume charge once; 0.7 s low window on hit or miss |
| Owl Swoop | `X 0.25/0.20/0.12/0.65/0.50`; hit `0.39` | reject grounded/perched variants; lock point within 6 u; no steering; endpoint contact can hit ground targets; break stealth on acceptance; 0.7 s low window then braking recovery |
| Otter Tail Whip | `D 0.30/0.10/0.55/0.40`; hit `0.33` | commit alternating back-to-front left/right arc; each target once; 1.5 u outward knockback; 60% movement in startup/recovery; 5 s cooldown |
| Crayfish Caridoid Escape | `D 0.12/0.06/0.28/0.30`; hit `0.168`; then 0.22 s dash | lock facing; one front 1 u smack during active; fixed 3 u backward recovery dash; no steering; 3 charges with 5 s recharge |
| Mink Choke impact | `X 0.24/0.10/0.06/3.00/0.50`; landed recovery `1.80` after latch | lock heading; fixed 2 u dash; 1.5-body-radius corridor; first latchable contact takes 20 and starts Choke; miss serves full 3 s; landed recovery waits for latch end |
| Wolf Spider Bite Lunge | `X 0.00/0.16/0.08/0.45/0.35`; hit `0.27` | lock aim at acceptance; the existing fixed 2 u/0.16 s unsteerable travel is the authoritative warning/startup substate; first 1 u contact resolves once and may latch; miss serves full recovery |
| Wolf Spider Burrow Charge | `X 0.30/0.16/0.08/0.55/0.45`; hit `0.33` | require legal target within 4 u before emergence; empty request spends nothing and stays burrowed; rustle startup; lock heading; fixed 2 u dash; first contact may latch |

### Reactive, Armed And Channel Actions

| Action | Prototype Timing | Ownership, Cadence And Cleanup |
| --- | --- | --- |
| Newt Toxic Secretion | `ARM 0.18/0.04/0.20/0.25`; armed 5 s | melee attacker receives 60% dealt damage over 3 s; each contact creates independent target-owned DOT; 6 s cooldown at acceptance; activation startup is counter-vulnerable |
| Newt Rib Exudation | reactive; aftermath `0.35`; cooldown 10 s | visible when ready; crossing from above to `<=10%` HP triggers once for 50 burst plus 60% triggering damage over 3 s against source; DOT persists after Newt death |
| Cane Toad Poison Stream | `CH 0.30/0.25/0.25/0.35` | first pulse at channel entry, then every 0.25 s; each pulse deals 5 and applies 20 over 2 s; live aim capped at 270 deg/s; 3x1 line doubled in Thanatosis; ammo drains 10/s only while active |
| Cane Toad Bufotoxin | persistent reactive; aftermath `0.18` | always armed while alive; melee contact applies 24 over 2 s, maximum five same-source stacks; target owns DOT; ticks have no action lock or counter bonus |
| Cane Toad Toxic Skin | `ARM 0.20/0.04/0.20/0.30`; armed 10 s | melee contact applies 20 over 3 s, maximum three stacks; application x1.05 during Thanatosis; 8 s cooldown at acceptance; survives suppression, clears on death/respawn |
| Water Snake Bite bleed | child of Bite active | valid Bite applies 18 over 3 s; applications stack independently; target owns DOT through latch release or Snake death |
| Water Snake latched Bite | Bite contact entry; release `0.20`, interrupted `0.30` | first latchable target; held Primary refreshes grip to 0.75 s; `1%` target max HP/s; general struggle and 45% movement rules; no second counter bonus |
| Water Snake Ingestion | `D 0.35/0.06/0.60/0.30`; hit `0.36` | auto-warning when attached smaller victim reaches `<=15%` HP; target/eligibility valid through active; execute and heal 85% target max HP; 20 s cooldown only on execute |
| Alligator Death Roll | `CH 0.35/continuous/0.40/0.55`; duration 5 s | require valid latch and both actors in water; root ordinary actions; deterministic 30 DPS; preserve rotational movement; 5 s cooldown at acceptance; release latch on completion/interruption |
| Water Shrew empowered Bite | `ARM 0.10/0.04/0.15/0.20`; inherit Bite | arm reserves charge; persists through whiff/suppression; spend charge and start 3 s recharge only on valid hit; clear on death/respawn |
| Otter ordinary latch | child of Bite active; hold 2 s | first latchable target; no hold DPS; general struggle; invalid target produces ordinary hit recovery |
| Otter Gang Up | `ARM 0.15/0.04/0.20/0.25`; inherit Bite | persist through whiff/interruption; consume only on valid latchable hit; immobilize target 2 s; final cohort behavior waits on the Otter identity gate below |
| Mink Choke execute | 10 s latch countdown; active `0.06`; break exit `0.35`; success recovery `0.60` | Mink kit owns countdown/execute; visible 10/5/3/1 s checkpoints; death only at zero; grip break cancels; 10 s cooldown after release |

### Spawned Children And Fields

| Action | Exact Child Contract | Targeting And Ownership |
| --- | --- | --- |
| Duckling Peck | `D 0.18/0.05/0.25/0.20`, hit `0.15`; interval 0.8 s | Duckling-owned timeline; nearest legal target locked at startup; stationary until recovery; invalid target whiffs; retire on death/owner retirement |
| Spiderling Bite | `D 0.14/0.05/0.25/0.20`, hit `0.15`; interval 0.7 s; lifetime 12 s | Spiderling-owned timeline/attribution; nearest legal target locked; invalid target whiffs; retire on owner death or match end |
| Leech Projectile attachment | flight `<=0.747 s`; attach 3 s at 10 DPS | parent `P 0.30/0.06/0.20/0.30`; heading locks; spend body-leech at release; projectile owns flight; target attachment owns DOT/reveal |
| Leech Sensory Crypt | `P 0.40/0.06/0.35/0.45`; attach 6 s at 10 DPS | require water and same-water legal target; snapshot targets at release; spend one body-leech per attach; reject no-target without cost; 14 s cooldown on release |
| Mosquito primary field | flight `<=0.747 s`; field 3 s, radius 3 u, 15 DPS | field on collision/max range; overlapping fields damage independently, 5% slow does not stack; persists through owner death; retire on respawn/switch/match end |
| Mosquito Breeding Grounds | `ARM 0.20/0.04/0.20/0.30`; active 6 s | first field on first moving active tick, then every 0.35 s while moving; fields last 3 s; cap 14 trail/20 total and retire oldest; 10 s cooldown after trail |
| Mosquito Unswattable | persistent overlap integration, 10 DPS | always-visible envelope; continuous per-target damage; enter/exit cues, no tick spam; immediate re-entry; blood 1:1 and hunger 0.5:1 from actual damage |
| Wolf Spider Bite latch | child of Lunge contact; maximum 3 s | first latchable target; held Primary refreshes grip to 0.45 s; 45% slow; no latch damage; release on button-up, invalid target, suppression or timeout |
| Firefly Spark | flight `<=0.889 s`; one impact; reveal 2 s | parent `P 0.24/0.06/0.18/0.28`; nearest legal target fixed at release; invalid target continues current heading and expires; child owns flight, damage, harvest and reveal |

Preserve the current repeatedly stacking Cane Toad Stream DOT and independent
Mosquito-field damage through migration. Measure both as explicit balance
anomalies in PvAI stages before changing values.

`HUMAN GATE - Otter pack identity:` roster intent says Gang Up sends all three
otters, while current code has only the attacker. Simulation migration may
proceed for Bite, Tail Whip, latch timing and the armed-state contract, but
Gang Up cohort range, follower travel/teleport rules, individual health and
control transfer must be selected before final Otter combat and assets.

## Policies Locked By Existing Text Or Behavior

- Duck's chain advances on accepted attempts. Mobbing survives whiff and
  interruption and is consumed only by the next landed primary.
- Bog Turtle self-recoil occurs once at active resolution on hit or whiff.
  While basking, the ally heal/buff follows that same accepted active
  resolution.
- Leech spends one body-leech when its projectile is released, including a
  later miss.
- Mosquito Swarm primary has no traditional whiff: its projectile creates the
  field on collision or at maximum range.
- Mink Choke miss recovery is three seconds; on hit, cooldown begins after
  latch release.

## Resolved Migration Policies

These are `PROTOTYPE` implementation decisions. They remove guesswork without
turning tuning defaults into permanent balance law.

| ID | Action | Migration Decision |
| --- | --- | --- |
| P1 | Snapping Turtle Grab | consume on the accepted empowered Bite attempt, including whiff; this preserves current behavior and the roster's "next attack" wording |
| P2 | Water Shrew empowered Bite | arming reserves but does not spend a charge; persist through ordinary whiff and temporary suppression; consume the charge and begin cooldown on the valid empowered hit; clear unspent priming on death/respawn |
| P3 | Otter Gang Up | persist through whiff and interruption; consume only on a valid latchable hit, matching "next hit" |
| P4 | Wolf Spider empty Burrow Charge | if no legal target exists in range, remain burrowed and spend no primary/Q cooldown; only a target-backed accepted charge may emerge |
| P5 | Firefly Spark | select the nearest legal homing target at release; never replace it in flight; if it becomes invalid, continue on current heading and expire as a whiff |

## Completion Rule

A creature's combat migration cannot be marked complete until every row for
that creature is either:

1. implemented and proven under its timing class; or
2. explicitly documented as non-damaging after code and roster data agree.
