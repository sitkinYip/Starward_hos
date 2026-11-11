import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppEnvironment } from '../platform/AppEnvironment';
import { QuestionImageFailure, QuestionImageLoader, QuestionImageResult } from '../platform/QuestionImageLoader';

async function releaseImage(value: QuestionImageResult | undefined): Promise<void> {
  if (value !== undefined) {
    try { await value.pixels.release(); } catch { /* Already unavailable; never log source URLs. */ }
  }
}

/** One mounted image owns one decoder result. No answer state is held here. */
@ComponentV2
struct QuestionImageCell {
  @Require @Param source: string;
  @Require @Param ownerKey: string;
  @Require @Param ownerIsCurrent: (key: string) => boolean;
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

  @Monitor('source', 'ownerKey')
  sourceChanged(): void { this.load(); }

  aboutToDisappear(): void {
    this.mounted = false;
    this.generation++;
    this.loader.cancel();
    const previous: QuestionImageResult | undefined = this.value;
    this.value = undefined;
    this.state = 'idle';
    releaseImage(previous);
  }

  private current(generation: number, owner: string, source: string): boolean {
    return this.mounted && generation === this.generation && owner === this.ownerKey && source === this.source &&
      this.ownerIsCurrent(owner);
  }

  private record(state: string, httpStatus: number, value?: QuestionImageResult): void {
    if (AppEnvironment.endpoint.length > 0 && AppEnvironment.probeTls) {
      hilog.info(0x0000, 'StarwardQuestionImage', '%{public}s', JSON.stringify({
        slot: this.imageId, state: state, httpStatus: httpStatus,
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
    await releaseImage(previous);
    if (!this.current(generation, owner, source) || source.length === 0) {
      return;
    }
    this.state = 'loading';
    this.record('loading', 0);
    try {
      const value: QuestionImageResult = await this.loader.load(source, 2048);
      if (!this.current(generation, owner, source)) {
        await releaseImage(value);
        return;
      }
      this.value = value;
      this.state = 'ready';
      this.record('ready', 200, value);
    } catch (error) {
      if (this.current(generation, owner, source) &&
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
            if (this.state === 'ready' && this.value !== undefined && this.ownerIsCurrent(this.ownerKey)) { this.opened(); }
          })
      } else if (this.state === 'loading') {
        LoadingProgress().id(this.imageId + '-loading').width(24).height(24)
          .color($r('app.color.accent')).enableLoading(!this.reducedMotion).accessibilityText('正在载入题图')
      } else if (this.state === 'failed') {
        Column({ space: 4 }) {
          Text('图片加载失败').id(this.imageId + '-error').fontSize(13).lineHeight('22.1fp')
            .fontColor($r('app.color.muted'))
          Button('重新加载', { type: ButtonType.Capsule }).id(this.imageId + '-retry')
            .constraintSize({ minHeight: 44, minWidth: 88 }).fontSize(13)
            .fontColor($r('app.color.accent_text')).backgroundColor(Color.Transparent)
            .onClick(() => { if (this.state === 'failed') { this.load(); } })
        }.width('100%').alignItems(HorizontalAlign.Start)
      }
    }.id(this.imageId).width(this.cellWidth).constraintSize({ minHeight: 44 })
      .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
  }
}

/** Native image layout and ready-image triggers, matching the Web natural-size gallery. */
@ComponentV2
export struct StarwardQuestionImages {
  @Require @Param sources: string[];
  @Require @Param ownerKey: string;
  @Require @Param ownerIsCurrent: (key: string) => boolean;
  @Param groupId: string = 'question-images';
  @Param imageLabel: string = '题图';
  @Param maxHeight: number = 340;
  @Param reducedMotion: boolean = true;
  @Event opened: (index: number) => void = () => {};
  @Local private contentWidth: number = 0;

  private columns(): number {
    return Math.min(this.sources.length, Math.max(1, Math.floor((this.contentWidth + 10) / 160)));
  }

  private cellWidth(): number {
    return this.columns() > 0 ? (this.contentWidth - (this.columns() - 1) * 10) / this.columns() : 0;
  }

  private rows(): number[] {
    const rows: number[] = [];
    for (let start: number = 0; start < this.sources.length; start += Math.max(1, this.columns())) { rows.push(start); }
    return rows;
  }

  private rowSources(start: number): string[] { return this.sources.slice(start, start + this.columns()); }

  build() {
    Column({ space: 10 }) {
      if (this.contentWidth > 2) {
        ForEach(this.rows(), (start: number) => {
          Row({ space: 10 }) {
            ForEach(this.rowSources(start), (source: string, index: number) => {
              QuestionImageCell({ source: source, ownerKey: this.ownerKey, ownerIsCurrent: this.ownerIsCurrent,
                cellWidth: this.cellWidth(), maxHeight: this.maxHeight, imageId: `${this.groupId}-${start + index}`,
                imageLabel: `${this.imageLabel} ${start + index + 1}，共 ${this.sources.length} 张`,
                reducedMotion: this.reducedMotion,
                opened: () => this.opened(start + index) })
            }, (source: string) => `${this.ownerKey}:${source}`)
          }.width('100%').alignItems(VerticalAlign.Top)
        }, (start: number) => `${this.columns()}:${start}`)
      }
    }.id(this.groupId).width('100%').alignItems(HorizontalAlign.Start)
      .constraintSize({ minHeight: this.contentWidth > 2 ? 0 : 24 })
      .onAreaChange((_previous: Area, current: Area) => {
        const width: number = Number(current.width);
        if (Number.isFinite(width) && width > 0 && width !== this.contentWidth) { this.contentWidth = width; }
      })
  }
}
