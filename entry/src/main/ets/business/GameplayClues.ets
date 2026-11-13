import { GameplayClue, GameplayEffect, GameplayLevel, GameplaySnapshot } from './GameplayModels';

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

function isOrdinaryClue(clue: GameplayClue, totalLevels: number): boolean {
  return !isCombinationClue(clue, totalLevels) && (clue.kind === 'text' ||
    (clue.kind === 'image' && clueImageSources(clue).length > 0) ||
    (clue.kind === 'video' && clue.content.url.trim().length > 0));
}

/** Mobile archive projection. The server snapshot is the only source of grants. */
export function ordinaryClues(snapshot: GameplaySnapshot | null, level: GameplayLevel | null): GameplayClue[] {
  if (snapshot === null || snapshot.detail.status === 'cancelled' || level === null ||
    level.question === null || level.completedAt.length === 0) {
    return [];
  }
  return snapshot.clues.filter((clue: GameplayClue) => {
    if (!isOrdinaryClue(clue, snapshot.detail.totalLevels)) { return false; }
    if (clue.source === 'question') { return clue.sessionLevel.length > 0 && clue.sessionLevel === level.id; }
    return clue.sessionLevel.length === 0 || clue.sessionLevel === level.id;
  }).sort(clueOrder);
}

/** Only the successful answer response can start automatic clues for the current question. */
export function answerAutomaticClues(previous: GameplaySnapshot | null, settled: GameplaySnapshot,
  level: GameplayLevel, effects: GameplayEffect[] | undefined): GameplayClue[] {
  const normalCompletion: boolean = settled.detail.status === 'completed' &&
    previous?.detail.status !== 'completed' && settled.presentation.completionStyle !== 'finale';
  if (settled.detail.status !== 'active' && !normalCompletion) { return []; }
  const provided: Map<string, boolean | undefined> = new Map();
  for (const effect of effects || []) {
    if (effect.type === 'clue') { provided.set(effect.clueId, effect.autoPlay); }
  }
  const known: Set<string> = new Set((previous?.clues || []).map((clue: GameplayClue) => clue.id));
  let available: GameplayClue[];
  if (normalCompletion && effects !== undefined) {
    // Completion can explicitly unlock a session clue filed under an earlier question.
    const levelOrder: Map<string, number> = new Map();
    settled.levels.forEach((entry: GameplayLevel, index: number) => levelOrder.set(entry.id, index));
    available = settled.clues.filter((clue: GameplayClue) => isOrdinaryClue(clue, settled.detail.totalLevels))
      .sort((left: GameplayClue, right: GameplayClue) => clueOrder(left, right, levelOrder));
  } else {
    available = ordinaryClues(settled, level);
  }
  return available.filter((clue: GameplayClue) => {
    return effects === undefined ? !known.has(clue.id) && clue.autoPlay :
      provided.has(clue.id) && (provided.get(clue.id) ?? clue.autoPlay);
  });
}

export function clueTitle(clue: GameplayClue): string {
  if (clue.content.title.length > 0) { return clue.content.title; }
  if (clue.kind === 'image') { return '神谕影像'; }
  return clue.kind === 'video' ? '时空回溯' : '古老密卷';
}

export class ClueSpan {
  text: string;
  highlight: boolean;
  linkTarget: string;

  constructor(text: string, highlight: boolean = false, linkTarget: string = '') {
    this.text = text;
    this.highlight = highlight;
    this.linkTarget = linkTarget;
  }
}

export class ClueTextPart {
  spans: ClueSpan[] = [];
  image: string = '';
}

/**
 * Native reading subset of the frozen RichContent tokens. Inline images go through
 * the existing image loader policy. Link targets are retained only in the reading body;
 * videos and their posters are not fetched by the text dialog.
 */
export function clueTextParts(source: string, preview: boolean = false): ClueTextPart[] {
  const tokens: RegExp = /\[\[[\s\S]*?\]\]|\(\([\s\S]*?\|\|[\s\S]*?\)\)(?!\))|\{\{[\s\S]*?\}\}|<<[\s\S]*?>>/g;
  const parts: ClueTextPart[] = [];
  let paragraph: ClueTextPart = new ClueTextPart();
  let from: number = 0;
  const append = (text: string, highlight: boolean = false, linkTarget: string = ''): void => {
    if (text.length > 0) { paragraph.spans.push(new ClueSpan(text.replace(/\r\n/g, '\n'), highlight, linkTarget)); }
  };
  let match: RegExpExecArray | null = tokens.exec(source);
  while (match !== null) {
    const token: string = match[0];
    const isImage: boolean = token.startsWith('{{');
    const image: string = isImage ? token.slice(2, -2).trim() : '';
    const showImage: boolean = isImage && !preview &&
      (/^https:\/\//i.test(image) || (image.startsWith('/') && !image.startsWith('//')));
    const before: string = source.slice(from, match.index);
    // A rendered image is already a block. Its enclosing line breaks would add two blank lines.
    append(showImage ? before.replace(/\r?\n$/, '') : before);
    if (token.startsWith('[[')) {
      append(token.slice(2, -2), true);
    } else if (token.startsWith('((')) {
      const separator: number = token.indexOf('||');
      const label: string = token.slice(2, separator);
      append(label || token, false, !preview && label.length > 0 ? token.slice(separator + 2, -2).trim() : '');
    } else if (showImage) {
      if (paragraph.spans.length > 0) { parts.push(paragraph); }
      const picture: ClueTextPart = new ClueTextPart();
      picture.image = image;
      parts.push(picture);
      paragraph = new ClueTextPart();
    }
    from = match.index + token.length;
    if (showImage || ((isImage || token.startsWith('<<')) && /\r?\n$/.test(before))) {
      // When a media-only line is omitted, keep its preceding break for the text preview.
      if (source.startsWith('\r\n', from)) { from += 2; } else if (source.startsWith('\n', from)) { from++; }
    }
    match = tokens.exec(source);
  }
  append(source.slice(from));
  if (paragraph.spans.length > 0) { parts.push(paragraph); }
  return parts;
}
