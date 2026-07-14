const SUPPORTED_DICE = new Set([4, 6, 8, 10, 12, 20, 100]);
export function parseDiceExpression(rawExpression) {
  const expression = String(rawExpression).toLowerCase().replaceAll(' ', '');
  const match = expression.match(/^(\d*)d(4|6|8|10|12|20|100)([+-]\d+)?$/);
  if (!match) throw new Error('Use a simple expression like d20, 1d8 + 2 or 2d6 - 1.');
  const diceCount = match[1] ? Number(match[1]) : 1;
  const dieSize = Number(match[2]);
  const modifier = match[3] ? Number(match[3]) : 0;
  if (!SUPPORTED_DICE.has(dieSize)) throw new Error('Unsupported die.');
  if (diceCount < 1 || diceCount > 20) throw new Error('Roll between 1 and 20 dice at a time.');
  return { diceCount, dieSize, modifier, displayText: `${diceCount === 1 ? '' : diceCount}d${dieSize}${modifier ? ` ${modifier > 0 ? '+' : '-'} ${Math.abs(modifier)}` : ''}` };
}
export function roll(expression, { advantage = false, disadvantage = false } = {}) {
  const diceExpression = typeof expression === 'string' ? parseDiceExpression(expression) : expression;
  const hasD20AdvantageState = diceExpression.dieSize === 20 && diceExpression.diceCount === 1 && advantage !== disadvantage;
  const rollCount = hasD20AdvantageState ? 2 : diceExpression.diceCount;
  const dice = Array.from({ length: rollCount }, () => 1 + Math.floor(Math.random() * diceExpression.dieSize));
  const keptDice = hasD20AdvantageState ? [advantage ? Math.max(...dice) : Math.min(...dice)] : dice;
  const total = keptDice.reduce((sum, value) => sum + value, 0) + diceExpression.modifier;
  return { expression: diceExpression.displayText, dice, keptDice, modifier: diceExpression.modifier, total, natural20: diceExpression.dieSize === 20 && keptDice[0] === 20, natural1: diceExpression.dieSize === 20 && keptDice[0] === 1 };
}
