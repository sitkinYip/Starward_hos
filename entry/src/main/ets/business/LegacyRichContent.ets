type LegacyRichKind = 'text' | 'image' | 'video';
type LegacyRichMode = 'content' | 'clueBody' | 'cluePreview';

export class LegacyRichSpan {
  readonly text: string;
  readonly highlight: boolean;
  readonly linkTarget: string;

  constructor(text: string, highlight: boolean = false, linkTarget: string = '') {
    this.text = text;
    this.highlight = highlight;
    this.linkTarget = linkTarget;
  }
}

export class LegacyRichBlock {
  readonly kind: LegacyRichKind;
  readonly spans: LegacyRichSpan[];
  readonly url: string;
  readonly poster: string;

  constructor(kind: LegacyRichKind, spans: LegacyRichSpan[] = [], url: string = '', poster: string = '') {
    this.kind = kind;
    this.spans = spans;
    this.url = url;
    this.poster = poster;
  }
}

export function isLegacyInternalLink(href: string): boolean {
  return href.startsWith('/') && !href.startsWith('//') && !/[\\\u0000-\u001f\u007f]/.test(href);
}

function destination(raw: string): string {
  const href: string = raw.trim();
  if (/[\\\u0000-\u001f\u007f]/.test(href)) { return ''; }
  return isLegacyInternalLink(href) || /^https?:\/\/[^/?#\s@]+(?:[/?#]|$)/i.test(href) ? href : '';
}

function mediaDestination(raw: string, mode: LegacyRichMode): string {
  const href: string = destination(raw);
  return mode === 'clueBody' && /^http:/i.test(href) ? '' : href;
}

/** Group adjacent spans for native wrapping, keeping separate media blocks in authored order. */
export function legacyRichBlocks(content: string, mode: LegacyRichMode = 'content'): LegacyRichBlock[] {
  const tokens: RegExp = /\[\[[\s\S]*?\]\]|\(\([\s\S]*?\|\|[\s\S]*?\)\)(?!\))|\{\{[\s\S]*?\}\}|<<[\s\S]*?>>/g;
  const blocks: LegacyRichBlock[] = [];
  let spans: LegacyRichSpan[] = [];
  const append = (text: string, highlight: boolean = false, href: string = ''): void => {
    if (text.length > 0) { spans.push(new LegacyRichSpan(text.replace(/\r\n/g, '\n'), highlight, href)); }
  };
  let from: number = 0;
  let match: RegExpExecArray | null = tokens.exec(content);
  while (match !== null) {
    const token: string = match[0];
    const image: boolean = token.startsWith('{{');
    const video: boolean = token.startsWith('<<');
    const value: string = token.slice(2, -2);
    const separator: number = value.indexOf('||');
    const before: string = content.slice(from, match.index);
    let media: string = '';
    if ((image || video) && mode !== 'cluePreview') {
      media = mediaDestination(image || separator < 0 ? value : value.slice(0, separator), mode);
    }
    append(media.length > 0 && mode === 'clueBody' ? before.replace(/\r?\n$/, '') : before);
    if (token.startsWith('[[')) {
      append(value, true);
    } else if (token.startsWith('((')) {
      const label: string = value.slice(0, separator);
      append(label || token, false, label.length > 0 && mode !== 'cluePreview' ?
        destination(value.slice(separator + 2)) : '');
    } else if (media.length > 0) {
      if (spans.length > 0) { blocks.push(new LegacyRichBlock('text', spans)); }
      spans = [];
      const poster: string = video && separator >= 0 ? mediaDestination(value.slice(separator + 2), mode) : '';
      blocks.push(new LegacyRichBlock(image ? 'image' : 'video', [], media, poster));
    }
    from = match.index + token.length;
    if (mode !== 'content' && (media.length > 0 || ((image || video) && /\r?\n$/.test(before)))) {
      // The media block supplies its own vertical spacing. Keep the other authored blank lines.
      if (content.startsWith('\r\n', from)) { from += 2; } else if (content.startsWith('\n', from)) { from++; }
    }
    match = tokens.exec(content);
  }
  append(content.slice(from));
  if (spans.length > 0) { blocks.push(new LegacyRichBlock('text', spans)); }
  return blocks;
}

export function legacyImageSources(blocks: LegacyRichBlock[]): string[] {
  return blocks.filter((block: LegacyRichBlock) => block.kind === 'image')
    .map((block: LegacyRichBlock) => block.url);
}
