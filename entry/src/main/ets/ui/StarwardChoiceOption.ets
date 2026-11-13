import { hilog } from '@kit.PerformanceAnalysisKit';
import { curves, UIUtils } from '@kit.ArkUI';
import { AppEnvironment } from '../platform/AppEnvironment';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { QuestionImageFailure, QuestionImageLoader, QuestionImageResult } from '../platform/QuestionImageLoader';

/** The platform owns Radio selection; its content modifier supplies the brand layout. */
class ChoiceRadioStyle implements ContentModifier<RadioConfiguration> {
  text: string;
  nodeId: string;
  reducedMotion: boolean;

  constructor(text: string, nodeId: string, reducedMotion: boolean) {
    this.text = text;
    this.nodeId = nodeId;
    this.reducedMotion = reducedMotion;
  }

  applyContent(): WrappedBuilder<[RadioConfiguration]> { return wrapBuilder(choiceRadioContent); }
}

@Builder
function choiceRadioContent(config: RadioConfiguration) {
  Row() {
    Row() {
      Text(config.value).id((config.contentModifier as ChoiceRadioStyle).nodeId + '-key')
        .width(28).height(28).textAlign(TextAlign.Center).fontSize(16).fontWeight(FontWeight.Bold)
        .fontColor(config.checked ? $r('app.color.on_accent') : $r('app.color.accent_text'))
        .backgroundColor(config.checked ? $r('app.color.accent') : Color.Transparent)
        .border({ width: 1, color: config.checked ? $r('app.color.accent') : $r('app.color.accent_border') })
        .rotate({ angle: config.checked ? -4 : 0 })
        .scale({ x: config.checked ? 1.08 : 1, y: config.checked ? 1.08 : 1 })
        .animation({ duration: (config.contentModifier as ChoiceRadioStyle).reducedMotion ? 0 : 520,
          curve: curves.cubicBezierCurve(0.22, 0.78, 0.18, 1) })
    }.width(40).flexShrink(0)
    Text((config.contentModifier as ChoiceRadioStyle).text)
      .id((config.contentModifier as ChoiceRadioStyle).nodeId + '-text').layoutWeight(1)
      .fontSize(16).fontColor(config.checked ? $r('app.color.strong') : $r('app.color.text'))
  }.id((config.contentModifier as ChoiceRadioStyle).nodeId + '-header')
    .width('100%').constraintSize({ minHeight: 58 }).padding({ top: 8, bottom: 8, left: 14, right: 14 })
    .alignItems(VerticalAlign.Center).enabled(config.enabled)
    .onClick(() => { if (config.enabled) { config.triggerChange(true); } })
}

/** One option retains its Radio and its independently owned thumbnail across selection and Refresh. */
@ComponentV2
export struct StarwardChoiceOption {
  @Require @Param optionKey: string;
  @Require @Param text: string;
  @Require @Param group: string;
  @Require @Param radioId: string;
  @Require @Param cardId: string;
  @Require @Param imageId: string;
  @Require @Param ownerKey: string;
  @Require @Param ownerIsCurrent: (key: string) => boolean;
  @Require @Param imageCache: QuestionImageCache;
  @Param imageSource: string = '';
  @Param selected: boolean = false;
  @Param editable: boolean = false;
  @Param reducedMotion: boolean = true;
  @Event chosen: () => void = () => {};
  @Event opened: () => void = () => {};
  @Local private image: QuestionImageResult | undefined = undefined;
  @Local private imageState: string = 'idle';
  @Local private frameWidth: number = 0;
  @Local private frameHeight: number = 0;
  @Local private motionX: number = 0;
  @Local private motionScale: number = 1;
  private readonly loader: QuestionImageLoader = new QuestionImageLoader();
  private revision: number = 0;
  private motionRevision: number = 0;
  private motionTimer: number = -1;
  private motionSelected: boolean = false;
  private mounted: boolean = false;

  aboutToAppear(): void {
    this.mounted = true;
    this.motionSelected = this.selected;
    this.motionX = this.selected ? 6 : 0;
    this.motionScale = this.selected ? 1.006 : 1;
    this.loadImage();
  }

  @Monitor('selected', 'reducedMotion')
  selectionChanged(): void {
    clearTimeout(this.motionTimer);
    const revision: number = ++this.motionRevision;
    const changedSelection: boolean = this.selected !== this.motionSelected;
    this.motionSelected = this.selected;
    this.motionTimer = setTimeout(() => {
      this.motionTimer = -1;
      if (!this.mounted || revision !== this.motionRevision) { return; }
      const context = this.getUIContext();
      if (this.reducedMotion || !changedSelection) {
        context.animateTo({ duration: 0 }, () => this.setMotion(this.selected ? 6 : 0, this.selected ? 1.006 : 1));
      } else if (!this.selected) {
        context.animateTo({ duration: 520, curve: curves.cubicBezierCurve(0.22, 0.78, 0.18, 1) },
          () => this.setMotion(0, 1));
      } else {
        context.animateTo({ duration: 0 }, () => this.setMotion(0, 1));
        const curve = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
        context.keyframeAnimateTo({ iterations: 1 }, [
          { duration: 260, curve, event: () => this.setMotion(9, 1.014) },
          { duration: 360, curve, event: () => this.setMotion(6, 1.006) }
        ]);
      }
    }, 0);
  }

  private setMotion(x: number, scale: number): void {
    UIUtils.applySync(() => {
      this.motionX = x;
      this.motionScale = scale;
    });
  }

  @Monitor('imageSource', 'ownerKey')
  imageChanged(): void { this.loadImage(); }

  aboutToDisappear(): void {
    this.mounted = false;
    this.revision++;
    this.motionRevision++;
    clearTimeout(this.motionTimer);
    this.loader.cancel();
    const previous: QuestionImageResult | undefined = this.image;
    this.image = undefined;
    this.imageState = 'idle';
    previous?.release();
  }

  private current(revision: number, owner: string, source: string): boolean {
    return this.mounted && revision === this.revision && owner === this.ownerKey && source === this.imageSource &&
      this.ownerIsCurrent(owner);
  }

  private record(state: string, httpStatus: number, value?: QuestionImageResult, cacheHit: boolean = false): void {
    if (AppEnvironment.endpoint.length > 0 && AppEnvironment.probeTls) {
      hilog.info(0x0000, 'StarwardQuestionImage', '%{public}s', JSON.stringify({
        slot: this.imageId, state: state, httpStatus: httpStatus, cacheHit: cacheHit,
        naturalWidthPx: value?.naturalWidthPx || 0, naturalHeightPx: value?.naturalHeightPx || 0,
        decodedWidthPx: value?.decodedWidthPx || 0, decodedHeightPx: value?.decodedHeightPx || 0
      }));
    }
  }

  private async loadImage(): Promise<void> {
    const revision: number = ++this.revision;
    const owner: string = this.ownerKey;
    const source: string = this.imageSource;
    this.loader.cancel();
    const previous: QuestionImageResult | undefined = this.image;
    this.image = undefined;
    this.imageState = 'idle';
    previous?.release();
    if (!this.current(revision, owner, source) || source.length === 0) { return; }
    const cached: QuestionImageResult | undefined = this.imageCache.acquire(source);
    if (cached !== undefined) {
      this.image = cached;
      this.imageState = 'ready';
      this.record('ready', 0, cached, true);
      return;
    }
    const cacheVersion: number = this.imageCache.version();
    this.imageState = 'loading';
    this.record('loading', 0);
    try {
      const value: QuestionImageResult = await this.loader.load(source);
      if (!this.current(revision, owner, source)) { await value.release(); return; }
      this.imageCache.remember(source, value, cacheVersion);
      this.image = value;
      this.imageState = 'ready';
      this.record('ready', 200, value);
    } catch (error) {
      if (this.current(revision, owner, source) &&
        !(error instanceof QuestionImageFailure && error.cancelled)) {
        this.imageState = 'failed';
        this.record('failed', error instanceof QuestionImageFailure ? error.httpStatus : 0);
      }
    }
  }

  @Builder
  thumbnail() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.image !== undefined && this.imageState === 'ready') {
        // Keep photo pixels outside the native Button's disabled-opacity layer.
        // The sibling Button still owns the entire thumbnail's interaction.
        Image(this.image.pixels).id(this.imageId + '-pixels').width('100%').height(129)
          .objectFit(ImageFit.Cover).draggable(false).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        Button({ type: ButtonType.Normal }) {
          Column() {}.width('100%').height(129).accessibilityLevel('no')
        }.id(this.imageId + '-open').width('100%').height(129).padding(0).borderRadius(0)
          .backgroundColor(Color.Transparent).enabled(this.editable)
          .accessibilityText(`查看选项 ${this.optionKey} 图片`).onClick(() => {
            if (this.editable && this.imageState === 'ready' && this.image !== undefined && this.ownerIsCurrent(this.ownerKey)) {
              this.opened();
            }
          })
      } else if (this.imageState === 'loading') {
        LoadingProgress().id(this.imageId + '-loading').width(24).height(24).align(Alignment.Center)
          .color($r('app.color.accent')).enableLoading(!this.reducedMotion).accessibilityText('正在载入题图')
      } else if (this.imageState === 'failed') {
        Column({ space: 4 }) {
          Text('图片加载失败').id(this.imageId + '-error').fontSize(13).lineHeight('22.1fp')
            .fontColor($r('app.color.muted'))
          Button('重新加载', { type: ButtonType.Capsule }).id(this.imageId + '-retry')
            .constraintSize({ minHeight: 44, minWidth: 88 }).fontSize(13)
            .fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
            .enabled(this.editable).accessibilityText(`重新加载选项 ${this.optionKey} 图片`)
            .onClick(() => {
              if (this.editable && this.imageState === 'failed' && this.ownerIsCurrent(this.ownerKey)) { this.loadImage(); }
            })
        }.width('100%').align(Alignment.Center)
      }
    }.id(this.imageId + '-frame').width('100%').height(130).backgroundColor($r('app.color.media_surface'))
      .border({ width: { top: 1, left: 0, right: 0, bottom: 0 }, color: $r('app.color.border_strong') })
  }

  build() {
    Column() {
      if (this.frameWidth > 2 && this.frameHeight > 2) {
        Column() {}.id(this.radioId + '-glow').width(this.frameWidth - 2).height(this.frameHeight - 2)
          .radialGradient({ center: ['8%', '50%'],
            radius: Math.sqrt(Math.pow((this.frameWidth - 2) * 0.92, 2) + Math.pow((this.frameHeight - 2) * 0.5, 2)),
            colors: [[$r('app.color.accent'), 0], [Color.Transparent, 0.62]] })
          .opacity(this.selected ? 0.24 : 0).position({ x: 1, y: 1 })
          .animation({ duration: this.reducedMotion ? 0 : 420, curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) })
          .translate({ x: this.selected ? 0 : -0.12 * this.frameWidth })
          .scale({ x: this.selected ? 1 : 0.72, y: 1 })
          .animation({ duration: this.reducedMotion ? 0 : 680, curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) })
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      }
      Radio({ value: this.optionKey, group: this.group }).id(this.radioId).checked(this.selected)
        .contentModifier(new ChoiceRadioStyle(this.text, this.radioId, this.reducedMotion))
        .width('100%').constraintSize({ minHeight: 58 }).margin(0).padding(0).enabled(this.editable)
        .accessibilityText(`${this.optionKey} ${this.text}`).onChange((checked: boolean) => {
          if (checked && this.editable) { this.chosen(); }
        })
      Rect().id(this.radioId + '-rail').width(3).height(Math.max(0, this.frameHeight - 2))
        .fill(this.selected ? $r('app.color.accent') : Color.Transparent).position({ x: 1, y: 1 })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      // The media surface covers the rail below the label, like the Web inset line.
      // Its Button is independent of the Radio selection.
      if (this.imageSource.length > 0) { this.thumbnail(); }
    }.id(this.cardId).width('100%').alignItems(HorizontalAlign.Start)
      .backgroundColor(this.selected ? $r('app.color.accent_faint') : Color.Transparent)
      .border({ width: 1, color: this.selected ? $r('app.color.accent') : $r('app.color.border_strong'), radius: 0 })
      .shadow({ radius: this.selected ? 23 : 0, offsetY: 15,
        color: this.selected ? $r('app.color.choice_shadow') : Color.Transparent })
      .animation({ duration: this.reducedMotion ? 0 : 480, curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) })
      .clip(true).translate({ x: this.motionX }).scale({ x: this.motionScale, y: this.motionScale })
      .onAreaChange((_previous: Area, current: Area) => {
        const width: number = Number(current.width);
        const height: number = Number(current.height);
        if (Number.isFinite(width) && width > 0 && width !== this.frameWidth) { this.frameWidth = width; }
        if (Number.isFinite(height) && height > 0 && height !== this.frameHeight) { this.frameHeight = height; }
      })
  }
}
