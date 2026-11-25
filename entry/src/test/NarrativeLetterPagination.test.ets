import { describe, expect, it } from '@ohos/hypium';
import { LetterColumn, LetterSegment, letterPageForCursor, letterVerticalColumns,
  paginateLetterRuns } from '../main/ets/ui/NarrativeLetterPagination';

export default function narrativeLetterPaginationTests(): void {
  describe('NarrativeLetterPagination', () => {
    it('preserves code points and empty paragraphs across exact page boundaries', 0, () => {
      const runs: string[][] = [['甲', '✨', '🪐', '乙'], [], ['尾', '句']];
      const pages: LetterSegment[][] = paginateLetterRuns(runs, 2, 1,
        (segment: LetterSegment) => Math.max(1, segment.end - segment.start));
      expect(pages.length).assertEqual(4);
      expect(runs[0].slice(pages[0][0].start, pages[0][0].end).join('')).assertEqual('甲✨');
      expect(runs[0].slice(pages[1][0].start, pages[1][0].end).join('')).assertEqual('🪐乙');
      expect(pages[2][0].start).assertEqual(0);
      expect(pages[2][0].end).assertEqual(0);
      expect(letterPageForCursor(pages, 0, 1)).assertEqual(0);
      expect(letterPageForCursor(pages, 0, 2)).assertEqual(1);
      expect(letterPageForCursor(pages, 0, 4)).assertEqual(-1);
      expect(letterPageForCursor(pages, 1, 0)).assertEqual(2);
    });

    it('preserves native measurement tolerance and makes progress on an oversized character', 0, () => {
      const runs: string[][] = [Array.from('甲乙丙')];
      const rounded: LetterSegment[][] = paginateLetterRuns(runs, 1, 0,
        (segment: LetterSegment) => (segment.end - segment.start) * 1.25);
      const oversized: LetterSegment[][] = paginateLetterRuns(runs, 0.1, 0,
        (segment: LetterSegment) => (segment.end - segment.start) * 3);
      expect(rounded.map((page: LetterSegment[]) => page[0].end)).assertDeepEquals([1, 2, 3]);
      expect(oversized.map((page: LetterSegment[]) => page[0].end)).assertDeepEquals([1, 2, 3]);
      expect(paginateLetterRuns([], 2, 0, (_segment: LetterSegment) => 1).length).assertEqual(1);
    });

    it('keeps classical punctuation with the surrounding characters and preserves explicit blank lines', 0, () => {
      const columns: LetterColumn[] = letterVerticalColumns('甲乙，丙\r\n\r\n丁', 2, 1, 0.75, true);
      expect(columns.map((column: LetterColumn) => column.text)).assertDeepEquals(['甲', '乙\n，', '丙', '', '丁']);
      expect(columns[4].caret).assertTrue();
      const opening: LetterColumn[] = letterVerticalColumns('甲（乙', 2, 1, 0.75, true);
      expect(opening.map((column: LetterColumn) => column.text)).assertDeepEquals(['甲', '（\n乙', '']);
      expect(opening[1].caret).assertFalse();
      expect(opening[2].caret).assertTrue();
    });
  });
}
