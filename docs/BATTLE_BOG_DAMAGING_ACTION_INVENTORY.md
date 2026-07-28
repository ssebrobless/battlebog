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
Discovery is complete; normalized action contracts are not. `R3.5` creates
`docs/action-contracts/<action_id>.json` for every independently owned action
and child effect below. Migration cannot begin until the contract validator and
an independent reviewer mark every action scheduled in that slice
`CONTRACT_READY`.

## Normalized Action Contract

Each JSON record uses schema version `1` and exactly these required keys:

```text
schema_version              action_id
creature_id                 display_name
r4_slice                    status
gate_id                     class
blocked_fields              source_paths
source_symbols              config_path
acceptance_owner            timeline_owner
contact_owner               child_owner
attribution_owner           teardown_owner
player_route                bot_route
acceptance_rule             rejection_rule
timing                      geometry
movement                    recovery_lock
counter_policy              resource_policy
outcome_policy              cadence_policy
lifecycle_policy            required_vectors
focused_test                scenario_ids
required_anchors            approving_review
```

`status` is one of `DISCOVERED`, `HUMAN_BLOCKED`, `CONTRACT_READY`,
`IMPLEMENTED`, `PROVEN`, `PROVEN_NON_DAMAGING` or `BLOCKED`. Normal progression
is `DISCOVERED -> CONTRACT_READY -> IMPLEMENTED -> PROVEN`; a verified
non-damaging modifier ends at `PROVEN_NON_DAMAGING`. `HUMAN_BLOCKED` names a
gate ID and can resume at `CONTRACT_READY`; `BLOCKED` names a conflict. `config_path` is
`data/battle_bog_roster.json::creatures[id=<creature_id>].stats.action_timelines.<action_id>`
for accepted player actions. Child-only cadence may name an owning code constant
only when it has no independent player trigger; its parent action still has the
roster config. No timing constant may have two authorities.

Scalar identity/owner/route/status/class/config fields are non-empty strings.
`gate_id` is an empty string except for `HUMAN_BLOCKED`, where it is the exact
human gate ID.
`class` is exactly one of `DISCRETE`, `DASH_AIR`, `CHANNEL`, `REACTIVE`,
`FIELD`, `SUMMON` or `MODIFIER`; hybrid ownership is split into linked records.
`source_paths`, `source_symbols`, `scenario_ids` and `required_anchors` are
non-empty unique string arrays. `blocked_fields` is a unique string array and
may be empty as described below. `required_vectors` is an object with exact keys
`accept`, `reject`, `hit`, `whiff`, `interrupt`, `suppression`, `switch`,
`source_death`, `target_death` and `match_freeze`. Each value is a fixture ID or
`not_applicable:<reason>` for a child, modifier or automatic reactive action
with no such phase.
`approving_review` is
`{"reviewer":String,"decision":"PASS","evidence_path":String}` at
`CONTRACT_READY` and later.

For ordinary statuses, `blocked_fields` is an empty array and all policy leaves
have their declared type. For `HUMAN_BLOCKED`, `gate_id` is non-empty,
`blocked_fields` lists exact JSON paths awaiting the decision, and only those
leaves are JSON `null`. Its review object is
`{"reviewer":"none","decision":"HUMAN_BLOCKED","evidence_path":String}`.
The JSON Schema expresses these as separate `oneOf` branches; `null` is illegal
for every other status.

Policy objects use these exact subkeys; unavailable numeric values are `-1.0`,
never omitted or `null`:

```text
timing:
  model, startup_sec, active_sec, travel_sec, pulse_interval_sec,
  hit_recovery_sec, whiff_recovery_sec, released_recovery_sec,
  interrupted_recovery_sec, lifetime_sec
geometry:
  shape_kind, origin_rule, dimensions_units, target_order, damage_plane,
  locks_at_acceptance
movement:
  startup_mult, active_mult, recovery_mult, steering_rule,
  forced_displacement_units, forced_displacement_sec
recovery_lock:
  blocks_primary, blocks_q, blocks_e, blocks_context, blocks_flight,
  allows_dash_cancel
counter_policy:
  startup_vulnerable, child_inherits_source, self_allowed, ally_allowed,
  environment_allowed
resource_policy:
  spend_phase, spend_amount, refund_rule, cooldown_start_phase
outcome_policy:
  hit, whiff, released, interrupted, no_whiff_reason
cadence_policy:
  cadence_mode, interval_sec, first_application, boundary_order, final_step,
  stacking_key, reapplication
lifecycle_policy:
  controller_switch, actor_death, source_death, target_death,
  respawn_replacement, match_freeze
```

String policy values use the exact phrases already written in the action's
prototype record or current code behavior. R3.5 does not paraphrase a behavior
into a new rule. The validator checks key/type/enum/cardinality completeness;
the independent reviewer checks that factual values match their cited source.

Routes use one grammar:

```text
player:<source-path>::<symbol>->InputFrame.BUTTON_<NAME>
bot:<bot-hook-path>::<symbol>->InputFrame.BUTTON_<NAME>
parent:<action_id>
passive:<source-path>::<symbol>
```

Accepted player actions require `player:` and `bot:` routes. Child records use
`parent:` for both. Reactions use `passive:` and name the bot route
`not_applicable:automatic reaction`.

Ownership fields are separate. `acceptance_owner` accepts/rejects input,
`timeline_owner` advances phases, `contact_owner` performs the query,
`child_owner` advances a projectile/field/DOT/summon after release,
`attribution_owner` supplies source/team identity, and `teardown_owner` clears
state. Use the literal `none` where a role does not exist.

The default lifecycle policy is:

```text
controller switch    accepted actor action continues; control suppression is
                     not an intentional release
actor death          hard-reset actor-owned commitment and unspawned release
source death         target-owned DOT and already spawned children continue
target death         target attachment/latch clears; free child follows contract
respawn/replacement  clear actor-owned state; retire children only if row says so
match freeze         freeze all timelines, ticks, cooldowns and teardown clocks
```

Any exception is explicit in the action record. A weaker executor may preserve
observed code or apply a written `PROTOTYPE` override; it may not invent a third
behavior. A conflict between code, roster and this ledger sets `status` to
`BLOCKED` and stops the slice.

Every action record contains deterministic vectors at fixed 60 Hz. The values
below are the required keys, not an array:

```text
accept       legal input at tick 0, exact accepted phase/resource/cooldown state
reject       illegal context, no commitment and no spend
hit          target at the contract's committed contact locus
whiff        same trace with target outside the committed shape
interrupt    interruption halfway through startup
suppression  held input suppressed during recovery/control transfer
switch       controller transfer during every owned phase
source_death source actor death during every owned phase
target_death target actor death during every owned phase
match_freeze freeze one tick before each damaging boundary
```

Each vector records seed `307`, initial actor/target state, per-tick input,
expected event order, exact total damage/resource/cooldown changes, final
outcome and teardown. Boundary time is simulation elapsed time; tests must not
round prototype seconds to an independently chosen animation frame.

Class anchor sets:

```text
DISCRETE  TEL+0, HIT-1, HIT+0, RECOVERY+0, RECOVERY_END
DASH_AIR  TEL+0, TRAVEL+0, HIT-1, HIT+0, RECOVERY+0, RECOVERY_END
CHANNEL   TEL+0, CHANNEL+0, FIRST_PULSE, STEADY_PULSE, RELEASE, EXIT_END
REACTIVE  ARMED+0, TRIGGER-1, TRIGGER+0, AFTERSTATE+0, TEARDOWN
FIELD     CREATE+0, FIRST_TICK, STEADY_TICK, FINAL_TICK, EXPIRE
SUMMON    SUMMON+0, CHILD_TEL+0, CHILD_HIT+0, OWNER_LOST, RETIRE
MODIFIER  ARMED+0, CONSUME+0, TEARDOWN
```

Use one scenario per `action_id`, with additional outcome scenarios only when a
single deterministic scenario cannot contain all required anchors. Creature
summary scenarios are indexes, not substitutes for action evidence.

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
| Crayfish | Caridoid Escape smack | `crayfish.gd::_escape` | `DISCRETE` contact plus recovery-owned backward displacement | front geometry, backward travel, contact/miss and recovery |
| Mosquito Swarm | Piercing Swarm projectile and AOE | `scripts/sim/kits/mosquito_swarm.gd`; `scripts/sim/entities/mosquito_field.gd::_physics_process` | `DISCRETE` release plus `FIELD` | release, collision/max-range activation, pulse/overlap, lifetime and teardown |
| Mosquito Swarm | Breeding Grounds trail AOE | `mosquito_swarm.gd`; `mosquito_field.gd::_physics_process` | `FIELD` | trail creation spacing, pulse/overlap, ownership and expiry |
| Mosquito Swarm | Unswattable contact DPS | `mosquito_swarm.gd::_tick_contact` | `FIELD/REACTIVE` | enter/exit cue, exact pulse, re-entry and resource gain |
| Wolf Spider | Bite Lunge | `scripts/sim/kits/wolf_spider.gd::_start_lunge`, `_tick_lunge` | `DASH`; damage at completion/contact | aim-freeze, travel, contact/miss, latch and recovery |
| Wolf Spider | Burrow Charge | `wolf_spider.gd::_start_lunge`, `_tick_lunge` | `DASH`; emergence into charge | hidden warning, emergence, contact/miss and empty-charge policy |
| Wolf Spider | Spiderling Bite | `scripts/sim/pets/spiderling.gd::_physics_process` | `SUMMON`; immediate pet hit | pet phases, owner attribution, crowd density and retirement |
| Firefly | Firefly Spark | `scripts/sim/kits/firefly.gd::_fire_projectile`; `scripts/sim/entities/firefly_projectile.gd::_hit_scan` | `DISCRETE` release; later homing contact | release, acquisition/reacquisition, expiry whiff, collision and reveal |

## Canonical Action IDs And Evidence Routes

R3.5 uses these IDs exactly. The default scenario ID is
`<action_id>_evidence`; add an outcome suffix only when the normalized contract
requires more than one scenario. Allowed suffixes are `_hit`, `_whiff`,
`_interrupt`, `_release`, `_expire`, `_owner_lost` and `_teardown`; no other
suffix is legal. The focused file proves every listed ID, not
only the creature's primary.

| R4 Slice | Focused Test | Required Action IDs |
| --- | --- | --- |
| R4A | `battle_bog_mosquito_swarm_timeline_check.gd` | `mosquito_primary_release`, `mosquito_primary_projectile`, `mosquito_primary_field`, `mosquito_breeding_trail_controller`, `mosquito_breeding_trail_field`, `mosquito_unswattable_contact` |
| R4A | `battle_bog_firefly_timeline_check.gd` | `firefly_spark_release`, `firefly_spark_projectile`, `firefly_spark_impact` |
| R4B | `battle_bog_newt_timeline_check.gd` | `newt_tail_right`, `newt_tail_left`, `newt_toxic_secretion_arm`, `newt_toxic_secretion_dot`, `newt_rib_exudation_burst`, `newt_rib_exudation_dot` |
| R4B | `battle_bog_crayfish_timeline_check.gd` | `crayfish_pinch_right`, `crayfish_pinch_left`, `crayfish_caridoid_escape` |
| R4B | `battle_bog_duck_timeline_check.gd` | `duck_wing_right`, `duck_wing_left`, `duck_bite`, `duck_mobbing_modifier` |
| R4B | `battle_bog_duckling_timeline_check.gd` | `duckling_peck` |
| R4C | `battle_bog_alligator_timeline_check.gd` | `alligator_bite`, `alligator_latch_hold`, `alligator_death_roll` |
| R4C | `battle_bog_bullfrog_timeline_check.gd` | `bullfrog_bite`, `bullfrog_swallow`, `bullfrog_lunge` |
| R4C | `battle_bog_water_snake_timeline_check.gd` | `water_snake_bite`, `water_snake_bleed`, `water_snake_latch_dps`, `water_snake_ingestion` |
| R4D | `battle_bog_kingfisher_timeline_check.gd` | `kingfisher_ground_peck`, `kingfisher_air_peck`, `kingfisher_plunge` |
| R4D | `battle_bog_owl_timeline_check.gd` | `owl_ground_peck`, `owl_swoop` |
| R4D | `battle_bog_cane_toad_timeline_check.gd` | `cane_toad_poison_stream`, `cane_toad_stream_dot`, `cane_toad_bufotoxin_trigger`, `cane_toad_bufotoxin_dot`, `cane_toad_toxic_skin_arm`, `cane_toad_toxic_skin_dot` |
| R4E.1 | `battle_bog_beaver_timeline_check.gd` | `beaver_chomp`, `beaver_gnaw_contact` |
| R4E.1 | `battle_bog_bog_turtle_timeline_check.gd` | `bog_turtle_headbutt`, `bog_turtle_self_recoil`, `bog_turtle_basking_followup` |
| R4E.2 | `battle_bog_water_shrew_timeline_check.gd` | `water_shrew_bite`, `water_shrew_empowered_bite` |
| R4E.2 | `battle_bog_mink_timeline_check.gd` | `mink_bite`, `mink_choke_impact`, `mink_choke_channel`, `mink_choke_execute` |
| R4E.3 | `battle_bog_chorus_frog_timeline_check.gd` | `chorus_frog_tongue` |
| R4E.3 | `battle_bog_great_blue_heron_timeline_check.gd` | `great_blue_heron_spear` |
| R4E.4 | `battle_bog_snapping_turtle_timeline_check.gd` | `snapping_turtle_bite`, `snapping_turtle_grab_arm`, `snapping_turtle_grab_bite` |
| R4E.4 | `battle_bog_wolf_spider_timeline_check.gd` | `wolf_spider_bite_lunge`, `wolf_spider_burrow_charge`, `wolf_spider_latch` |
| R4E.4 | `battle_bog_spiderling_timeline_check.gd` | `spiderling_bite` |
| R4F.0 | `battle_bog_otter_timeline_check.gd` | `otter_bite`, `otter_latch`, `otter_tail_whip` |
| R4F.2 | `battle_bog_leech_timeline_check.gd` | `leech_primary_release`, `leech_primary_projectile`, `leech_attachment_dot`, `leech_sensory_crypt_release`, `leech_sensory_crypt_dot` |
| R4F.1 | `battle_bog_otter_timeline_check.gd` | `otter_gang_up_arm`, `otter_gang_up_cohort` |

Modifier/follow-up records such as Swallow, Mobbing, Gnaw, self-recoil and
basking remain in the validator even when they do not independently damage an
enemy. They prove consumption, attribution and active-resolution coupling and
may not be silently dropped as "non-damaging."

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

Continuous damage preserves current fixed-step integration unless a row names
an interval. Its contract records:

```text
cadence_mode       fixed_step | interval
interval_sec       1/60 for fixed_step, otherwise the written interval
first_application  on contact/release or after one full interval
boundary_order     phase/contact transition before child damage at same time
final_step         clamp elapsed contribution to remaining lifetime
stacking_key       current code key; independent when the row says stack
reapplication      refresh, replace or independent exactly as written
```

Controller switching never retires an already spawned field or child and never
releases a held latch by itself. Input suppression preserves effective-held
state. The Mosquito field and Wolf Spider latch references to switch/suppression
are therefore interpreted as lifecycle-cleanup bugs to correct during their
named migrations, not deliberate kit exceptions.

### Discrete, Dash And Aerial Actions

| Action | Prototype Timing | Acceptance, Geometry And Outcome |
| --- | --- | --- |
| Bullfrog Swallow | child of Bite active | first normal Bite contact only; target smaller and at `<=10%` HP; execute for `10x` max HP and heal 25%; inherit Bite movement/recovery; no second counter bonus |
| Bullfrog Lunge | `X 0.12/0.18/0.06/0.30/0.36`; hit `0.18` | require charge; lock heading; fixed 3 u dash; endpoint 3x2 impact hits each legal target once and knocks 1 u; no steering; 3 s recharge |
| Snapping Turtle Grab | `ARM 0.10/0.04/0.15/0.20`; empowered Bite uses roadmap timing | arm without cooldown; accepted empowered attempt consumes Grab on hit or whiff; +1.5 u reach; first latchable hit pulls to jaw and latches 1.6 s; 5 s cooldown starts on attempt |
| Kingfisher Air Peck | `D 0.32/0.10/0.50/0.40`; hit `0.30` | lock heading and airborne variant; local 1 u beak; free ground-anchor travel; air plane; open 0.7 s low window at active |
| Kingfisher Plunge | `X 0.25/0.20/0.12/0.65/0.50`; hit `0.39` | require airborne plus 2 u accumulated travel; lock target within 2 u; no steering; endpoint 1 u beak contact; consume charge once; 0.7 s low window on hit or miss |
| Owl Swoop | `X 0.25/0.20/0.12/0.65/0.50`; hit `0.39` | accept AIRBORNE or PERCHED; perched acceptance leaves the perch and uses the same Swoop; reject NORMAL and BURROWED; lock point within 6 u; no steering; endpoint contact can hit ground targets; break stealth on acceptance; 0.7 s low window then braking recovery |
| Otter Tail Whip | `D 0.30/0.10/0.55/0.40`; hit `0.33` | commit alternating back-to-front left/right arc; each target once; 1.5 u outward knockback; 60% movement in startup/recovery; 5 s cooldown |
| Crayfish Caridoid Escape | `D 0.12/0.06/0.28/0.30`; hit `0.168`; then 0.22 s recovery displacement | lock facing; one front 1 u smack during active; fixed 3 u backward motion begins at recovery entry and cannot change the resolved hit shape; no steering; 3 charges with 5 s recharge |
| Mink Choke impact | `X 0.24/0.10/0.06/3.00/0.50`; landed recovery `1.80` after latch | lock heading; fixed 2 u dash; 1.5-body-radius corridor; first latchable contact takes 20, ends the dash action and starts kit-owned `mink_choke_channel`; miss serves full 3 s; landed recovery starts after latch end |
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
| Mink Choke execute | 10 s latch countdown; active `0.06`; break exit `0.35`; success recovery `0.60` | generic Creature latch owns only grip/lifecycle; `mink.gd::_tick_choke_channel` owns countdown/execute; visible 10/5/3/1 s checkpoints; death only at zero; grip break cancels; 10 s cooldown after release |

### Spawned Children And Fields

| Action | Exact Child Contract | Targeting And Ownership |
| --- | --- | --- |
| Duckling Peck | `D 0.18/0.05/0.25/0.20`, hit `0.15`; interval 0.8 s | Duckling-owned timeline; nearest legal target locked at startup; stationary until recovery; invalid target whiffs; retire on death/owner retirement |
| Spiderling Bite | `D 0.14/0.05/0.25/0.20`, hit `0.15`; interval 0.7 s; lifetime 12 s | Spiderling-owned timeline/attribution; nearest legal target locked; invalid target whiffs; retire on owner death or match end |
| Leech Projectile attachment | flight `<=0.747 s`; attach 3 s at 10 DPS | parent `P 0.30/0.06/0.20/0.30`; heading locks; spend body-leech at release; projectile owns flight; target attachment owns DOT/reveal |
| Leech Sensory Crypt | `P 0.40/0.06/0.35/0.45`; attach 6 s at 10 DPS | require water and same-water legal target; snapshot targets at release; spend one body-leech per attach; reject no-target without cost; 14 s cooldown on release |
| Mosquito primary field | flight `<=0.747 s`; field 3 s, radius 3 u, 15 DPS | field on collision/max range; overlapping fields damage independently, 5% slow does not stack; survives controller switch and source death; retire on owner respawn/species replacement/match end |
| Mosquito Breeding Grounds | `ARM 0.20/0.04/0.20/0.30`; active 6 s | first field on first moving active tick, then every 0.35 s while moving; fields last 3 s; cap 14 trail/20 total and retire oldest; 10 s cooldown after trail |
| Mosquito Unswattable | persistent overlap integration, 10 DPS | always-visible envelope; continuous per-target damage; enter/exit cues, no tick spam; immediate re-entry; blood 1:1 and hunger 0.5:1 from actual damage |
| Wolf Spider Bite latch | child of Lunge contact; maximum 3 s | first latchable target; effectively held Primary refreshes grip to 0.45 s; suppression is still held; 45% slow; no latch damage; release on intentional button-up, invalid target or timeout |
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

1. `PROVEN` under its timing class; or
2. `PROVEN_NON_DAMAGING` after code, roster data and modifier coupling tests
   agree.
