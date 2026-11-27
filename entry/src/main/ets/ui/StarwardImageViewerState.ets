import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppEnvironment } from '../platform/AppEnvironment';
import { ImmersiveSurfaces } from '../platform/ImmersiveSurfaces';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { QuestionImageFailure, QuestionImageLoader, QuestionImageResult } from '../platform/QuestionImageLoader';

@ObservedV2
export class StarwardViewerImage {
  readonly source: string;
  @Trace value: QuestionImageResult | undefined = undefined;
  @Trace loadState: string = 'idle';
  private readonly loader: QuestionImageLoader = new QuestionImageLoader();
  private revision: number = 0;

  constructor(source: string) { this.source = source; }

  cancel(): void {
    this.revision++;
    this.loader.cancel();
  }

  release(): void {
    this.cancel();
    const previous: QuestionImageResult | undefined = this.value;
    this.value = undefined;
    this.loadState = 'idle';
    previous?.release();
  }

  async prepare(cache: QuestionImageCache, current: () => boolean, retry: boolean,
    record: (state: string, cacheHit: boolean) => void): Promise<void> {
    if (this.loadState === 'ready' || this.loadState === 'loading') {
      if (retry) { record(this.loadState, this.loadState === 'ready'); }
      return;
    }
    if (this.loadState === 'failed' && !retry) { return; }
    const cached: QuestionImageResult | undefined = cache.acquire(this.source);
    if (cached !== undefined) {
      this.value = cached;
      this.loadState = 'ready';
      record('ready', true);
      return;
    }
    const revision: number = ++this.revision;
    const cacheVersion: number = cache.version();
    this.loadState = 'loading';
    record('loading', false);
    try {
      const value: QuestionImageResult = await this.loader.load(this.source);
      if (revision !== this.revision || !current()) { await value.release(); return; }
      cache.remember(this.source, value, cacheVersion);
      this.value = value;
      this.loadState = 'ready';
      record('ready', false);
    } catch (error) {
      if (revision === this.revision && current() &&
        !(error instanceof QuestionImageFailure && error.cancelled)) { this.loadState = 'failed'; }
    }
  }
}

/** Owns the view session and retains display references for the current and adjacent pages. */
@ObservedV2
export class StarwardImageViewerState {
  @Trace visible: boolean = false;
  @Trace closing: boolean = false;
  @Trace sessionId: number = 0;
  @Trace images: StarwardViewerImage[] = [];
  @Trace index: number = 0;
  @Trace zoom: number = 1;
  @Trace x: number = 0;
  @Trace y: number = 0;
  private readonly imageCache: QuestionImageCache;
  private retained: Set<StarwardViewerImage> = new Set<StarwardViewerImage>();
  private leaseId: number = 0;
  private ownerCurrent: () => boolean = () => false;
  private onClosed?: () => void;

  constructor(imageCache: QuestionImageCache) { this.imageCache = imageCache; }

  open(sources: string[], index: number, ownerCurrent: () => boolean, onClosed?: () => void): boolean {
    if (this.visible || this.closing || !ownerCurrent() || !Number.isInteger(index) ||
      index < 0 || index >= sources.length || sources.some((source: string) => source.length === 0)) {
      return false;
    }
    try { this.leaseId = ImmersiveSurfaces.acquireDark(); } catch { return false; }
    const bySource: Map<string, StarwardViewerImage> = new Map<string, StarwardViewerImage>();
    this.images = sources.map((source: string) => {
      const existing: StarwardViewerImage | undefined = bySource.get(source);
      if (existing !== undefined) { return existing; }
      const image: StarwardViewerImage = new StarwardViewerImage(source);
      bySource.set(source, image);
      return image;
    });
    this.sessionId++;
    this.index = index;
    this.ownerCurrent = ownerCurrent;
    this.onClosed = onClosed;
    this.visible = true;
    this.preparePages();
    return true;
  }

  active(): boolean { return this.visible && !this.closing && this.ownerCurrent(); }

  validateOwner(): void {
    if ((this.visible || this.closing) && !this.ownerCurrent()) { this.close(this.sessionId, true); }
  }

  close(sessionId: number, invalidOwner: boolean = false): void {
    if (sessionId !== this.sessionId || (!this.visible && !this.closing)) { return; }
    this.closing = true;
    this.visible = false;
    this.retained.forEach((image: StarwardViewerImage) => image.cancel());
    if (invalidOwner) { this.clearContent(); }
  }

  disappeared(sessionId: number): void {
    if (sessionId !== this.sessionId || (!this.visible && !this.closing)) { return; }
    const onClosed = this.onClosed;
    this.visible = false;
    this.clearContent();
    this.closing = false;
    onClosed?.();
  }

  private clearContent(): void {
    this.images = [];
    this.index = 0;
    this.ownerCurrent = () => false;
    this.onClosed = undefined;
    this.reset();
    this.retained.forEach((image: StarwardViewerImage) => image.release());
    this.retained.clear();
    const lease: number = this.leaseId;
    this.leaseId = 0;
    if (lease > 0) { ImmersiveSurfaces.releaseDark(lease); }
  }

  reset(): void { this.zoom = 1; this.x = 0; this.y = 0; }

  select(index: number, sessionId: number): void {
    if (sessionId !== this.sessionId || !this.active() || !Number.isInteger(index) ||
      index < 0 || index >= this.images.length || index === this.index) {
      return;
    }
    this.reset();
    this.index = index;
    this.preparePages();
  }

  retry(sessionId: number): void {
    const selected: StarwardViewerImage | undefined = this.images[this.index];
    if (sessionId === this.sessionId && this.active() && selected?.loadState === 'failed') {
      this.prepare(selected, true);
    }
  }

  private preparePages(): void {
    const selected: StarwardViewerImage = this.images[this.index];
    const nearby: Set<StarwardViewerImage> =
      new Set<StarwardViewerImage>(this.images.slice(Math.max(0, this.index - 1), this.index + 2));
    this.retained.forEach((image: StarwardViewerImage) => {
      if (!nearby.has(image)) { image.release(); }
    });
    this.retained = nearby;
    this.prepare(selected, true);
    nearby.forEach((image: StarwardViewerImage) => {
      if (image !== selected) { this.prepare(image, false); }
    });
  }

  private prepare(image: StarwardViewerImage, retry: boolean): void {
    const sessionId: number = this.sessionId;
    void image.prepare(this.imageCache, () => this.active() && this.sessionId === sessionId && this.retained.has(image),
      retry, (state: string, cacheHit: boolean) => {
        if (this.images[this.index] === image && AppEnvironment.endpoint.length > 0 && AppEnvironment.probeTls) {
          hilog.info(0x0000, 'StarwardViewerImage', '%{public}s', JSON.stringify({
            sessionId: sessionId, index: this.index, state: state, cacheHit: cacheHit
          }));
        }
      });
  }
}
