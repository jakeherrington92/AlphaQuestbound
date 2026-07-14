# Quick Action Audit

Developer-facing audit for Version 1. This file is not shown in the player UI.

| Path / Subpath | Ability | Cost | Cooldown / Limit | Target | Effect | Status | Overlap note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Shared physical | Catch Breath | None | 4 turns | Self | Restore 1 Stamina | Implemented | Unique resource recovery |
| Shadowstep | Slip Away | None | None | Self | Reposition / escape pressure | Planning only | Effect needs a concrete combat rule |
| Oathkeeper | Sacred Challenge | None | None | Enemy | Draw enemy attention | Planning only | Future party-facing control |
| Oathkeeper | Mend the Wounded | 1 Focus | None | Self | Heal 1d6 + Presence | Implemented | Distinct resource healing |
| Iron Vanguard | Shield Brace | None | 3 turns | Self | Guarded; reduce next physical hit by 1 | Implemented | Strong defensive identity |
| Iron Vanguard | Cracking Bash | None | 3 turns | Enemy | Exposed | Implemented | Overlaps other Exposed techniques |
| Storm Duelist | Elemental Flask | None | 3 turns; 3/adventure | Self | Next weapon hit gains random +1d4 elemental damage | Implemented | Replaces overlapping Duelist's Tempo |
| Storm Duelist | Tempest Feint | None | 3 turns | Enemy | Weakened | Implemented | Distinct offensive control |
| Storm Duelist | Tempest Step | None | 2 turns | Self | Next melee attack +1 hit and damage | Implemented | Remains the accuracy/damage setup |
| Nightblade | Veil Step | None | 3 turns | Self | +1 Defence and next attack +1 | Implemented | Hybrid offence/defence |
| Nightblade | Marked in Shadow | None | 3 turns | Enemy | Exposed; bonus if already Exposed | Implemented | Similar condition, unique repeat payoff |
| Trickhand | Loaded Trick | None | 3 turns | Self | Small next item/attack bonus | Implemented | Broad wording needs later item-specific refinement |
| Trickhand | Pocket Sand | None | 3 turns | Enemy | -1 next enemy attack | Implemented | Distinct disruption |
| Beastcaller | Pack Instinct | None | 3 turns | Self | +1 Defence | Implemented | Simple but fits defensive pack identity |
| Beastcaller | Hamstring Call | None | 3 turns | Enemy | Slowed | Implemented | Distinct control |
| Deepwood Archer | Steady Aim | None | 3 turns | Self | Next ranged attack +1 hit and damage | Implemented | Similar to Tempest Step, but weapon-role specific |
| Deepwood Archer | Pinning Threat | None | 3 turns | Enemy | Marked, or Exposed if already Marked | Implemented | Distinct mark escalation |
| Flamecaller | Kindled Focus | None | 3 turns | Self | Restore Focus or empower next fire spell | Implemented | Complements Cinder Mark rather than duplicating it |
| Flamecaller | Cinder Veil | None | 3 turns | Enemy | Exposed; Weakened if Burning | Implemented | Exposed overlap with fire synergy |
| Flamecaller | Cinder Mark | 1 Focus | 3 turns | Enemy | Next fire spell gains +1d6 | Implemented | Targeted burst setup |
| Voidweaver | Void Ward | None | 3 turns | Self | Reduce next damage by 1d4 | Implemented | Unique ward |
| Voidweaver | Fracture Pattern | None | 3 turns | Enemy | Exposed | Implemented | Exposed-only effect overlaps Cracking Bash |
| Voidweaver | Arcane / Void Ward | 1 Focus | 3 turns | Self | Reduce next damage by 1d6 | Planning in availability registry | Stronger ward progression |
| Dawnshield | Dawn's Grace | None | 3 turns | Self | Restore 1d4 HP | Implemented | Unique free minor healing |
| Dawnshield | Mercy's Rebuke | None | 3 turns | Enemy | Weakened | Implemented | Similar condition to Tempest Feint |
| Dawnshield | Dawnward | 1 Focus | 3 turns | Self | Guarded and damage resistance | Planning in availability registry | Strong defensive progression |
| Judgement Flame | Judgement Spark | None | 3 turns | Self | Next attack +1 oathfire | Implemented | Similar next-hit structure, distinct damage identity |
| Judgement Flame | Brand of Doubt | None | 3 turns | Enemy | Marked and -1 next attack | Implemented | Distinct combined control |
| Judgement Flame | Brand of Judgement | 1 Focus | 3 turns | Enemy | Next melee hit gains +1d6 oathfire | Planning in availability registry | Stronger targeted burst setup |

## Review Flags

- Fracture Pattern and Cracking Bash are the closest remaining direct overlap.
- Steady Aim and Tempest Step share a template but apply to different combat roles.
- Loaded Trick needs more explicit item hooks in a later combat pass.
- Cinder Mark and Kindled Focus intentionally coexist to support Flamecaller's setup-and-burst loop.

## Embermage Direction

Version 1:

- Flamecaller: Fire affinity; burst, Burning, AoE and direct damage with little defence.
- Voidweaver: Void/Arcane affinity; wards, gravity-flavoured disruption, hostile-magic control and enemy weakening.

Future Version 2 concepts, not implemented:

- Frostweaver: Water/Ice; lockdown, traps, debuffs and solo-capable protection.
- Stormcaller: Air/Lightning; mobility, displacement and high-voltage skirmishing.
- Stonebinder: Earth; defence, terrain shaping, knockdown and solo-capable tanking.

The internal `starweaver` ID and portrait enum cases remain unchanged for save compatibility.
