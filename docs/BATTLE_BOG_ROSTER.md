# Battle Bog Roster Map

This roster translates the current creature notes into a buildable design map.
Numbers are intentionally preserved from the notes even when they need tuning.

```text
╔════════════╦══════════════════════════════════════════════════════════════╗
║ Family     ║ Playable creatures                                           ║
╠════════════╬══════════════════════════════════════════════════════════════╣
║ Amphibian  ║ Bullfrog · Chorus Frog · Newt · Cane Toad                    ║
║ Reptile    ║ Snapping Turtle · Water Snake · Bog Turtle · Alligator       ║
║ Bird       ║ Owl · Great Blue Heron · Kingfisher · Duck                   ║
║ Mammal     ║ Water Shrew · Beaver · Otter · Mink                          ║
║ Crawly     ║ Leech · Crayfish · Mosquito Swarm · Wolf Spider · Firefly    ║
╚════════════╩══════════════════════════════════════════════════════════════╝
```

## Combat Jobs

```text
Frontline / anchor     Snapping Turtle · Alligator · Beaver · Bullfrog
Skirmish assassin      Mink · Water Shrew · Kingfisher · Wolf Spider
Control support        Chorus Frog · Newt · Cane Toad · Firefly
Sustain support        Bog Turtle · Firefly · Duck
Summoner / swarm       Duck · Otter · Leech · Wolf Spider · Mosquito Swarm
Terrain specialist     Beaver · Owl · Heron · Water Snake · Crayfish
```

## Amphibians

| Creature | Identity | Primary | Q | E | Passive |
| --- | --- | --- | --- | --- | --- |
| Bullfrog | Ambush bruiser/executor | Directional bite, 21 dmg, 2x2 range | Leap 4 units moving, 10 units from camouflage, 5s cd | Lunge 3 units, 15 dmg, knockback, 3 charges | Swallow execute under 10% lower-HP target; Camouflage after 3s still |
| Chorus Frog | Tempo support | Tongue poke, 15 dmg, 1x3 range | Comb Call: allies in 6 radius gain 10% move/attack speed 4s | Cree: enemies in 8 radius deal 10% less and move 10% slower 6s | None |
| Newt | Punish tank/disruptor | Alternating tail swing, 19 dmg | Unken Reflex: 3s invulnerable fear pulse | Toxic Secretion: reflect 60% physical damage over 3s during 5s window | Rib Exudation burst/reflect at low HP; Caudal Autotomy avoids death |
| Cane Toad | Poison zone bruiser | Poison stream, 20 DPS, 100 ammo | Toxic Skin: attackers receive stackable poison | Thanatosis: immobile 5s, doubled primary range, stronger Toxic Skin | Bufotoxin poisons physical attackers |

## Reptiles

| Creature | Identity | Primary | Q | E | Passive |
| --- | --- | --- | --- | --- | --- |
| Snapping Turtle | Slow hard engage tank | 0.7s windup bite, 100 dmg | Grab: next bite reaches farther and pulls | Lingual Lure: 1.5 radius stun while mouth lure is active | Protective Shell: 15% damage reduction |
| Water Snake | Latch duelist | Bite/bleed latch, 1% target max HP per sec | Musking: 3 radius fear, not while latched | Slithering Retreat: 20% speed 5s | Ingestion execute lower-HP latched target under 15% |
| Bog Turtle | Mounted healer/enchanter | 2 dmg headbutt, mounted hit heals ally and buffs damage | Endozoochory: flower heal projectile, 2 charges | Umbrella Effect: mounted burst heal from missing HP | Basking: ride higher-HP ally with 95% shared-damage reduction |
| Alligator | Heavy ambush grappler | Burst bite latch, drag 3s | Death Roll: water-only 30 DPS roll for 5s | Ambush: stealth with 30% slow, revealed by hit/action | Devour: kills heal 50% victim max HP |

## Birds

| Creature | Identity | Primary | Q | E | Passive |
| --- | --- | --- | --- | --- | --- |
| Owl | Stealth aerial assassin/scout | Ground peck 20; air/perch swoop 50 | Silent Flight: flying invis/no noise 10s | Auditory Mapping: reveal 12 radius for 3s | Perch: sit on terrain, safer from ground attacks, +50% vision |
| Great Blue Heron | Long-range grounded striker | Spear beak, 55 dmg, 3x1 range | Powder Puff: cleanse and stun immunity 2s | Flushing: 2 unit dash into flight | Wading: grounded water traversal and water attacks |
| Kingfisher | High-speed precision diver | Peck 25 ground/35 flying, +30% after moving 2 units | Hover: idle airborne state 4s | Nest Chamber: 7s underground immunity | Plunge: can attack water targets |
| Duck | Pet sustain skirmisher | Wing/wing/bite chain, 10/10/15 dmg | Nesting: hatch up to 4 ducklings | Mobbing: next hit buffs ducklings with DR/speed/AS | Paddling: duck and ducklings safely traverse water |

## Mammals

| Creature | Identity | Primary | Q | E | Passive |
| --- | --- | --- | --- | --- | --- |
| Water Shrew | Tiny speed debuffer | Bite, 8 dmg, stacking move/damage/vulnerability debuff | Water Walk: 35% speed and water-running while moving | Proenkephalin A: next bite roots/silences 1s, 2 charges | Aquatic Locomotion |
| Beaver | Builder frontline support | Chomp, 50 dmg | Tail Slap: allies in 8 radius gain 15% DR; repairs dams | Dam: place up to 3 cover walls, rotate with R | Gnawing: bite trees to heal 5% |
| Otter | Three-body latch pack | Bite latch, 25 dmg | Tail Whip: multi-hit knockback arc | Gang Up: living pack visibly pounces, latches and stacks 25% slow each | Pack of 3; individual 300 HP bodies, shared stock, control swaps to an unlatched otter |
| Mink | Anti-tank assassin | Bite, 20 dmg | Choke: dash latch, 10s suffocation threat | Scent Marking: ally DR/damage buff, enemy heal reduction | Fearless: better into higher-HP targets |

## Crawlies

| Creature | Identity | Primary | Q | E | Passive |
| --- | --- | --- | --- | --- | --- |
| Leech | Resource swarm artillery | Fire sticky leech projectile, 10 DPS for 3s | Copulation: idle spawn 1 leech/sec up to cap | Sensory Crypt: water-only multi-target latch/reveal | Cluster: 20 leeches are HP and ammo |
| Crayfish | Defensive duelist | Alternating claw pinch, 20 dmg | Caridoid Escape: backward dash, 3 charges | Meral Display: larger, slower turning, 30% DR stance | Molting: scaling DR every 30s alive |
| Mosquito Swarm | Flying AOE harasser | Projectile becomes 3 radius AOE, 15 DPS, 5% slow | Breeding Grounds: 6s moving AOE trail, lingers 3s | Deposit: transfer blood meter to ally as burst heal (50 at full) | Unswattable: pass through units/objects, 9% ranged miss chance, contact blood drain fills hunger + blood meter |
| Wolf Spider | Burrow ambusher | 2 unit lunge bite, optional latch/slow | Silk-lined Burrows: hidden burrow network and charge | Epigamic Carrying: 12 spiderlings hatch as trap/pets | Simple Eyes: 20 unit facing vision day/night |
| Firefly | Aura healer/debuff trapper | Reveal projectile, 3 dmg | Flash-Train: 7 radius stronger glow/heal and ally speed | Glowworms: 3 charge slowing vulnerability mines | Bioluminescence: 4 radius 20 HP/sec ally heal |

## Stat Snapshot

| Creature | HP | Speed | Regen | Special movement |
| --- | ---: | ---: | ---: | --- |
| Bullfrog | 850 | 1.2 | 20/s | Leap over obstacles |
| Chorus Frog | 400 | 2.0 | 15/s | Land walker |
| Newt | 200 | 1.3 | 45/s | Semi-aquatic, 12s swim |
| Cane Toad | 550 | 1.5 | 25/s | Land walker |
| Snapping Turtle | 1200 | 0.95 | 30/s | Semi-aquatic, 20s swim |
| Water Snake | 950 | 1.6 | 40/s | Semi-aquatic, 22s swim |
| Bog Turtle | 150 | 1.0 | 10/s | Mounted basking |
| Alligator | 1500 | 1.3 | 20/s | Semi-aquatic, 20s swim |
| Owl | 200 | 0.9 / 2.8 | 9/s | Flight 12s, perch |
| Great Blue Heron | 240 | 0.95 / 2.9 | 10/s | Flight 20s, wading |
| Kingfisher | 160 | 1.1 / 3.0 | 5/s | Flight 8s, hover/burrow |
| Duck | 200 | 0.97 / 1.0 swim | 8/s | Flight 15s, ducklings swim |
| Water Shrew | 95 | 1.6 | 5/s | Semi-aquatic, 8s swim |
| Beaver | 875 | 1.0 | 15/s | Semi-aquatic, 12s swim |
| Otter | 300 each | 1.5 | 18/s | Semi-aquatic, 13s swim, pack of 3 |
| Mink | 300 | 1.8 | 20/s | Land walker |
| Leech | 20 leeches | 0.7 / 1.8 swim | 1 leech/4s | Unlimited swim |
| Crayfish | 250 | 1.2 | 30/s | Ground currently; aquatic tuning TBD |
| Mosquito Swarm | 110 | 1.7 flying | 20/s | Unlimited flight |
| Wolf Spider | 170 | 1.5 | 15/s | Burrows |
| Firefly | 30 | 0.88 flying | 1 HP/4s | Unlimited flight |

## Resolved Gaps (2026-07-03)

All former design gaps are resolved; values live in `data/battle_bog_roster.json`
and `docs/BATTLE_BOG_DECISIONS.md`:

| Gap | Resolution |
| --- | --- |
| Mosquito Q/E | Breeding Grounds (trail AOE) and Deposit (blood-meter ally heal). |
| Alligator attack speed | 1 bite / 1.8s. |
| Great Blue Heron attack speed | 1 strike / 1.4s. |
| Sensory Crypt cooldown | 14s; costs 1 body-leech per target hit. |
| Diet tags | Per-creature `diet` field; kill-heal for carnivores/omnivores. Beaver (herbivore) and Firefly (nectarivore) excluded. |
| Habitat stat boosts | Per-family buff table (see decisions doc #8). |
| Reproduction rates/caps | Uniform 45s breed timer; cap 6 stacks/team, max 3 per family. |
| Model footprint | Per-creature `footprint` field (circles; capsules for Water Snake and Alligator). |
