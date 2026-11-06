import { describe, expect, it } from '@ohos/hypium';
import { image } from '@kit.ImageKit';
import { QuestionImageFailure, QuestionImageLoader, QuestionImageResult } from '../main/ets/platform/QuestionImageLoader';
import { QuestionImageIO, QuestionImageMetadata, QuestionImagePixelsHandle, QuestionImageRequestHandle,
  QuestionImageResponse, QuestionImageSourceHandle } from '../main/ets/platform/QuestionImageIO';

const SOURCE_A: string = 'https://image.example.com/a.png';
const SOURCE_B: string = 'https://image.example.com/b.png';

class Completion<T> {
  readonly task: Promise<T>;
  private resolve: (value: T) => void = () => {};

  constructor() {
    this.task = new Promise<T>((resolve: (value: T) => void) => { this.resolve = resolve; });
  }

  complete(value: T): void { this.resolve(value); }
}

class ControlledRequest implements QuestionImageRequestHandle {
  readonly entered: Completion<boolean> = new Completion<boolean>();
  readonly response: Completion<QuestionImageResponse> = new Completion<QuestionImageResponse>();
  destroyCalls: number = 0;
  reads: string[] = [];

  async read(target: string): Promise<QuestionImageResponse> {
    this.reads.push(target);
    this.entered.complete(true);
    return await this.response.task;
  }

  destroy(): void { this.destroyCalls++; }

  finish(status: number = 200): void {
    // Signature only: metadata/decoding are controlled resources, not a fake native decoder.
    const bytes: ArrayBuffer = new ArrayBuffer(8);
    new Uint8Array(bytes).set([137, 80, 78, 71, 13, 10, 26, 10]);
    const response: QuestionImageResponse = { status: status, bytes: bytes };
    this.response.complete(response);
  }
}

class ControlledPixels implements QuestionImagePixelsHandle {
  releaseCalls: number = 0;
  transferCalls: number = 0;

  async metadata(): Promise<QuestionImageMetadata> { return { widthPx: 240, heightPx: 120, mimeType: 'image/png' }; }
  async flip(_horizontal: boolean, _vertical: boolean): Promise<void> {}
  async rotate(_degrees: number): Promise<void> {}
  async release(): Promise<void> { this.releaseCalls++; }

  nativeValue(): image.PixelMap {
    this.transferCalls++;
    throw new Error('A cancelled test resource must never be transferred as a native PixelMap');
  }
}

class ControlledSource implements QuestionImageSourceHandle {
  readonly decodeEntered: Completion<boolean> = new Completion<boolean>();
  readonly decoded: Completion<QuestionImagePixelsHandle> = new Completion<QuestionImagePixelsHandle>();
  readonly releaseEntered: Completion<boolean> = new Completion<boolean>();
  readonly releaseFinished: Completion<boolean> = new Completion<boolean>();
  holdRelease: boolean = false;
  decodeFinished: boolean = false;
  releaseBeforeDecodeFinished: boolean = false;
  releaseCalls: number = 0;

  async metadata(): Promise<QuestionImageMetadata> { return { widthPx: 240, heightPx: 120, mimeType: 'image/png' }; }
  async orientation(): Promise<string> { return ''; }
  async decode(_widthPx: number, _heightPx: number): Promise<QuestionImagePixelsHandle> {
    this.decodeEntered.complete(true);
    const pixels: QuestionImagePixelsHandle = await this.decoded.task;
    this.decodeFinished = true;
    return pixels;
  }
  async release(): Promise<void> {
    this.releaseCalls++;
    this.releaseBeforeDecodeFinished = !this.decodeFinished;
    this.releaseEntered.complete(true);
    if (this.holdRelease) { await this.releaseFinished.task; }
  }
}

class ControlledIO implements QuestionImageIO {
  readonly requests: ControlledRequest[];
  readonly sources: ControlledSource[];
  sourceCalls: number = 0;
  private requestIndex: number = 0;

  constructor(requests: ControlledRequest[], sources: ControlledSource[] = []) {
    this.requests = requests;
    this.sources = sources;
  }

  // This suite does not substitute a URL parser or claim URL/TLS/real decode coverage.
  resolveSource(source: string): string {
    if (source !== SOURCE_A && source !== SOURCE_B) { throw new Error('Unexpected synthetic image source'); }
    return source;
  }
  createRequest(): QuestionImageRequestHandle {
    if (this.requestIndex >= this.requests.length) { throw new Error('Unexpected image request'); }
    return this.requests[this.requestIndex++];
  }
  createSource(_bytes: ArrayBuffer): QuestionImageSourceHandle {
    const index: number = this.sourceCalls++;
    if (index >= this.sources.length) { throw new Error('Unexpected image source'); }
    return this.sources[index];
  }
}

class LoadOutcome {
  readonly settled: Promise<void>;
  fulfilled: boolean = false;
  failure: QuestionImageFailure | undefined = undefined;
  unexpectedFailure: boolean = false;

  constructor(task: Promise<QuestionImageResult>) {
    // Attach immediately, so no deliberately held/rejected load becomes unhandled.
    this.settled = task.then((_value: QuestionImageResult) => { this.fulfilled = true; }, (error: Error) => {
      if (error instanceof QuestionImageFailure) { this.failure = error; }
      else { this.unexpectedFailure = true; }
    });
  }
}

function cancelled(outcome: LoadOutcome, status: number = 200): void {
  expect(outcome.fulfilled).assertFalse();
  expect(outcome.unexpectedFailure).assertFalse();
  expect(outcome.failure !== undefined).assertTrue();
  expect(outcome.failure?.cancelled).assertTrue();
  expect(outcome.failure?.httpStatus).assertEqual(status);
}

export default function questionImageLoaderTests(): void {
  describe('QuestionImageLoaderTests', () => {
    it('cancelPendingHttpDestroysOnceAndRejectsItsLateResponseBeforeCreatingSource', 0, async () => {
      const request: ControlledRequest = new ControlledRequest();
      const io: ControlledIO = new ControlledIO([request]);
      const loader: QuestionImageLoader = new QuestionImageLoader(io);
      const outcome: LoadOutcome = new LoadOutcome(loader.load(SOURCE_A));
      await request.entered.task;
      loader.cancel();
      loader.cancel();
      expect(request.destroyCalls).assertEqual(1);
      request.finish();
      await outcome.settled;
      cancelled(outcome);
      expect(io.sourceCalls).assertEqual(0);
      expect(request.destroyCalls).assertEqual(1);
    });

    it('cancelPendingDecodeReleasesTheLatePixelsOnlyAfterTheSourceOperationCompletes', 0, async () => {
      const request: ControlledRequest = new ControlledRequest();
      const source: ControlledSource = new ControlledSource();
      const pixels: ControlledPixels = new ControlledPixels();
      const loader: QuestionImageLoader = new QuestionImageLoader(new ControlledIO([request], [source]));
      const outcome: LoadOutcome = new LoadOutcome(loader.load(SOURCE_A));
      request.finish();
      await source.decodeEntered.task;
      loader.cancel();
      expect(source.releaseCalls).assertEqual(0);
      expect(pixels.releaseCalls).assertEqual(0);
      expect(request.destroyCalls).assertEqual(1);
      source.decoded.complete(pixels);
      await outcome.settled;
      cancelled(outcome);
      expect(source.releaseBeforeDecodeFinished).assertFalse();
      expect(source.releaseCalls).assertEqual(1);
      expect(pixels.releaseCalls).assertEqual(1);
      expect(pixels.transferCalls).assertEqual(0);
      expect(request.destroyCalls).assertEqual(1);
    });

    it('oldHttpFinallyCannotDestroyOrDetachTheReplacementRequest', 0, async () => {
      const first: ControlledRequest = new ControlledRequest();
      const second: ControlledRequest = new ControlledRequest();
      const io: ControlledIO = new ControlledIO([first, second]);
      const loader: QuestionImageLoader = new QuestionImageLoader(io);
      const old: LoadOutcome = new LoadOutcome(loader.load(SOURCE_A));
      await first.entered.task;
      const replacement: LoadOutcome = new LoadOutcome(loader.load(SOURCE_B));
      await second.entered.task;
      expect(first.destroyCalls).assertEqual(1);
      first.finish();
      await old.settled;
      cancelled(old);
      expect(second.destroyCalls).assertEqual(0);
      // This cancellation proves old finally did not merely clear the new owner field.
      loader.cancel();
      expect(second.destroyCalls).assertEqual(1);
      second.finish();
      await replacement.settled;
      cancelled(replacement);
      expect(first.destroyCalls).assertEqual(1);
      expect(second.destroyCalls).assertEqual(1);
      expect(io.sourceCalls).assertEqual(0);
    });

    it('replacementDuringSourceCleanupRejectsOldPixelsAndLeavesTheNewReadIndependent', 0, async () => {
      const first: ControlledRequest = new ControlledRequest();
      const second: ControlledRequest = new ControlledRequest();
      const source: ControlledSource = new ControlledSource();
      source.holdRelease = true;
      const pixels: ControlledPixels = new ControlledPixels();
      const io: ControlledIO = new ControlledIO([first, second], [source]);
      const loader: QuestionImageLoader = new QuestionImageLoader(io);
      const old: LoadOutcome = new LoadOutcome(loader.load(SOURCE_A));
      first.finish();
      await source.decodeEntered.task;
      source.decoded.complete(pixels);
      await source.releaseEntered.task;
      expect(pixels.transferCalls).assertEqual(0);
      expect(pixels.releaseCalls).assertEqual(0);
      const replacement: LoadOutcome = new LoadOutcome(loader.load(SOURCE_B));
      await second.entered.task;
      source.releaseFinished.complete(true);
      await old.settled;
      cancelled(old);
      expect(source.releaseBeforeDecodeFinished).assertFalse();
      expect(source.releaseCalls).assertEqual(1);
      expect(pixels.releaseCalls).assertEqual(1);
      expect(pixels.transferCalls).assertEqual(0);
      expect(second.destroyCalls).assertEqual(0);
      second.finish(404);
      await replacement.settled;
      expect(replacement.fulfilled).assertFalse();
      expect(replacement.unexpectedFailure).assertFalse();
      expect(replacement.failure?.cancelled).assertFalse();
      expect(replacement.failure?.httpStatus).assertEqual(404);
      expect(second.destroyCalls).assertEqual(1);
      expect(first.destroyCalls).assertEqual(1);
      expect(io.sourceCalls).assertEqual(1);
    });
  });
}
