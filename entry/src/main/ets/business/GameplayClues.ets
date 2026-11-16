import { LegacyRichBlock, LegacyRichSpan, legacyRichBlocks } from './LegacyRichContent';
import { GameplayClue, GameplayEffect, GameplayLevel, GameplaySnapshot } from './GameplayModels';
export { LegacyRichSpan as ClueSpan } from './LegacyRichContent';

function compareText(left: string, right: string): number {
  return left < right ? -1 : left > right ? 1 : 0;
}

export function clueImageSources(clue: GameplayClue): string[] {
  return clue.content.imageUrls.filter((source: string) => source.length > 0);
}

function clueOrder(left: GameplayClue, right: GameplayClue, levelOrder?: Map<string, number>): number {
  if (left.source !== right.source) { return left.source === 'session' ? -1 : 1; }
  if (left.source === 'question' && levelOrder !== undefined) {
    const position: number = (levelOrder.get(left.sessionLevel) ?? Number.MAX_SAFE_INTEGER) -
      (levelOrder.get(right.sessionLevel) ?? Number.MAX_SAFE_INTEGER);
    if (position !== 0) { return position; }
  }
  return left.position - right.position ||
    compareText(left.definitionId || left.id, right.definitionId || right.id) || compareText(left.id, right.id);
}

function isCombinationClue(clue: GameplayClue, totalLevels: number): boolean {
  return totalLevels > 1 && clue.source === 'session' && clue.sessionLevel.length === 0 &&
    clue.trigger === 'session_completed' && clue.kind === 'text';
}

export function combinationClues(snapshot: GameplaySnapshot | null): GameplayClue[] {
  if (snapshot === null || snapshot.detail.status !== 'completed') { return []; }
  return snapshot.clues.filter((clue: GameplayClue) =>
    isCombinationClue(clue, snapshot.detail.totalLevels)).sort(clueOrder);
}

/** Only the result of this answer can start the sequence. A GET always opens silently. */
export function completionCombinations(previous: GameplaySnapshot | null, settled: GameplaySnapshot,
  effects: GameplayEffect[] | undefined): GameplayClue[] {
  const available: GameplayClue[] = combinationClues(settled);
  if (effects !== undefined) {
    const ids: Set<string> = new Set(effects.filter((item: GameplayEffect) => item.type === 'clue')
      .map((item: GameplayEffect) => item.clueId));
    return available.filter((clue: GameplayClue) => ids.has(clue.id));
  }
  const known: Set<string> = new Set((previous?.clues || []).map((clue: GameplayClue) => clue.id));
  return available.filter((clue: GameplayClue) => !known.has(clue.id));
}

function isPlayableClue(clue: GameplayClue, totalLevels: number): boolean {
  return !isCombinationClue(clue, totalLevels) && (clue.kind === 'text' ||
    (clue.kind === 'image' && clueImageSources(clue).length > 0) ||
    (clue.kind === 'video' && clue.content.url.trim().length > 0));
}

export function isNarrativeClue(clue: GameplayClue): boolean {
  return (clue.kind === 'letter' || clue.kind === 'bless') && clue.narrative.trim().length > 0;
}

/** Only a current, granted cue that is absent from the visible archive needs a reminder. */
export function nextNarrativeAttention(snapshot: GameplaySnapshot | null, visibleClues: GameplayClue[],
  openedIds: string[]): GameplayClue | null {
  if (snapshot === null || (snapshot.detail.status !== 'active' && snapshot.detail.status !== 'completed')) {
    return null;
  }
  const omitted: Set<string> = new Set(openedIds);
  visibleClues.forEach((clue: GameplayClue) => omitted.add(clue.id));
  const levelOrder: Map<string, number> = new Map();
  snapshot.levels.forEach((level: GameplayLevel, index: number) => levelOrder.set(level.id, index));
  return snapshot.clues.filter((clue: GameplayClue) => isNarrativeClue(clue) && !omitted.has(clue.id))
    .sort((left: GameplayClue, right: GameplayClue) => clueOrder(left, right, levelOrder))[0] ?? null;
}

function autoplayEffects(effects: GameplayEffect[]): Map<string, boolean | undefined> {
  const result: Map<string, boolean | undefined> = new Map();
  for (const effect of effects) {
    if (effect.type === 'clue') { result.set(effect.clueId, effect.autoPlay); }
  }
  return result;
}

/** The start receipt can present grants before the current question is completed. */
export function entryAutomaticClues(previousIds: string[], snapshot: GameplaySnapshot): GameplayClue[] {
  if (snapshot.detail.status !== 'active' && snapshot.detail.status !== 'completed') { return []; }
  const available: GameplayClue[] = snapshot.clues.filter((clue: GameplayClue) =>
    isPlayableClue(clue, snapshot.detail.totalLevels));
  if (!snapshot.transitionEffectsProvided) {
    const known: Set<string> = new Set(previousIds);
    return available.filter((clue: GameplayClue) => clue.autoPlay && !known.has(clue.id)).sort(clueOrder);
  }
  const effects = autoplayEffects(snapshot.transitionEffects);
  const levelOrder: Map<string, number> = new Map();
  snapshot.levels.forEach((level: GameplayLevel, index: number) => levelOrder.set(level.id, index));
  return available.filter((clue: GameplayClue) => effects.has(clue.id) && (effects.get(clue.id) ?? clue.autoPlay))
    .sort((left: GameplayClue, right: GameplayClue) => clueOrder(left, right, levelOrder));
}

/** Mobile archive projection. The server snapshot is the only source of grants. */
export function ordinaryClues(snapshot: GameplaySnapshot | null, level: GameplayLevel | null): GameplayClue[] {
  if (snapshot === null || snapshot.detail.status === 'cancelled' || level === null ||
    level.question === null || level.completedAt.length === 0) {
    return [];
  }
  return snapshot.clues.filter((clue: GameplayClue) => {
    if (!isPlayableClue(clue, snapshot.detail.totalLevels) && !isNarrativeClue(clue) &&
      !(clue.kind === 'link' && clue.content.url.trim().length > 0)) { return false; }
    if (clue.source === 'question') { return clue.sessionLevel.length > 0 && clue.sessionLevel === level.id; }
    return clue.sessionLevel.length === 0 || clue.sessionLevel === level.id;
  }).sort(clueOrder);
}

/** Only the successful answer response can start automatic clues for the current question. */
export function answerAutomaticClues(previous: GameplaySnapshot | null, settled: GameplaySnapshot,
  level: GameplayLevel, effects: GameplayEffect[] | undefined): GameplayClue[] {
  const newCompletion: boolean = settled.detail.status === 'completed' && previous?.detail.status !== 'completed';
  if (settled.detail.status !== 'active' && !newCompletion) { return []; }
  const provided = autoplayEffects(effects || []);
  const known: Set<string> = new Set((previous?.clues || []).map((clue: GameplayClue) => clue.id));
  let available: GameplayClue[];
  if (newCompletion && effects !== undefined) {
    // Completion can explicitly unlock a session clue filed under an earlier question.
    const levelOrder: Map<string, number> = new Map();
    settled.levels.forEach((entry: GameplayLevel, index: number) => levelOrder.set(entry.id, index));
    available = settled.clues.filter((clue: GameplayClue) => isPlayableClue(clue, settled.detail.totalLevels))
      .sort((left: GameplayClue, right: GameplayClue) => clueOrder(left, right, levelOrder));
  } else {
    available = ordinaryClues(settled, level).filter((clue: GameplayClue) =>
      isPlayableClue(clue, settled.detail.totalLevels));
  }
  return available.filter((clue: GameplayClue) => {
    return effects === undefined ? !known.has(clue.id) && clue.autoPlay :
      provided.has(clue.id) && (provided.get(clue.id) ?? clue.autoPlay);
  });
}

export function clueTitle(clue: GameplayClue): string {
  if (clue.content.title.length > 0) { return clue.content.title; }
  if (clue.kind === 'image') { return '神谕影像'; }
  if (clue.kind === 'link') { return '位面传送'; }
  if (clue.kind === 'letter') { return '星海情笺'; }
  if (clue.kind === 'bless') { return '星辉祝福'; }
  return clue.kind === 'video' ? '时空回溯' : '古老密卷';
}

export class ClueTextPart {
  spans: LegacyRichSpan[] = [];
  image: string = '';
  video: string = '';
  poster: string = '';
}

export function clueTextParts(source: string, preview: boolean = false): ClueTextPart[] {
  return legacyRichBlocks(source, preview ? 'cluePreview' : 'clueBody').map((block: LegacyRichBlock) => {
    const part: ClueTextPart = new ClueTextPart();
    part.spans = block.spans;
    part.image = block.kind === 'image' ? block.url : '';
    part.video = block.kind === 'video' ? block.url : '';
    part.poster = block.poster;
    return part;
  });
}
