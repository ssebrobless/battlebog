# Battle Bog HUD, Information And Switching Constitution

Status: research-derived ownership rules

Compiled: 2026-07-27

## Information Shape

```text
DIRECT CONTROL
      |
      v
one active creature ------> quiet combat HUD
      |
      +--> released allies -> compact autonomous intent
      +--> team visibility -> exact / revealed / uncertain / stale
      +--> public objective -> world + minimap + short broadcast
                                      |
                                      v
                         optional expanded tactical view
```

## HUD Ownership

### Always On

- controlled health and hunger;
- immediately usable abilities;
- stocks;
- compact minimap;
- critical warnings;
- compact state for the other two player-owned creatures.

### Contextual

- deposit and breeding prompts;
- ally intent changes;
- boss wake, contest, claim and steal;
- altitude/submergence exceptions;
- revealed, heard, last-known and suspected transitions;
- urgent released-creature needs.

### Expanded

- full team stocks;
- boss meters and objective timing;
- route and visibility history;
- ally assignments and intent detail;
- strategic map information.

The expanded view appears on demand. It does not compete with active combat.

## Visibility Ownership

| State | Allowed Presentation |
| --- | --- |
| Direct sight | exact body and minimap position |
| Revealed | exact presentation for the reveal duration |
| Heard | uncertain directional pulse with precision decreasing by distance |
| Last known | fading stationary ghost at the last legal position |
| Suspected | coarse area or environmental disturbance only |
| Hidden | no exact body, icon or AI target truth |

Public boss state is globally readable. Enemy approach and claim actors still
obey normal visibility.

Bots and inactive allies consume the same sanitized team-information snapshot
available to the player.

## Ally Intent

Released creatures show only:

`verb + destination/objective + urgency`

Examples:

- `FORAGE | Zone B`
- `RETURN | hungry`
- `DEPOSIT | ready`
- `DEFEND | habitat`
- `CONTEST | blue boss`

Do not expose:

- hidden target identity;
- full path;
- utility scores;
- private threat calculations;
- exact enemy positions learned outside legal visibility.

Short assignment leases prevent intent flicker. Emergency retreat, starvation
and deposit safety may interrupt an assignment immediately.

## Switching Contract

Switching is atomic:

1. input transfers to the selected living creature;
2. conflicting AI input is cleared;
3. the released creature resumes autonomous evaluation immediately;
4. actor health, hunger, cooldowns, stocks, position and commitment remain on
   that actor;
5. simulation does not pause;
6. neither creature is repositioned.

Presentation:

- `150-250 ms` camera ease;
- portrait highlight handoff;
- world truth-ring handoff;
- concise new-control confirmation.

Do not import Dragon Age's pause-and-queue combat or player-authored tactics
programming surface.

## Directional Alerts

Battle Bog translates Apex and SUPERVIVE principles into wetland information:

- splash pulse;
- ripple pulse;
- rustle;
- wingbeat;
- disturbed reeds;
- off-screen impact.

Each event can produce:

- directional audio;
- short screen-edge cue;
- uncertain minimap pulse.

Threat priority may lower self-generated ambience, but it must not delete
important opponent cues or turn sound into exact GPS.

## Reference Anchors

- [Dota player POV](https://www.youtube.com/watch?v=Oo5t5nBpneo):
  compact persistent HUD, fog minimap and optional depth.
- [Dota HUD documentation](https://www.dota2.com/700/hud):
  scalable minimap and on-demand teammate/unit detail.
- [Apex normal match](https://www.youtube.com/watch?v=6300yq0gKNs):
  contextual pings and perimeter-weighted alerts.
- [Apex audio update](https://www.ea.com/games/apex-legends/apex-legends/news/showdown-audio-update):
  threat-prioritized mix and critical-cue space.
- [EA accessibility ping patent pledge](https://www.ea.com/en-gb/commitments/positive-play/accessibility-patent-pledge):
  contextual visual/audio communication through one mapped action.
- [Dragon Age tactics footage](https://www.youtube.com/watch?v=B8Oul5CAo-o):
  direct-control transfer and configurable autonomy.
- [Garden of Terror developer insight](https://news.blizzard.com/en-us/article/14806627/developer-insights-garden-of-terror):
  lighting, minimap and ecology as objective transition.

The Garden of Terror footage is a legacy implementation and supplies
presentation evidence only.

## Do Not Import

- Dota inventory, shop, courier and item-status density;
- Apex deathboxes, loot feed, battle-royale ring or indicator geometry;
- Dragon Age pause/queue or tactics programming;
- Heroes of the Storm's severe darkness or exact global neutral locations;
- SUPERVIVE revive, inventory or battle-royale systems;
- persistent AI paths or target lines that disclose hidden information.

## First Validation Slice

Prove:

1. three switchable creatures;
2. compact always-visible intent for the two released allies;
3. immediate autonomous resumption after switching;
4. simple and expanded HUD ownership;
5. direct sight, uncertain sound and decaying last-known information;
6. the same sanitized information used by bots and players.

