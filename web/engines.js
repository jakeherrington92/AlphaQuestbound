import { ADVENTURES, ENEMIES, PATHS, byID } from './data.js';
import { Hero, applyBonuses, attributeModifier, createAttributes, SKILL_TYPES } from './models.js';
import { parseDiceExpression, roll } from './dice.js';
const enemiesByID = byID(ENEMIES); const pathsByID = byID(PATHS);
export function createHero({ name, origin, path }) {
  const attributes = applyBonuses(createAttributes(), origin.bonuses);
  const pathDef = path;
  const maxHealth = pathDef.hp + Math.max(0, attributeModifier(attributes.endurance));
  const defence = 10 + Math.max(0, attributeModifier(attributes.agility)) + (pathDef.id === 'bladeguard' || pathDef.id === 'oathkeeper' ? 2 : 0);
  const inventory = Object.fromEntries(pathDef.gear.map(item => [item, (pathDef.gear.filter(entry => entry === item).length)]));
  return new Hero({ name, origin: origin.id, path: pathDef.id, attributes, trainedSkills: pathDef.trainedSkills, abilities: [pathDef.ability], inventory, maxHealth, maxFocus: pathDef.focus, defence });
}
export const AdventureEngine = {
  plannedAdventures: ADVENTURES,
  adventure(id) { return ADVENTURES.find(adventure => adventure.id === id); },
  startAdventure(hero, adventureID) { const adventure = this.adventure(adventureID); hero.currentLocation = adventure.title; hero.adventureState = { adventureID, currentRoomID: adventure.rooms[0]?.id, completedRoomIDs: new Set(), log: [`Started ${adventure.title}.`] }; return hero; },
  currentRoom(hero) { const adventure = this.adventure(hero.adventureState?.adventureID); return adventure?.rooms.find(room => room.id === hero.adventureState.currentRoomID); },
  moveTo(hero, nextRoomID) { const state = hero.adventureState; if (state?.currentRoomID) state.completedRoomIDs.add(state.currentRoomID); state.currentRoomID = nextRoomID; return hero; },
  complete(hero) { hero.completedAdventureIDs.add(hero.adventureState.adventureID); hero.currentLocation = 'Greywick'; hero.adventureState.log.push('Adventure complete.'); return hero; }
};
export const SkillCheckHelper = {
  check(hero, skill, target) { const linkedAttribute = SKILL_TYPES[skill]; const die = roll('d20'); const attributeMod = attributeModifier(hero.attributes[linkedAttribute]); const trained = hero.trainedSkills.includes(skill); const trainingBonus = trained ? 2 : 0; const total = die.total + attributeMod + trainingBonus; return { skill, linkedAttribute, dieRoll: die.total, attributeMod, trainingBonus, target, total, trained, success: die.natural20 || (!die.natural1 && total >= target), natural20: die.natural20, natural1: die.natural1 }; }
};
export const CombatEngine = {
  startCombat(hero, room) { const enemies = room.enemyIDs.map(id => ({ ...enemiesByID[id], currentHealth: enemiesByID[id].maxHealth })); hero.combatState = { encounterID: room.id, enemies, phase: 'heroTurn', round: 1, log: ['Combat begins.'] }; return hero.combatState; },
  primaryAttack(hero) { return pathsByID[hero.path]; },
  attack(hero, enemy) { const attack = this.primaryAttack(hero); const attackRoll = roll('d20').total + attributeModifier(hero.attributes[attack.attackAttribute]) + 3; if (attackRoll < enemy.defence) return { hit: false, line: `${hero.name} misses ${enemy.name}.` }; const damageRoll = roll(parseDiceExpression(attack.damage)); const damage = Math.max(1, damageRoll.total + Math.max(0, attributeModifier(hero.attributes[attack.attackAttribute]))); enemy.currentHealth = Math.max(0, enemy.currentHealth - damage); return { hit: true, damage, line: `${attack.ability} hits ${enemy.name} for ${damage}.` }; },
  enemyAttack(hero, enemy) { const attackRoll = roll('d20').total + enemy.attackBonus; if (attackRoll < hero.defence) return `${enemy.name} misses.`; const damage = Math.max(1, roll(enemy.damage).total); hero.currentHealth = Math.max(0, hero.currentHealth - damage); return `${enemy.name} hits ${hero.name} for ${damage}.`; },
  runRound(hero) { const state = hero.combatState; const enemy = state.enemies.find(target => target.currentHealth > 0); if (!enemy) { state.phase = 'victory'; return; } state.log.push(this.attack(hero, enemy).line); if (state.enemies.every(target => target.currentHealth <= 0)) { state.phase = 'victory'; return; } for (const foe of state.enemies.filter(target => target.currentHealth > 0)) state.log.push(this.enemyAttack(hero, foe)); if (hero.currentHealth <= 0) state.phase = 'defeated'; state.round += 1; },
  collectRewards(hero) { const defeated = hero.combatState.enemies.filter(enemy => enemy.currentHealth <= 0); const reward = defeated.reduce((sum, enemy) => { sum.xp += enemy.xp; sum.gold += enemy.gold[0] + Math.floor(Math.random() * (enemy.gold[1] - enemy.gold[0] + 1)); return sum; }, { xp: 0, gold: 0 }); hero.xp += reward.xp; hero.gold += reward.gold; return reward; }
};
export function useHealingDraught(hero) { const owned = hero.inventory['Minor Healing Draught'] ?? 0; if (owned < 1) return 'No Minor Healing Draught available.'; hero.inventory['Minor Healing Draught'] = owned - 1; const healed = roll('1d8 + 2').total; hero.currentHealth = Math.min(hero.maxHealth, hero.currentHealth + healed); return `Restored ${healed} HP.`; }
