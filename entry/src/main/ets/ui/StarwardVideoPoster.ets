import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppEnvironment } from '../platform/AppEnvironment';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { QuestionImageFailure, QuestionImageLoader, QuestionImageResult } from '../platform/QuestionImageLoader';

/** A playable media surface even when the optional poster has not loaded. */
@ComponentV2
export struct StarwardVideoPoster {
  @Require @Param source: string;
  @Require @Param ownerKey: string;
  @Require @Param ownerIsCurrent: (key: string) => boolean;
  @Require @Param imageCache: QuestionImageCache;
  @Require @Param nodeId: string;
  @Require @Param playLabel: string;
  @Param option: boolean = false;
  @Param active: boolean = true;
  @Param playable: boolean = true;
  @Param maxHeight: number = 340;
  @Event play: () => void = () => {};
  @Local private poster: QuestionImageResult | undefined = undefined;
  @Local private widthVp: number = 0;
  private readonly loader: QuestionImageLoader = new QuestionImageLoader();
  private revision: number = 0;
  private appeared: boolean = false;

  aboutToAppear(): void {
    this.appeared = true;
    this.load();
  }

  aboutToDisappear(): void {
    this.appeared = false;
    this.clear();
  }

  @Monitor('source', 'ownerKey', 'active')
  inputsChanged(update: IMonitor): void {
    if (this.poster === undefined || update.dirty.includes('source') || update.dirty.includes('ownerKey')) {
      this.load();
    }
  }

  private clear(): void {
    this.revision++;
    this.loader.cancel();
    const previous: QuestionImageResult | undefined = this.poster;
    this.poster = undefined;
    previous?.release();
  }

  private current(revision: number, owner: string, source: string): boolean {
    return this.appeared && this.revision === revision && this.ownerKey === owner && this.source === source &&
      this.ownerIsCurrent(owner);
  }

  private record(state: string, status: number, value?: QuestionImageResult, cacheHit: boolean = false): void {
    if (this.active && AppEnvironment.endpoint.length > 0 && AppEnvironment.probeTls) {
      hilog.info(0x0000, 'StarwardQuestionImage', '%{public}s', JSON.stringify({
        slot: this.nodeId, state, httpStatus: status, cacheHit,
        naturalWidthPx: value?.naturalWidthPx || 0, naturalHeightPx: value?.naturalHeightPx || 0,
        decodedWidthPx: value?.decodedWidthPx || 0, decodedHeightPx: value?.decodedHeightPx || 0
      }));
    }
  }

  private async load(): Promise<void> {
    this.clear();
    const revision: number = this.revision;
    const owner: string = this.ownerKey;
    const source: string = this.source;
    if (source.length === 0 || !this.current(revision, owner, source)) { return; }
    const cached: QuestionImageResult | undefined = this.imageCache.acquire(source);
    if (cached !== undefined) {
      this.poster = cached;
      this.record('ready', 0, cached, true);
      return;
    }
    if (!this.active) { return; }
    const version: number = this.imageCache.version();
    this.record('loading', 0);
    try {
      const value: QuestionImageResult = await this.loader.load(source);
      if (!this.active || !this.current(revision, owner, source)) { await value.release(); return; }
      this.imageCache.remember(source, value, version);
      this.poster = value;
      this.record('ready', 200, value);
    } catch (error) {
      if (this.current(revision, owner, source) && !(error instanceof QuestionImageFailure && error.cancelled)) {
        this.record('failed', error instanceof QuestionImageFailure ? error.httpStatus : 0);
      }
    }
  }

  private posterHeight(): number {
    if (this.option) { return 129; }
    return this.poster === undefined ? 180 : Math.min(this.maxHeight,
      Math.max(0, this.widthVp - 2) * this.poster.naturalHeightPx / this.poster.naturalWidthPx);
  }

  private surfaceHeight(): number {
    return this.option ? 130 : this.poster === undefined ? 182 : Math.max(180, this.posterHeight() + 2);
  }

  @Builder
  badge() {
    Stack() {
      Circle().width(this.option ? 48 : 72).height(this.option ? 48 : 72).fill($r('app.color.accent_faint'))
      Stack() {
        SymbolGlyph($r('sys.symbol.play_fill')).fontSize('16vp').fontColor([$r('app.color.on_accent')])
      }.width(this.option ? 34 : 58).height(this.option ? 34 : 58)
        .backgroundColor($r('app.color.accent')).borderRadius(this.option ? 17 : 29)
        .shadow({ radius: 18, color: $r('app.color.accent_soft') })
    }.hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.poster !== undefined) {
        Image(this.poster.pixels).id(this.nodeId + '-pixels').width('100%').height(this.posterHeight())
          .objectFit(this.option || this.maxHeight > 340 ? ImageFit.Cover : ImageFit.Contain)
          .draggable(false).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        this.badge()
      } else {
        Column({ space: 4 }) {
          this.badge()
          Text(this.option ? '播放影像' : '影像记录').id(this.nodeId + '-placeholder')
            .fontSize(16).fontColor(this.option ? $r('app.color.accent_text') : $r('app.color.muted'))
        }.hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      }
      Button({ type: ButtonType.Normal }) {
        Column() {}.width('100%').height(this.surfaceHeight()).accessibilityLevel('no')
      }.id(this.nodeId + '-open').width('100%').height(this.surfaceHeight()).padding(0).borderRadius(0)
        .backgroundColor(Color.Transparent).enabled(this.active && this.playable)
        .accessibilityText(this.playLabel).onClick(() => {
          if (this.active && this.playable && this.ownerIsCurrent(this.ownerKey)) { this.play(); }
        })
    }.id(this.nodeId + '-frame').width('100%').height(this.surfaceHeight())
      .backgroundColor($r('app.color.media_surface'))
      .radialGradient({ center: ['50%', '50%'], radius: this.widthVp * 0.35,
        colors: [[$r('app.color.accent_faint'), 0], [Color.Transparent, 1]] })
      .border({ width: { top: 1, bottom: this.option ? 0 : 1, left: this.option ? 0 : 1, right: this.option ? 0 : 1 },
        color: $r('app.color.border_strong') }).clip(true)
      .onAreaChange((_previous: Area, current: Area) => {
        const width: number = Number(current.width);
        if (Number.isFinite(width) && width > 2 && width !== this.widthVp) { this.widthVp = width; }
      })
  }
}
