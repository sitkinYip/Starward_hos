import { GameFailure } from '../business/models';
import { GameplayAnswerResult, GameplayClue, GameplayClueContent, GameplayCompletionTarget, GameplayContentBlock,
  GameplayEffect, GameplayLevel, GameplayOption, GameplayPresentation, GameplayQuestion,
  GameplaySnapshot } from '../business/GameplayModels';
import { decodeAssignment, decodePlayer } from './DtoDecoder';

function invalid(): GameFailure {
  return new GameFailure('CONTRACT_ERROR', '服务返回了不兼容的冒险数据，请重试或联系管理员。');
}

function record(value: Object): Record<string, Object> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw invalid();
  }
  return value as Record<string, Object>;
}

function array(value: Object): Object[] {
  if (!Array.isArray(value)) {
    throw invalid();
  }
  return value as Object[];
}

function text(source: Record<string, Object>, key: string, nonempty: boolean = false): string {
  const value: Object = source[key];
  if (typeof value !== 'string' || (nonempty && value.length === 0)) {
    throw invalid();
  }
  return value as string;
}

function integer(source: Record<string, Object>, key: string): number {
  const value: Object = source[key];
  if (typeof value !== 'number' || !Number.isSafeInteger(value as number) || (value as number) < 0) {
    throw invalid();
  }
  return value as number;
}

function bool(source: Record<string, Object>, key: string): boolean {
  const value: Object = source[key];
  if (typeof value !== 'boolean') {
    throw invalid();
  }
  return value as boolean;
}

function date(source: Record<string, Object>, key: string): string {
  const value: string = text(source, key);
  if (value.length > 0 && !Number.isFinite(Date.parse(value))) {
    throw invalid();
  }
  return value;
}

function optionalText(source: Record<string, Object>, key: string): string | undefined {
  return source[key] === undefined ? undefined : text(source, key);
}

function optionalBool(source: Record<string, Object>, key: string): boolean | undefined {
  return source[key] === undefined ? undefined : bool(source, key);
}

function oneOf(value: string, options: string[]): string {
  if (options.indexOf(value) < 0) {
    throw invalid();
  }
  return value;
}

function stringArray(value: Object): string[] {
  const values: Object[] = array(value);
  const result: string[] = [];
  for (let i: number = 0; i < values.length; i++) {
    if (typeof values[i] !== 'string') {
      throw invalid();
    }
    result.push(values[i] as string);
  }
  return result;
}

function presentation(value: Object): GameplayPresentation {
  const source: Record<string, Object> = record(value);
  const result: GameplayPresentation = new GameplayPresentation();
  const backgroundMode: string | undefined = optionalText(source, 'backgroundMode');
  result.backgroundMode = backgroundMode === undefined ? undefined : oneOf(backgroundMode, ['inherit', 'custom', 'none']);
  result.hideTitle = optionalBool(source, 'hideTitle');
  const bgmMode: string | undefined = optionalText(source, 'bgmMode');
  result.bgmMode = bgmMode === undefined ? undefined : oneOf(bgmMode, ['inherit', 'custom', 'silent']);
  result.bgmUrl = optionalText(source, 'bgmUrl');
  result.backgroundUrl = optionalText(source, 'backgroundUrl');
  const style: string | undefined = optionalText(source, 'completionStyle');
  result.completionStyle = style === undefined ? undefined : oneOf(style, ['normal', 'finale']);
  return result;
}

function question(value: Object): GameplayQuestion {
  const source: Record<string, Object> = record(value);
  const result: GameplayQuestion = new GameplayQuestion();
  result.id = text(source, 'id', true);
  result.kind = oneOf(text(source, 'kind'), ['text', 'choice']);
  result.title = text(source, 'title');
  result.placeholder = text(source, 'placeholder');
  const content: Object[] = array(source['content']);
  for (let i: number = 0; i < content.length; i++) {
    const item: Record<string, Object> = record(content[i]);
    const block: GameplayContentBlock = new GameplayContentBlock();
    block.text = text(item, 'text');
    block.hint = text(item, 'hint');
    block.imageUrl = text(item, 'imageUrl');
    block.imageUrls = stringArray(item['imageUrls']);
    block.videoUrl = text(item, 'videoUrl');
    result.content.push(block);
  }
  const options: Object[] = array(source['options']);
  const keys: string[] = [];
  for (let i: number = 0; i < options.length; i++) {
    const item: Record<string, Object> = record(options[i]);
    const option: GameplayOption = new GameplayOption();
    option.key = text(item, 'key', true);
    option.text = text(item, 'text');
    option.imageUrl = text(item, 'imageUrl');
    option.videoUrl = text(item, 'videoUrl');
    if (keys.indexOf(option.key) >= 0) {
      throw invalid();
    }
    keys.push(option.key);
    result.options.push(option);
  }
  return result;
}

function level(value: Object): GameplayLevel {
  const source: Record<string, Object> = record(value);
  const result: GameplayLevel = new GameplayLevel();
  result.id = text(source, 'id', true);
  result.position = integer(source, 'position');
  result.xp = integer(source, 'xp');
  result.autoNext = bool(source, 'autoNext');
  result.completedAt = date(source, 'completedAt');
  result.wrongCount = integer(source, 'wrongCount');
  result.cooldownUntil = date(source, 'cooldownUntil');
  result.locked = bool(source, 'locked');
  result.presentationOverride = presentation(source['presentationOverride']);
  result.question = source['question'] === null ? null : question(source['question']);
  result.lastAnswer = text(source, 'lastAnswer');
  return result;
}

function effect(value: Object): GameplayEffect {
  const source: Record<string, Object> = record(value);
  const result: GameplayEffect = new GameplayEffect();
  result.type = oneOf(text(source, 'type'), ['clue']);
  result.clueId = text(source, 'clueId', true);
  result.autoPlay = optionalBool(source, 'autoPlay');
  return result;
}

function clue(value: Object): GameplayClue {
  const source: Record<string, Object> = record(value);
  const result: GameplayClue = new GameplayClue();
  result.id = text(source, 'id', true);
  result.source = oneOf(optionalText(source, 'source') || 'session', ['session', 'question']);
  result.definitionId = optionalText(source, 'definitionId') || result.id;
  result.question = optionalText(source, 'question') || '';
  result.sessionLevel = optionalText(source, 'sessionLevel') || '';
  result.trigger = oneOf(text(source, 'trigger'),
    ['start', 'level_completed', 'session_completed', 'manual', 'question_completed']);
  result.kind = oneOf(text(source, 'kind'), ['text', 'image', 'video', 'link', 'letter', 'bless']);
  result.position = integer(source, 'position');
  result.narrative = text(source, 'narrative');
  result.autoPlay = bool(source, 'autoPlay');
  result.unlockedAt = date(source, 'unlockedAt');
  const body: Record<string, Object> = record(source['content']);
  const content: GameplayClueContent = new GameplayClueContent();
  content.title = text(body, 'title');
  content.text = text(body, 'text');
  content.url = text(body, 'url');
  content.imageUrls = stringArray(body['imageUrls']);
  content.buttonText = text(body, 'buttonText');
  content.description = optionalText(body, 'description');
  content.tips = optionalText(body, 'tips');
  result.content = content;
  if (result.source === 'question' && (result.question.length === 0 || result.sessionLevel.length === 0 ||
    result.trigger !== 'question_completed' || result.kind === 'letter' || result.kind === 'bless')) {
    throw invalid();
  }
  return result;
}

function completionTarget(value: Object): GameplayCompletionTarget | null {
  if (value === null) {
    return null;
  }
  const source: Record<string, Object> = record(value);
  const result: GameplayCompletionTarget = new GameplayCompletionTarget();
  result.kind = oneOf(text(source, 'kind'), ['narrative', 'link']);
  if (result.kind === 'narrative') {
    result.id = text(source, 'id', true);
  } else {
    result.url = text(source, 'url');
  }
  return result;
}

export function decodeGameplay(body: string): GameplaySnapshot {
  const result: GameplaySnapshot = new GameplaySnapshot();
  // Reuse the frozen read-only boundary without extending or weakening its required fields.
  result.detail = decodeAssignment(body);
  let source: Record<string, Object>;
  try {
    source = record(JSON.parse(body) as Object);
  } catch (error) {
    throw invalid();
  }
  result.presentation = presentation(source['presentation']);
  result.completionTarget = completionTarget(source['completionTarget']);
  const levels: Object[] = array(source['levels']);
  const ids: string[] = [];
  const unlocked: boolean = result.detail.startedAt.length > 0 && result.detail.status !== 'cancelled';
  if (levels.length !== result.detail.totalLevels || result.detail.currentIndex > Math.max(0, levels.length - 1)) {
    throw invalid();
  }
  for (let i: number = 0; i < levels.length; i++) {
    const item: GameplayLevel = level(levels[i]);
    if (ids.indexOf(item.id) >= 0 || ((!unlocked || i > result.detail.currentIndex) &&
      (item.question !== null || item.lastAnswer.length > 0)) ||
      (unlocked && i <= result.detail.currentIndex && item.question === null)) {
      throw invalid();
    }
    ids.push(item.id);
    result.levels.push(item);
  }
  const clues: Object[] = array(source['clues']);
  for (let i: number = 0; i < clues.length; i++) {
    result.clues.push(clue(clues[i]));
  }
  if (source['transitionEffects'] !== undefined) {
    const effects: Object[] = array(source['transitionEffects']);
    for (let i: number = 0; i < effects.length; i++) {
      result.transitionEffects.push(effect(effects[i]));
    }
  }
  return result;
}

export function decodeGameplayAnswer(body: string): GameplayAnswerResult {
  let source: Record<string, Object>;
  try {
    source = record(JSON.parse(body) as Object);
  } catch (error) {
    throw invalid();
  }
  const result: GameplayAnswerResult = new GameplayAnswerResult();
  result.result = oneOf(text(source, 'result'), ['correct', 'incorrect', 'already_completed']);
  result.xpDelta = integer(source, 'xpDelta');
  result.rewardIds = stringArray(source['rewardIds']);
  if (result.rewardIds.some((id: string) => id.length === 0)) {
    throw invalid();
  }
  if (source['effects'] !== undefined) {
    const effects: Object[] = array(source['effects']);
    for (let i: number = 0; i < effects.length; i++) {
      result.effects.push(effect(effects[i]));
    }
  }
  result.assignment = decodeGameplay(JSON.stringify(record(source['assignment'])));
  result.player = decodePlayer(JSON.stringify(record(source['player'])));
  // A replay keeps the old outcome but returns freshly read assignment/player facts.
  // Do not infer current progress, rank or XP from the historical result/xpDelta.
  return result;
}
