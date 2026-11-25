const CANNOT_START_COLUMN = '、。，．！？：；）〕］｝〉》」』】〙〗〟’”';
const CANNOT_END_COLUMN = '（〔［｛〈《「『【〘〖〝‘“';

/** Offsets count Unicode code points in one paragraph. */
export class LetterSegment {
  readonly paragraph: number;
  readonly start: number;
  readonly end: number;

  constructor(paragraph: number, start: number, end: number) {
    this.paragraph = paragraph;
    this.start = start;
    this.end = end;
  }
}

export class LetterColumn {
  readonly text: string;
  readonly caret: boolean;

  constructor(text: string, caret: boolean = false) {
    this.text = text;
    this.caret = caret;
  }
}

export function letterPageForCursor(pages: LetterSegment[][], paragraph: number, visible: number): number {
  return pages.findIndex((page: LetterSegment[]) => page.some((segment: LetterSegment) =>
    segment.paragraph === paragraph && visible >= segment.start &&
    (visible < segment.end || (segment.start === segment.end && visible === segment.end))));
}

export function letterVerticalColumns(content: string, bodyHeight: number, advance: number, caretHeight: number,
  caret: boolean = false): LetterColumn[] {
  const limit: number = Math.max(1, Math.floor(bodyHeight / advance));
  const lines: string[] = content.split(/\r\n|\n|\r/);
  const result: LetterColumn[] = [];
  let lastLength: number = 0;
  for (let index: number = 0; index < lines.length; index++) {
    const points: string[] = Array.from(lines[index]);
    if (points.length === 0 && index < lines.length - 1) { result.push(new LetterColumn('')); }
    lastLength = 0;
    for (let start: number = 0; start < points.length;) {
      let end: number = Math.min(points.length, start + limit);
      while (end > start + 1 && end < points.length &&
        (CANNOT_START_COLUMN.includes(points[end]) || CANNOT_END_COLUMN.includes(points[end - 1]))) {
        end--;
      }
      lastLength = end - start;
      result.push(new LetterColumn(points.slice(start, end).join('\n')));
      start = end;
    }
  }
  if (caret) {
    if (lastLength === 0 || lastLength * advance + caretHeight > bodyHeight) {
      result.push(new LetterColumn('', true));
    } else {
      const last: LetterColumn = result[result.length - 1];
      result[result.length - 1] = new LetterColumn(last.text, true);
    }
  }
  return result;
}

/** The reader supplies measured space for a segment in its current writing mode and font. */
export function paginateLetterRuns(runs: string[][], limit: number, gap: number,
  measure: (segment: LetterSegment) => number): LetterSegment[][] {
  const pages: LetterSegment[][] = [[]];
  let used: number = 0;
  for (let index: number = 0; index < runs.length; index++) {
    const length: number = runs[index].length;
    let start: number = 0;
    do {
      const page: LetterSegment[] = pages[pages.length - 1];
      let low: number = Math.min(start + 1, length);
      let high: number = length;
      let fit: number = -1;
      let fitSpace: number = 0;
      const gapBefore: number = page.length > 0 ? gap : 0;
      while (low <= high) {
        const middle: number = Math.floor((low + high) / 2);
        const space: number = measure(new LetterSegment(index, start, middle)) + gapBefore;
        if (used + space <= limit + 0.25) {
          fit = middle;
          fitSpace = space;
          low = middle + 1;
        } else {
          high = middle - 1;
        }
      }
      if (fit < 0 && page.length > 0) {
        pages.push([]);
        used = 0;
        // The new page must receive even a blank paragraph.
        continue;
      }
      if (fit < 0) { fit = Math.min(start + 1, length); }
      page.push(new LetterSegment(index, start, fit));
      used += fitSpace;
      start = fit;
      if (start < length) {
        pages.push([]);
        used = 0;
      }
    } while (start < length || (length === 0 && pages[pages.length - 1].length === 0));
  }
  return pages;
}
