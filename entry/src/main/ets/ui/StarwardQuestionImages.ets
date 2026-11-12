import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppEnvironment } from '../platform/AppEnvironment';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { QuestionImageFailure, QuestionImageLoader, QuestionImageResult } from '../platform/QuestionImageLoader';

/** One mounted image holds a display reference and owns its pending load. */
@ComponentV2
struct QuestionImageCell {
  @Require @Param source: string;
  @Require @Param ownerKey: string;
  @Require @Param ownerIsCurrent: (key: string) => boolean;
  @Require @Param imageCache: QuestionImageCache;
  @Param active: boolean = true;
  @Param cellWidth: number = 0;
  @Param maxHeight: number = 340;
  @Param imageId: string = '';
  @Param imageLabel: string = '题图';
  @Param reducedMotion: boolean = true;
  @Event opened: () => void = () => {};
  @Local private value: QuestionImageResult | undefined = undefined;
  @Local private state: string = 'idle';
  private readonly loader: QuestionImageLoader = new QuestionImageLoader();
  private generation: number = 0;
  private mounted: boolean = false;

  aboutToAppear(): void {
    this.mounted = true;
    this.load();
  }

  @Monitor('source', 'ownerKey', 'active')
  sourceChanged(changes: IMonitor): void {
    if (this.value === undefined || changes.dirty.includes('source') || changes.dirty.includes('ownerKey')) {
      this.load();
    }
  }

  aboutToDisappear(): void {
    this.mounted = false;
    this.generation++;
    this.loader.cancel();
    const previous: QuestionImageResult | undefined = this.value;
    this.value = undefined;
    this.state = 'idle';
    previous?.release();
  }

  private current(generation: number, owner: string, source: string): boolean {
    return this.mounted && generation === this.generation && owner === this.ownerKey && source === this.source &&
      this.ownerIsCurrent(owner);
  }

  private record(state: string, httpStatus: number, value?: QuestionImageResult, cacheHit: boolean = false): void {
    if (this.active && AppEnvironment.endpoint.length > 0 && AppEnvironment.probeTls) {
      hilog.info(0x0000, 'StarwardQuestionImage', '%{public}s', JSON.stringify({
        slot: this.imageId, state: state, httpStatus: httpStatus, cacheHit: cacheHit,
        naturalWidthPx: value?.naturalWidthPx || 0, naturalHeightPx: value?.naturalHeightPx || 0,
        decodedWidthPx: value?.decodedWidthPx || 0, decodedHeightPx: value?.decodedHeightPx || 0
      }));
    }
  }

  private async load(): Promise<void> {
    const generation: number = ++this.generation;
    const owner: string = this.ownerKey;
    const source: string = this.source;
    this.loader.cancel();
    const previous: QuestionImageResult | undefined = this.value;
    this.value = undefined;
    this.state = 'idle';
    previous?.release();
    if (!this.current(generation, owner, source) || source.length === 0) {
      return;
    }
    const cached: QuestionImageResult | undefined = this.imageCache.acquire(source);
    if (cached !== undefined) {
      this.value = cached;
      this.state = 'ready';
      this.record('ready', 0, cached, true);
      return;
    }
    if (!this.active) { return; }
    const cacheVersion: number = this.imageCache.version();
    this.state = 'loading';
    this.record('loading', 0);
    try {
      const value: QuestionImageResult = await this.loader.load(source);
      if (!this.active || !this.current(generation, owner, source)) {
        await value.release();
        return;
      }
      this.imageCache.remember(source, value, cacheVersion);
      this.value = value;
      this.state = 'ready';
      this.record('ready', 200, value);
    } catch (error) {
      if (this.active && this.current(generation, owner, source) &&
        !(error instanceof QuestionImageFailure && error.cancelled)) {
        this.state = 'failed';
        this.record('failed', error instanceof QuestionImageFailure ? error.httpStatus : 0);
      }
    }
  }

  private imageScale(): number {
    return this.value === undefined ? 0 : Math.max(0, Math.min(1,
      (this.cellWidth - 2) / this.value.naturalWidthPx, (this.maxHeight - 2) / this.value.naturalHeightPx));
  }

  private frameWidth(): number { return (this.value?.naturalWidthPx || 0) * this.imageScale() + 2; }
  private frameHeight(): number { return (this.value?.naturalHeightPx || 0) * this.imageScale() + 2; }

  build() {
    Column() {
      if (this.value !== undefined && this.state === 'ready') {
        Button({ type: ButtonType.Normal }) {
          Stack() {
            Image(this.value.pixels).id(this.imageId + '-pixels')
              .width(this.frameWidth() - 2).height(this.frameHeight() - 2).objectFit(ImageFit.Contain)
              .draggable(false).accessibilityText(this.imageLabel)
          }.id(this.imageId + '-frame').width(this.frameWidth()).height(this.frameHeight())
            .border({ width: 1, color: $r('app.color.border_strong') })
        }.id(this.imageId + '-open').padding(0).borderRadius(0).backgroundColor(Color.Transparent)
          .width(Math.max(44, this.frameWidth())).height(Math.max(44, this.frameHeight()))
          .accessibilityText(`打开${this.imageLabel}`).onClick(() => {
            if (this.active && this.state === 'ready' && this.value !== undefined && this.ownerIsCurrent(this.ownerKey)) {
              this.opened();
            }
          })
      } else if (this.active && this.state === 'loading') {
        LoadingProgress().id(this.imageId + '-loading').width(24).height(24)
          .color($r('app.color.accent')).enableLoading(!this.reducedMotion).accessibilityText('正在载入题图')
      } else if (this.active && this.state === 'failed') {
        Column({ space: 4 }) {
          Text('图片加载失败').id(this.imageId + '-error').fontSize(13).lineHeight('22.1fp')
            .fontColor($r('app.color.muted'))
          Button('重新加载', { type: ButtonType.Capsule }).id(this.imageId + '-retry')
            .constraintSize({ minHeight: 44, minWidth: 88 }).fontSize(13)
            .fontColor($r('app.color.accent_text')).backgroundColor(Color.Transparent)
            .onClick(() => { if (this.active && this.state === 'failed') { this.load(); } })
        }.width('100%').alignItems(HorizontalAlign.Start)
      }
    }.id(this.imageId).width(this.cellWidth).constraintSize({ minHeight: this.active ? 44 : 0 })
      .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
  }
}

/** Native image layout and ready-image triggers, matching the Web natural-size gallery. */
@ComponentV2
export struct StarwardQuestionImages {
  @Require @Param sources: string[];
  @Require @Param ownerKey: string;
  @Require @Param ownerIsCurrent: (key: string) => boolean;
  @Require @Param imageCache: QuestionImageCache;
  @Param active: boolean = true;
  @Param availableWidth: number = 0;
  @Param groupId: string = 'question-images';
  @Param imageLabel: string = '题图';
  @Param maxHeight: number = 340;
  @Param reducedMotion: boolean = true;
  @Event opened: (index: number) => void = () => {};
  @Local private contentWidth: number = 0;

  private layoutWidth(): number { return this.availableWidth > 2 ? this.availableWidth : this.contentWidth; }

  private columns(): number {
    return Math.min(this.sources.length, Math.max(1, Math.floor((this.layoutWidth() + 10) / 160)));
  }

  private cellWidth(): number {
    return this.columns() > 0 ? (this.layoutWidth() - (this.columns() - 1) * 10) / this.columns() : 0;
  }

  private rows(): number[] {
    const rows: number[] = [];
    for (let start: number = 0; start < this.sources.length; start += Math.max(1, this.columns())) { rows.push(start); }
    return rows;
  }

  private rowSources(start: number): string[] { return this.sources.slice(start, start + this.columns()); }

  build() {
    Column({ space: 10 }) {
      if (this.layoutWidth() > 2) {
        ForEach(this.rows(), (start: number) => {
          Row({ space: 10 }) {
            ForEach(this.rowSources(start), (source: string, index: number) => {
              QuestionImageCell({ source: source, ownerKey: this.ownerKey, ownerIsCurrent: this.ownerIsCurrent,
                imageCache: this.imageCache, active: this.active,
                cellWidth: this.cellWidth(), maxHeight: this.maxHeight, imageId: `${this.groupId}-${start + index}`,
                imageLabel: `${this.imageLabel} ${start + index + 1}，共 ${this.sources.length} 张`,
                reducedMotion: this.reducedMotion,
                opened: () => this.opened(start + index) })
            }, (source: string) => `${this.ownerKey}:${source}`)
          }.width('100%').alignItems(VerticalAlign.Top)
        }, (start: number) => `${this.columns()}:${start}`)
      }
    }.id(this.groupId).width('100%').alignItems(HorizontalAlign.Start)
      .constraintSize({ minHeight: this.active && this.layoutWidth() <= 2 ? 24 : 0 })
      .onAreaChange((_previous: Area, current: Area) => {
        const width: number = Number(current.width);
        if (Number.isFinite(width) && width > 0 && width !== this.contentWidth) { this.contentWidth = width; }
      })
  }
}
