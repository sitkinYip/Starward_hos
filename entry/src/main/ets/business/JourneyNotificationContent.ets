import { LegacyRichBlock, LegacyRichSpan, legacyRichBlocks } from './LegacyRichContent';
export { LegacyRichBlock as JourneyNotificationBlock } from './LegacyRichContent';

export function journeyNotificationBlocks(content: string): LegacyRichBlock[] {
  return legacyRichBlocks(content);
}

export function journeyNotificationHasMedia(blocks: LegacyRichBlock[], kind: 'image' | 'video',
  source: string, poster: string = ''): boolean {
  return source.length > 0 && blocks.some((block: LegacyRichBlock) => block.kind === kind && block.url === source &&
    (kind === 'image' || block.poster === poster));
}

export function journeyNotificationHasLink(blocks: LegacyRichBlock[], href: string): boolean {
  return href.length > 0 && blocks.some((block: LegacyRichBlock) => block.kind === 'text' &&
    block.spans.some((span: LegacyRichSpan) => span.linkTarget === href));
}

export function journeyNotificationPreview(content: string): string {
  const summary: string = legacyRichBlocks(content).map((block: LegacyRichBlock) =>
    block.kind === 'text' ? block.spans.map((span: LegacyRichSpan) => span.text).join('') : ' ')
    .join('').replace(/\s+/g, ' ').trim().slice(0, 160);
  return summary || '打开查看来信内容';
}
