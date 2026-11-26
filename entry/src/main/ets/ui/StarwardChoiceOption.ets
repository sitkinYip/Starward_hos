import { hilog } from '@kit.PerformanceAnalysisKit';
import { curves } from '@kit.ArkUI';
import { AppEnvironment } from '../platform/AppEnvironment';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { QuestionImageFailure, QuestionImageLoader, QuestionImageResult } from '../platform/QuestionImageLoader';
import { StarwardVideoPoster } from './StarwardVideoPoster';
import { STARWARD_RADIUS_BADGE, STARWARD_RADIUS_CONTROL } from './StarwardRadii';

/** The platform owns Radio selection; its content modifier supplies the brand layout. */
class ChoiceRadioStyle implements ContentModifier<RadioConfiguration> {
  text: string;
  nodeId: string;
  reducedMotion: boolean;
  reselect: () => void;

  constructor(text: string, nodeId: string, reducedMotion: boolean, reselect: () => void) {
    this.text = text;
    this.nodeId = nodeId;
    this.reducedMotion = reducedMotion;
    this.reselect = reselect;
  }

  applyContent(): WrappedBuilder<[RadioConfiguration]> { return wrapBuilder(choiceRadioContent); }
}

@Builder
function choiceRadioContent(config: RadioConfiguration) {
  Row() {
    Row() {
      Text(config.value).id((config.contentModifier as ChoiceRadioStyle).nodeId + '-key')
        .width(28).height(28).textAlign(TextAlign.Center).fontSize(13).fontWeight(FontWeight.Bold)
        .fontColor(config.checked ? $r('app.color.on_accent') : $r('app.color.accent_text'))
        .backgroundColor(config.checked ? $r('app.color.accent') : $r('app.color.accent_soft'))
        .border({ width: 1, radius: STARWARD_RADIUS_BADGE,
          color: config.checked ? $r('app.color.accent') : $r('app.color.accent_border') })
        .scale({ x: config.checked ? 1.04 : 1, y: config.checked ? 1.04 : 1 })
        .animation({ duration: (config.contentModifier as ChoiceRadioStyle).reducedMotion ? 0 : 240,
          curve: curves.cubicBezierCurve(0.34, 1.38, 0.64, 1) })
    }.width(38).flexShrink(0)
    Text((config.contentModifier as ChoiceRadioStyle).text)
      .id((config.contentModifier as ChoiceRadioStyle).nodeId + '-text').layoutWeight(1)
      .fontSize(16).fontColor(config.checked ? $r('app.color.strong') : $r('app.color.text'))
  }.id((config.contentModifier as ChoiceRadioStyle).nodeId + '-header')
    .width('100%').constraintSize({ minHeight: 54 }).padding({ top: 8, bottom: 8, left: 14, right: 14 })
    .alignItems(VerticalAlign.Center).enabled(config.enabled)
    .onClick(() => {
      if (!config.enabled) { return; }
      if (config.checked) { (config.contentModifier as ChoiceRadioStyle).reselect(); }
      else { config.triggerChange(true); }
    })
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
  @Require @Param videoId: string;
  @Require @Param ownerKey: string;
  @Require @Param ownerIsCurrent: (key: string) => boolean;
  @Require @Param imageCache: QuestionImageCache;
  @Param imageSource: string = '';
  @Param videoSource: string = '';
  @Param videoPlayable: boolean = false;
  @Param selected: boolean = false;
  @Param editable: boolean = false;
  @Param mediaEnabled: boolean | undefined = undefined;
  @Param reducedMotion: boolean = true;
  @Event chosen: () => void = () => {};
  @Event opened: () => void = () => {};
  @Event videoOpened: () => void = () => {};
  @Local private image: QuestionImageResult | undefined = undefined;
  @Local private imageState: string = 'idle';
  private readonly loader: QuestionImageLoader = new QuestionImageLoader();
  private revision: number = 0;
  private mounted: boolean = false;

  aboutToAppear(): void {
    this.mounted = true;
    this.loadImage();
  }

  private canOpenMedia(): boolean {
    return this.mediaEnabled ?? this.editable;
  }

  @Monitor('imageSource', 'ownerKey', 'videoSource')
  imageChanged(): void { this.loadImage(); }

  aboutToDisappear(): void {
    this.mounted = false;
    this.revision++;
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
    if (!this.current(revision, owner, source) || source.length === 0 || this.videoSource.length > 0) { return; }
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
          .backgroundColor(Color.Transparent).enabled(this.canOpenMedia())
          .accessibilityText(`查看选项 ${this.optionKey} 图片`).onClick(() => {
            if (this.canOpenMedia() && this.imageState === 'ready' && this.image !== undefined &&
              this.ownerIsCurrent(this.ownerKey)) {
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
            .enabled(this.canOpenMedia()).accessibilityText(`重新加载选项 ${this.optionKey} 图片`)
            .onClick(() => {
              if (this.canOpenMedia() && this.imageState === 'failed' && this.ownerIsCurrent(this.ownerKey)) {
                this.loadImage();
              }
            })
        }.width('100%').align(Alignment.Center)
      }
    }.id(this.imageId + '-frame').width('100%').height(130).backgroundColor($r('app.color.media_surface'))
      .border({ width: { top: 1, left: 0, right: 0, bottom: 0 }, color: $r('app.color.border_strong') })
  }

  build() {
    Column() {
      Radio({ value: this.optionKey, group: this.group }).id(this.radioId).checked(this.selected)
        .contentModifier(new ChoiceRadioStyle(this.text, this.radioId, this.reducedMotion, () => this.chosen()))
        .width('100%').constraintSize({ minHeight: 54 }).margin(0).padding(0).enabled(this.editable)
        .accessibilityText(`${this.optionKey} ${this.text}`).onChange((checked: boolean) => {
          if (checked && this.editable) { this.chosen(); }
        })
      // The media action stays available independently of the Radio selection.
      if (this.videoSource.length > 0) {
        StarwardVideoPoster({ source: this.imageSource, ownerKey: this.ownerKey, ownerIsCurrent: this.ownerIsCurrent,
          imageCache: this.imageCache, nodeId: this.videoId, playLabel: `播放选项 ${this.optionKey} 视频`,
          option: true, playable: this.canOpenMedia() && this.videoPlayable, play: () => this.videoOpened() })
      } else if (this.imageSource.length > 0) {
        this.thumbnail()
      }
    }.id(this.cardId).width('100%').alignItems(HorizontalAlign.Start)
      .backgroundColor(this.selected ? $r('app.color.accent_soft') : $r('app.color.input'))
      .border({ width: 1, color: this.selected ? $r('app.color.accent') : $r('app.color.border_strong'),
        radius: STARWARD_RADIUS_CONTROL })
      .animation({ duration: this.reducedMotion ? 0 : 240, curve: Curve.EaseOut })
      .clip(true)
  }
}
