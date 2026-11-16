import { LegacyRichBlock, LegacyRichSpan, legacyRichBlocks } from './LegacyRichContent';
export { LegacyRichBlock as JourneyNotificationBlock } from './LegacyRichContent';

export function journeyNotificationBlocks(content: string): LegacyRichBlock[] {
  return legacyRichBlocks(content);
}

export function journeyNotificationPreview(content: string): string {
  const summary: string = legacyRichBlocks(content).map((block: LegacyRichBlock) =>
    block.kind === 'text' ? block.spans.map((span: LegacyRichSpan) => span.text).join('') : ' ')
    .join('').replace(/\s+/g, ' ').trim().slice(0, 160);
  return summary || '打开查看来信内容';
}
