import { ClueSpan } from './GameplayClues';

type JourneyContentKind = 'text' | 'image' | 'video';

export class JourneyNotificationBlock {
  readonly kind: JourneyContentKind;
  readonly spans: ClueSpan[];
  readonly url: string;
  readonly poster: string;

  constructor(kind: JourneyContentKind, spans: ClueSpan[] = [], url: string = '', poster: string = '') {
    this.kind = kind;
    this.spans = spans;
    this.url = url;
    this.poster = poster;
  }
}

function destination(value: string): string {
  const href: string = value.trim();
  if (/[\\\u0000-\u001f\u007f]/.test(href)) { return ''; }
  const relative: boolean = href.startsWith('/') && !href.startsWith('//');
  const external: boolean = /^https?:\/\/[^/?#\s@]+(?:[/?#]|$)/i.test(href);
  return relative || external ? href : '';
}

/** Keep text runs together for native wrapping, with media occupying separate blocks. */
export function journeyNotificationBlocks(content: string): JourneyNotificationBlock[] {
  const blocks: JourneyNotificationBlock[] = [];
  const tokens: RegExp = /\[\[[\s\S]*?\]\]|\(\([\s\S]*?\|\|[\s\S]*?\)\)(?!\))|\{\{[\s\S]*?\}\}|<<[\s\S]*?>>/g;
  let textRuns: ClueSpan[] = [];
  const append = (value: string, highlighted: boolean = false, href: string = ''): void => {
    if (value.length > 0) { textRuns.push(new ClueSpan(value.replace(/\r\n/g, '\n'), highlighted, href)); }
  };
  let from: number = 0;
  let match: RegExpExecArray | null = tokens.exec(content);
  while (match !== null) {
    const token: string = match[0];
    append(content.slice(from, match.index));
    const value: string = token.slice(2, -2);
    const separator: number = value.indexOf('||');
    if (token.startsWith('[[')) {
      append(value, true);
    } else if (token.startsWith('((')) {
      const label: string = value.slice(0, separator);
      append(label || token, false, label.length > 0 ? destination(value.slice(separator + 2)) : '');
    } else {
      const image: boolean = token.startsWith('{{');
      const source: string = destination(image || separator < 0 ? value : value.slice(0, separator));
      if (source.length > 0) {
        if (textRuns.length > 0) { blocks.push(new JourneyNotificationBlock('text', textRuns)); }
        textRuns = [];
        const poster: string = !image && separator >= 0 ? destination(value.slice(separator + 2)) : '';
        blocks.push(new JourneyNotificationBlock(image ? 'image' : 'video', [], source, poster));
      }
    }
    from = match.index + token.length;
    match = tokens.exec(content);
  }
  append(content.slice(from));
  if (textRuns.length > 0) { blocks.push(new JourneyNotificationBlock('text', textRuns)); }
  return blocks;
}

export function journeyNotificationPreview(content: string): string {
  const summary: string = journeyNotificationBlocks(content).map((block: JourneyNotificationBlock) =>
    block.kind === 'text' ? block.spans.map((span: ClueSpan) => span.text).join('') : ' ')
    .join('').replace(/\s+/g, ' ').trim().slice(0, 160);
  return summary || '打开查看来信内容';
}
