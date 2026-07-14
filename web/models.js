export const ATTRIBUTE_TYPES = ['might', 'agility', 'endurance', 'mind', 'instinct', 'presence'];
export const SKILL_TYPES = {
  athletics: 'might', stealth: 'agility', thievery: 'agility', survival: 'instinct',
  awareness: 'instinct', lore: 'mind', arcana: 'mind', persuasion: 'presence',
  intimidation: 'presence', endurance: 'endurance'
};
export const SKILL_DIFFICULTIES = { simple: 8, standard: 12, testing: 13, challenging: 14, difficult: 15, severe: 18, heroic: 22, mythic: 26 };
export const GAME_CONSTANTS = { maxHeroSlots: 4, versionOneLevelCap: 5, versionOneAttributeCap: 20, maxEnemiesInCombat: 3, maxStaminaDraughtUsesPerAdventure: 2 };
export function attributeModifier(score) { return Math.floor((score - 10) / 2); }
export function createAttributes(values = {}) { return Object.fromEntries(ATTRIBUTE_TYPES.map(type => [type, values[type] ?? 10])); }
export function applyBonuses(attributes, bonuses) { const next = { ...attributes }; for (const [key, value] of Object.entries(bonuses)) next[key] = (next[key] ?? 10) + value; return next; }
export function uuid() { return crypto?.randomUUID?.() ?? `id-${Date.now()}-${Math.random().toString(16).slice(2)}`; }
export class Hero {
  constructor({ name, origin, path, subpath, attributes, trainedSkills, abilities, inventory, maxHealth, maxFocus = 0, maxStamina = 0, defence }) {
    this.id = uuid(); this.name = name; this.origin = origin; this.path = path; this.subpath = subpath;
    this.level = 1; this.xp = 0; this.gold = 10; this.attributes = attributes; this.trainedSkills = trainedSkills;
    this.abilities = abilities; this.inventory = inventory; this.maxHealth = maxHealth; this.currentHealth = maxHealth;
    this.maxFocus = maxFocus; this.currentFocus = maxFocus; this.maxStamina = maxStamina; this.currentStamina = maxStamina;
    this.defence = defence; this.currentLocation = 'Greywick'; this.completedAdventureIDs = new Set(); this.adventureState = null; this.combatState = null;
  }
}
