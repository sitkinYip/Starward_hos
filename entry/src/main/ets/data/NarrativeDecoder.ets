import { NarrativeBless, NarrativeBlessLine, NarrativeContent, NarrativeLetter, NarrativeLetterVariant, NarrativeParagraph,
  NarrativeParagraphAlign } from '../business/NarrativeModels';
import { GameFailure } from '../business/models';

function invalid(): GameFailure {
  return new GameFailure('CONTRACT_ERROR', '服务返回了不兼容的剧情内容，请重试或联系管理员。');
}

function record(value: Object): Record<string, Object> {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw invalid();
  }
  return value as Record<string, Object>;
}

function text(value: Object, max: number, fallback?: string): string {
  if (value === undefined && fallback !== undefined) { return fallback; }
  if (typeof value !== 'string' || value.length > max || (fallback === undefined && value.trim().length === 0)) {
    throw invalid();
  }
  return value;
}

function integer(value: Object, fallback: number, min: number, max: number): number {
  if (value === undefined) { return fallback; }
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < min || value > max) { throw invalid(); }
  return value;
}

function array(value: Object, max: number, optional: boolean = false): Object[] {
  if (value === undefined && optional) { return []; }
  if (!Array.isArray(value) || value.length > max || (!optional && value.length === 0)) { throw invalid(); }
  return value as Object[];
}

function media(value: Object): string {
  const source: string = text(value, 4000, '').trim();
  // Match the input boundary shared by the native image/audio loaders. They validate and resolve the destination at load time.
  if (/[\s\\\u0000-\u001f\u007f]/.test(source)) { return ''; }
  return /^(?:https:\/\/[^/?#@]+(?:[/?#]|$)|\/(?!\/))/i.test(source) ? source : '';
}

function paragraph(value: Object): NarrativeParagraph {
  const source: Record<string, Object> = record(value);
  const align: string = text(source['align'], 6, 'left');
  if (align !== 'left' && align !== 'center' && align !== 'right' && align !== 'top' && align !== 'bottom') {
    throw invalid();
  }
  const result: NarrativeParagraph = new NarrativeParagraph();
  result.content = text(source['content'], 16000);
  result.align = align as NarrativeParagraphAlign;
  result.delayMs = integer(source['delayMs'], 0, 0, 600000);
  result.audioUrl = media(source['audioUrl']);
  return result;
}

function letter(payload: Record<string, Object>): NarrativeLetter {
  const variant: string = text(payload['variant'], 9);
  if (variant !== 'modern' && variant !== 'classical' && variant !== 'magic') { throw invalid(); }
  const result: NarrativeLetter = new NarrativeLetter();
  result.variant = variant as NarrativeLetterVariant;
  result.from = text(payload['from'], 200, '');
  result.description = text(payload['description'], 2000, '');
  result.hintText = text(payload['hintText'], 200, result.hintText);
  result.paragraphs = array(payload['paragraphs'], 100).map(paragraph);
  result.backgroundImages = array(payload['backgroundImages'], 30, true).map(media);
  result.pageBackgroundUrl = media(payload['pageBackgroundUrl']);
  result.mainAudioUrl = media(payload['mainAudioUrl']);
  result.typingSpeedMs = integer(payload['typingSpeedMs'], 60, 1, 2000);
  return result;
}

function blessLine(value: Object): NarrativeBlessLine {
  const line: Record<string, Object> = record(value);
  const result: NarrativeBlessLine = new NarrativeBlessLine();
  result.text = text(line['text'], 16000);
  result.durationMs = integer(line['durationMs'], 3000, 0, 600000);
  result.audioUrl = media(line['audioUrl']);
  return result;
}

function bless(payload: Record<string, Object>): NarrativeBless {
  const result: NarrativeBless = new NarrativeBless();
  result.from = text(payload['from'], 200, '');
  result.phrases = array(payload['phrases'], 100).map(blessLine);
  result.closingLines = array(payload['closingLines'], 100, true).map(blessLine);
  result.mainAudioUrl = media(payload['mainAudioUrl']);
  return result;
}

/** Decodes the payload of an authorized narrative detail response. */
export function decodeNarrative(body: string): NarrativeContent {
  let source: Record<string, Object>;
  try { source = record(JSON.parse(body) as Object); } catch { throw invalid(); }
  const payload: Record<string, Object> = record(source['payload']);
  const result: NarrativeContent = new NarrativeContent();
  result.id = text(source['id'], 100);
  result.title = text(source['title'], 200);
  const kind: Object = source['kind'];
  if (kind === 'letter') {
    result.letter = letter(payload);
  } else if (kind === 'bless') {
    result.kind = 'bless';
    result.bless = bless(payload);
  } else {
    throw invalid();
  }
  return result;
}
