export const ORIGINS = [
  { id: 'hearthborn', name: 'Hearthborn', bonuses: { might: 1, agility: 1, endurance: 1, mind: 1, instinct: 1, presence: 1 }, feature: 'Second Chance', summary: 'Once per adventure, reroll a failed skill check.' },
  { id: 'moonElf', name: 'Moon Elf', bonuses: { agility: 2, mind: 1 }, feature: 'Night Sight', summary: 'Advantage on Awareness checks in darkness, caves, ruins or moonlit areas.' },
  { id: 'stonekin', name: 'Stonekin', bonuses: { endurance: 2, might: 1 }, feature: 'Stonehide', summary: 'Once per combat, reduce incoming physical damage by 1.' },
  { id: 'ironblood', name: 'Ironblood', bonuses: { might: 2, endurance: 1 }, feature: 'Heavy Hand', summary: 'Once per combat, after hitting with a melee attack, deal +1 physical damage.' },
  { id: 'smallfolk', name: 'Smallfolk', bonuses: { agility: 2, presence: 1 }, feature: 'Nimble Hands', summary: 'Once per room, gain +2 to a Stealth or Thievery check.' },
  { id: 'starborn', name: 'Starborn', bonuses: { mind: 2, instinct: 1 }, feature: 'Arcane Memory', summary: 'Once per adventure, gain +2 to a Lore or Arcana check.' }
];
export const PATHS = [
  { id: 'bladeguard', name: 'Bladeguard', role: 'Physical melee defender', hp: 12, hpPerLevel: 7, focus: 0, trainedSkills: ['athletics', 'intimidation'], ability: 'Guarded Strike', attackAttribute: 'might', damage: '1d8 + 2', gear: ['Iron Sword', 'Wooden Shield', 'Chain Vest', 'Minor Healing Draught', 'Minor Healing Draught'] },
  { id: 'shadowstep', name: 'Shadowstep', role: 'Rogue/precision damage', hp: 9, hpPerLevel: 5, focus: 0, trainedSkills: ['stealth', 'thievery'], ability: 'Opening Strike', attackAttribute: 'agility', damage: '1d6 + 3', gear: ['Twin Daggers', 'Leather Vest', "Thief's Tools", 'Minor Healing Draught', 'Minor Healing Draught'] },
  { id: 'wildwarden', name: 'Wildwarden', role: 'Ranged survivalist', hp: 10, hpPerLevel: 6, focus: 0, trainedSkills: ['survival', 'awareness'], ability: 'Marked Shot', attackAttribute: 'agility', damage: '1d8 + 1', gear: ['Shortbow', 'Hunting Knife', 'Leather Vest', 'Minor Healing Draught', 'Minor Healing Draught'] },
  { id: 'embermage', name: 'Embermage', role: 'Spellcaster', hp: 7, hpPerLevel: 4, focus: 2, focusAttribute: 'mind', trainedSkills: ['arcana', 'lore'], ability: 'Ember Bolt', attackAttribute: 'mind', damage: '1d10 + 2', gear: ['Rune Staff', 'Cloth Robe', 'Focus Stone', 'Minor Healing Draught', 'Minor Healing Draught'] },
  { id: 'oathkeeper', name: 'Oathkeeper', role: 'Hybrid warrior/support', hp: 11, hpPerLevel: 6, focus: 1, focusAttribute: 'presence', trainedSkills: ['endurance', 'persuasion'], ability: 'Vowblade Strike', attackAttribute: 'presence', damage: '1d7 + 2', gear: ['Vowblade', 'Wooden Shield', 'Chain Vest', 'Minor Healing Draught', 'Minor Healing Draught'] }
];
export const ENEMIES = [
  { id: 'cave-rat', name: 'Cave Rat', level: 1, maxHealth: 5, defence: 10, initiativeBonus: 2, attackBonus: 3, damage: '1d4', xp: 25, gold: [1, 3], summary: 'A hungry cave rat with sharp teeth and little fear.' },
  { id: 'tunnel-skitter', name: 'Tunnel Skitter', level: 1, maxHealth: 6, defence: 11, initiativeBonus: 3, attackBonus: 3, damage: '1d4', xp: 25, gold: [1, 4], summary: 'A pale tunnel crawler whose bite can sour the blood.' },
  { id: 'greywick-raider', name: 'Greywick Raider', level: 1, maxHealth: 12, defence: 12, initiativeBonus: 1, attackBonus: 4, damage: '1d6 + 1', xp: 50, gold: [4, 10], summary: 'A rough blade-for-hire preying on travellers near the mine road.' },
  { id: 'raider-lookout', name: 'Raider Lookout', level: 1, maxHealth: 10, defence: 12, initiativeBonus: 2, attackBonus: 4, damage: '1d6', xp: 50, gold: [4, 12], summary: 'A wary raider posted to warn the camp and loose the first shot.' },
  { id: 'bristleback-brute', name: 'Bristleback Brute', level: 2, maxHealth: 30, defence: 13, initiativeBonus: 0, attackBonus: 4, damage: '1d8 + 2', xp: 200, gold: [25, 60], summary: 'A hulking brute in scavenged mail with a bone-rattling charge.' }
];
export const ADVENTURES = [{
  id: 'the-hollow-mine', title: 'The Hollow Mine', recommendedLevel: 1, difficulty: 'Beginner', theme: 'Raiders, rats and broken mine tunnels', hook: "Greywick's old mine road has gone quiet, and smoke curls from the lower shaft.",
  rooms: [
    { id: 'mine-road', title: 'Old Mine Road', type: 'choice', description: 'Broken cart tracks vanish into brambles below the Greywick ridge.', choices: [{ text: 'Follow the open road', nextRoomID: 'road-ambush' }, { text: 'Scout the brambles', skill: 'awareness', target: 12, nextRoomID: 'lower-shaft' }] },
    { id: 'road-ambush', title: 'Road Ambush', type: 'combat', description: 'Raiders spring from behind a cracked milestone.', enemyIDs: ['greywick-raider'], nextRoomID: 'lower-shaft' },
    { id: 'lower-shaft', title: 'Lower Shaft', type: 'combat', description: 'Chittering echoes from timber supports ahead.', enemyIDs: ['tunnel-skitter', 'cave-rat'], nextRoomID: 'storehouse' },
    { id: 'storehouse', title: 'Flooded Storehouse', type: 'skillCheck', description: 'A rusted strongbox rests just above black water.', skill: 'thievery', target: 13, nextRoomID: 'bristleback-den' },
    { id: 'bristleback-den', title: 'Bristleback Den', type: 'boss', description: 'The Bristleback Brute rises in scavenged mail.', enemyIDs: ['bristleback-brute'], nextRoomID: null }
  ]
}];
export const byID = list => Object.fromEntries(list.map(item => [item.id, item]));
