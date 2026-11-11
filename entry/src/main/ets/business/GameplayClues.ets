import { GameplayClue, GameplayLevel, GameplaySnapshot } from './GameplayModels';

function compareText(left: string, right: string): number {
  return left < right ? -1 : left > right ? 1 : 0;
}

export function clueImageSources(clue: GameplayClue): string[] {
  return clue.content.imageUrls.filter((source: string) => source.length > 0);
}

/** Mobile archive projection. The server snapshot is the only source of grants. */
export function ordinaryClues(snapshot: GameplaySnapshot | null, level: GameplayLevel | null): GameplayClue[] {
  if (snapshot === null || snapshot.detail.status === 'cancelled' || level === null ||
    level.question === null || level.completedAt.length === 0) {
    return [];
  }
  return snapshot.clues.filter((clue: GameplayClue) => {
    if (clue.kind !== 'text' && (clue.kind !== 'image' || clueImageSources(clue).length === 0)) { return false; }
    if (clue.source === 'question') { return clue.sessionLevel.length > 0 && clue.sessionLevel === level.id; }
    if (clue.sessionLevel.length > 0) { return clue.sessionLevel === level.id; }
    return !(snapshot.detail.totalLevels > 1 && clue.trigger === 'session_completed' && clue.kind === 'text');
  }).sort((left: GameplayClue, right: GameplayClue) => {
    if (left.source !== right.source) { return left.source === 'session' ? -1 : 1; }
    return left.position - right.position ||
      compareText(left.definitionId || left.id, right.definitionId || right.id) || compareText(left.id, right.id);
  });
}

export function clueTitle(clue: GameplayClue): string {
  return clue.content.title || (clue.kind === 'image' ? '神谕影像' : '古老密卷');
}

export class ClueSpan {
  text: string;
  highlight: boolean;

  constructor(text: string, highlight: boolean = false) {
    this.text = text;
    this.highlight = highlight;
  }
}

export class ClueTextPart {
  spans: ClueSpan[] = [];
  image: string = '';
}

/**
 * Native reading subset of the frozen RichContent tokens. Inline images go through
 * the existing image loader policy. Link labels remain readable without navigation;
 * videos and their posters are not fetched by the text dialog.
 */
export function clueTextParts(source: string, preview: boolean = false): ClueTextPart[] {
  const tokens: RegExp = /\[\[[\s\S]*?\]\]|\(\([\s\S]*?\|\|[\s\S]*?\)\)(?!\))|\{\{[\s\S]*?\}\}|<<[\s\S]*?>>/g;
  const parts: ClueTextPart[] = [];
  let paragraph: ClueTextPart = new ClueTextPart();
  let from: number = 0;
  const append = (text: string, highlight: boolean = false): void => {
    if (text.length > 0) { paragraph.spans.push(new ClueSpan(text.replace(/\r\n/g, '\n'), highlight)); }
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
      append(token.slice(2, token.indexOf('||')) || token);
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
