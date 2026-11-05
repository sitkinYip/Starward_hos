import { WEB_ASSIGNMENT_JSON, WEB_PLAYER_JSON } from './WebFixture';

// Valid synthetic gameplay variants of the frozen pre-entry Web fixture.
export const GAMEPLAY_TEXT_QUESTION_JSON: string = '{"id":"question0","kind":"text","title":"星辰之门",' +
  '"placeholder":"输入答案","content":[{"text":"循着星光寻找答案。","hint":"抬头看看","imageUrl":"",' +
  '"imageUrls":[],"videoUrl":""}],"options":[]}';
export const GAMEPLAY_CHOICE_QUESTION_JSON: string = '{"id":"question1","kind":"choice","title":"守门人的选择",' +
  '"placeholder":"","content":[{"text":"选择指引方向的星星。","hint":"","imageUrl":"",' +
  '"imageUrls":[],"videoUrl":""}],"options":[{"key":"A","text":"月亮","imageUrl":"","videoUrl":""},' +
  '{"key":"B","text":"北极星","imageUrl":"","videoUrl":""}]}';
export const GAMEPLAY_UNSTARTED_JSON: string = WEB_ASSIGNMENT_JSON;
export const GAMEPLAY_STARTED_JSON: string = WEB_ASSIGNMENT_JSON
  .replace('"status":"assigned"', '"status":"active"')
  .replace('"startedAt":""', '"startedAt":"2026-10-27T00:00:00.000Z"')
  .replace('"question":null', '"question":' + GAMEPLAY_TEXT_QUESTION_JSON);
export const GAMEPLAY_CHOICE_JSON: string = GAMEPLAY_STARTED_JSON
  .replace('"completedLevels":0', '"completedLevels":1')
  .replace('"currentIndex":0', '"currentIndex":1')
  .replace('"autoNext":false,"completedAt":""', '"autoNext":false,"completedAt":"2026-10-27T00:00:01.000Z"')
  .replace('"question":null', '"question":' + GAMEPLAY_CHOICE_QUESTION_JSON);
export const GAMEPLAY_COMPLETED_JSON: string = GAMEPLAY_CHOICE_JSON
  .replace('"status":"active"', '"status":"completed"')
  .replace('"completedLevels":1', '"completedLevels":2')
  .replace('"completedAt":""', '"completedAt":"2026-10-27T00:00:02.000Z"')
  .replace('"completedAt":""', '"completedAt":"2026-10-27T00:00:02.000Z"');
export const GAMEPLAY_CANCELLED_STARTED_JSON: string = GAMEPLAY_STARTED_JSON
  .replace('"status":"active"', '"status":"cancelled"')
  .replace('"question":' + GAMEPLAY_TEXT_QUESTION_JSON, '"question":null');
export const GAMEPLAY_PLAYER_JSON: string = WEB_PLAYER_JSON.replace('"mustChangePassword":true', '"mustChangePassword":false');
export const GAMEPLAY_PLAYER_50_JSON: string = GAMEPLAY_PLAYER_JSON.replace('"totalXp":0', '"totalXp":50');
export const GAMEPLAY_PLAYER_100_JSON: string = GAMEPLAY_PLAYER_JSON.replace('"totalXp":0', '"totalXp":100');

export function gameplayAnswerFixture(result: string, assignment: string = GAMEPLAY_CHOICE_JSON,
  player: string = GAMEPLAY_PLAYER_50_JSON, xpDelta: number = 50): string {
  return '{"result":' + JSON.stringify(result) + ',"xpDelta":' + xpDelta +
    ',"rewardIds":[],"effects":[],"assignment":' + assignment + ',"player":' + player + '}';
}
