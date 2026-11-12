import { describe, expect, it } from '@ohos/hypium';
import { image } from '@kit.ImageKit';
import { QuestionImageCache } from '../main/ets/platform/QuestionImageCache';
import { QuestionImageMetadata, QuestionImagePixelsHandle } from '../main/ets/platform/QuestionImageIO';
import { QuestionImageResult } from '../main/ets/platform/QuestionImageLoader';

const SOURCE_A: string = 'https://image.example.com/a.png?v=1';
const SOURCE_B: string = 'https://image.example.com/a.png?v=2';
const SOURCE_C: string = 'https://image.example.com/c.png';

class CacheTestImage implements QuestionImagePixelsHandle {
  readonly result: QuestionImageResult;
  releaseCalls: number = 0;

  constructor() {
    this.result = new QuestionImageResult(this, 32, 4, 32, 4, 'image/png');
  }

  async metadata(): Promise<QuestionImageMetadata> { return { widthPx: 32, heightPx: 4, mimeType: 'image/png' }; }
  bytesPerRow(): number { return 256; }
  async flip(_horizontal: boolean, _vertical: boolean): Promise<void> {}
  async rotate(_degrees: number): Promise<void> {}
  async release(): Promise<void> { this.releaseCalls++; }

  nativeValue(): image.PixelMap {
    throw new Error('The cache tests verify ownership without rendering a PixelMap');
  }
}

async function remember(cache: QuestionImageCache, source: string, image: CacheTestImage): Promise<void> {
  cache.remember(source, image.result, cache.version());
  await image.result.release();
}

export default function questionImageCacheTests(): void {
  describe('QuestionImageCacheTests', () => {
    it('reusesTheSameDecodedResultAndKeepsRecentlyViewedEntries', 0, async () => {
      const cache: QuestionImageCache = new QuestionImageCache(() => 'assignment-a', 4096, 2);
      const first: CacheTestImage = new CacheTestImage();
      const second: CacheTestImage = new CacheTestImage();
      const third: CacheTestImage = new CacheTestImage();
      await remember(cache, SOURCE_A, first);
      await remember(cache, SOURCE_B, second);
      const updated: QuestionImageResult | undefined = cache.acquire(SOURCE_B);
      expect(updated === second.result).assertTrue();
      await updated?.release();
      const revisited: QuestionImageResult | undefined = cache.acquire(SOURCE_A);
      expect(revisited === first.result).assertTrue();
      await revisited?.release();

      await remember(cache, SOURCE_C, third);
      expect(cache.acquire(SOURCE_B)).assertUndefined();
      expect(second.releaseCalls).assertEqual(1);
      const retained: QuestionImageResult | undefined = cache.acquire(SOURCE_A);
      expect(retained === first.result).assertTrue();
      await retained?.release();
      expect(first.releaseCalls).assertEqual(0);
      cache.clear();
      expect(first.releaseCalls).assertEqual(1);
      expect(third.releaseCalls).assertEqual(1);
    });

    it('appliesTheDecodedByteLimitUsingTheActualRowSize', 0, async () => {
      const cache: QuestionImageCache = new QuestionImageCache(() => 'assignment-a', 1536, 8);
      const first: CacheTestImage = new CacheTestImage();
      const second: CacheTestImage = new CacheTestImage();
      await remember(cache, SOURCE_A, first);
      await remember(cache, SOURCE_B, second);
      expect(cache.acquire(SOURCE_A)).assertUndefined();
      expect(first.releaseCalls).assertEqual(1);
      const retained: QuestionImageResult | undefined = cache.acquire(SOURCE_B);
      expect(retained === second.result).assertTrue();
      await retained?.release();
      cache.clear();
      expect(second.releaseCalls).assertEqual(1);
    });

    it('holdsPixelsUntilTheLastDisplayReleasesAfterEviction', 0, async () => {
      const cache: QuestionImageCache = new QuestionImageCache(() => 'assignment-a', 4096, 1);
      const first: CacheTestImage = new CacheTestImage();
      const second: CacheTestImage = new CacheTestImage();
      await remember(cache, SOURCE_A, first);
      const inline: QuestionImageResult | undefined = cache.acquire(SOURCE_A);
      const viewer: QuestionImageResult | undefined = cache.acquire(SOURCE_A);
      expect(inline === first.result && viewer === first.result).assertTrue();

      await remember(cache, SOURCE_B, second);
      expect(cache.acquire(SOURCE_A)).assertUndefined();
      expect(first.releaseCalls).assertEqual(0);
      await inline?.release();
      expect(first.releaseCalls).assertEqual(0);
      await viewer?.release();
      expect(first.releaseCalls).assertEqual(1);
      cache.clear();
      expect(second.releaseCalls).assertEqual(1);
    });

    it('discardsLateResultsAfterAnOwnerChangeOrExplicitClear', 0, async () => {
      let owner: string = 'assignment-a';
      const cache: QuestionImageCache = new QuestionImageCache(() => owner);
      const previous: CacheTestImage = new CacheTestImage();
      const late: CacheTestImage = new CacheTestImage();
      const oldVersion: number = cache.version();
      await remember(cache, SOURCE_A, previous);

      owner = 'assignment-b';
      cache.validateOwner();
      expect(cache.acquire(SOURCE_A)).assertUndefined();
      expect(previous.releaseCalls).assertEqual(1);
      cache.remember(SOURCE_A, late.result, oldVersion);
      expect(cache.acquire(SOURCE_A)).assertUndefined();
      await late.result.release();
      expect(late.releaseCalls).assertEqual(1);

      const current: CacheTestImage = new CacheTestImage();
      await remember(cache, SOURCE_A, current);
      const beforeClear: number = cache.version();
      cache.clear();
      cache.clear();
      expect(current.releaseCalls).assertEqual(1);
      const cleared: CacheTestImage = new CacheTestImage();
      cache.remember(SOURCE_A, cleared.result, beforeClear);
      expect(cache.acquire(SOURCE_A)).assertUndefined();
      await cleared.result.release();
      expect(cleared.releaseCalls).assertEqual(1);
    });
  });
}
