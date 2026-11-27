import { UIUtils, window } from '@kit.ArkUI';
import { QuestionImageResult } from '../platform/QuestionImageLoader';
import { StarwardMediaAmbient, StarwardMediaFrame } from './StarwardClueMotion';
import { StarwardImageViewerState, StarwardViewerImage } from './StarwardImageViewerState';
import { starwardMediaCoverOptions } from './StarwardMediaCover';
import { STARWARD_PAGE_TRANSITION_MS } from './StarwardMotion';

/** The stage clips Swiper pages and the selected image's zoom. */
@ComponentV2
struct StarwardImageViewer {
  @Env(ReadonlyEnvKey.WINDOW_SIZE) windowSize: window.SizeInVP;
  @Env(ReadonlyEnvKey.WINDOW_AVOID_AREA) avoidArea: window.UIEnvWindowAvoidAreaInfoVP;
  @Require @Param model: StarwardImageViewerState;
  @Param reducedMotion: boolean = true;
  @Param motionEnabled: boolean = false;
  @Local private positioned: boolean = false;
  @Local private measuredWidth: number = 0;
  @Local private measuredHeight: number = 0;
  private readonly swiper: SwiperController = new SwiperController();
  private readonly contacts: Set<number> = new Set<number>();
  private multiTouch: boolean = false;
  private panActive: boolean = false;
  private panX: number = 0;
  private panY: number = 0;
  private pinching: boolean = false;
  private pinchScale: number = 1;
  private centerX: number = 0;
  private centerY: number = 0;
  private mounted: boolean = false;
  private sessionId: number = 0;

  aboutToAppear(): void {
    this.sessionId = this.model.sessionId;
    this.positioned = this.model.index === 0;
    this.mounted = true;
  }

  aboutToDisappear(): void { this.mounted = false; this.contacts.clear(); }

  private interactive(): boolean { return this.mounted && this.sessionId === this.model.sessionId && this.model.active(); }

  @Monitor('model.index')
  imageChanged(): void { this.endImageGesture(); }

  private safeTop(): number {
    return Math.max(0, this.avoidArea.statusBar.topRect.height, this.avoidArea.cutout.topRect.height);
  }
  private safeBottom(): number {
    return Math.max(0, this.avoidArea.statusBar.bottomRect.height, this.avoidArea.cutout.bottomRect.height,
      this.avoidArea.navigationIndicator.bottomRect.height);
  }
  private safeLeft(): number {
    return Math.max(0, this.avoidArea.statusBar.leftRect.width, this.avoidArea.cutout.leftRect.width,
      this.avoidArea.navigationIndicator.leftRect.width);
  }
  private availableWidth(): number {
    return Math.max(0, this.windowSize.width - this.safeLeft() - Math.max(0,
      this.avoidArea.statusBar.rightRect.width, this.avoidArea.cutout.rightRect.width,
      this.avoidArea.navigationIndicator.rightRect.width));
  }
  private availableHeight(): number { return Math.max(0, this.windowSize.height - this.safeTop() - this.safeBottom()); }
  private panelWidth(): number { return Math.max(0, Math.min(1100, this.availableWidth() - 28)); }
  private controlsHeight(): number { return this.model.images.length > 1 ? 128 : 56; }
  private stageHeight(): number {
    return Math.max(0, Math.min(720, this.availableHeight() * 0.65, this.availableHeight() - 28 - this.controlsHeight()));
  }
  private stageWidth(): number { return this.measuredWidth > 0 ? this.measuredWidth : this.panelWidth(); }
  private actualStageHeight(): number { return this.measuredHeight > 0 ? this.measuredHeight : this.stageHeight(); }
  private imageFit(value: QuestionImageResult): number {
    return Math.max(0, Math.min(1,
      this.stageWidth() / value.naturalWidthPx, this.actualStageHeight() / value.naturalHeightPx));
  }
  private imageWidth(value: QuestionImageResult): number { return value.naturalWidthPx * this.imageFit(value); }
  private imageHeight(value: QuestionImageResult): number { return value.naturalHeightPx * this.imageFit(value); }

  private pose(zoom: number, x: number, y: number): void {
    if (!this.interactive()) { return; }
    const scale: number = Math.max(1, Math.min(4, zoom));
    const limitX: number = this.stageWidth() * (scale - 1) / 2;
    const limitY: number = this.actualStageHeight() * (scale - 1) / 2;
    this.model.zoom = scale;
    this.model.x = Math.max(-limitX, Math.min(limitX, x));
    this.model.y = Math.max(-limitY, Math.min(limitY, y));
  }

  private endImageGesture(): void { this.panActive = false; this.pinching = false; }

  private doubleTap(event: GestureEvent): void {
    const value: QuestionImageResult | undefined = this.model.images[this.model.index]?.value;
    if (!this.interactive() || this.pinching || value === undefined) { return; }
    const centerX: number = this.stageWidth() / 2;
    const centerY: number = this.actualStageHeight() / 2;
    const halfImageWidth: number = this.imageWidth(value) / 2;
    const halfImageHeight: number = this.imageHeight(value) / 2;
    const finger: FingerInfo | undefined = event.fingerInfos?.[0] ?? event.fingerList[0];
    const offsetX: number = (event.tapLocation?.x ?? finger?.localX ?? centerX) - centerX;
    const offsetY: number = (event.tapLocation?.y ?? finger?.localY ?? centerY) - centerY;
    const focusX: number = Math.max(-halfImageWidth, Math.min(halfImageWidth, offsetX));
    const focusY: number = Math.max(-halfImageHeight, Math.min(halfImageHeight, offsetY));
    const zoom: number = this.model.zoom > 1 ? 1 : 2;
    this.endImageGesture();
    this.getUIContext().animateTo({ duration: this.motionEnabled && !this.reducedMotion ? STARWARD_PAGE_TRANSITION_MS : 0,
      curve: Curve.EaseOut }, () => UIUtils.applySync(() => this.pose(zoom, (1 - zoom) * focusX, (1 - zoom) * focusY)));
  }

  private touch(event: TouchEvent): void {
    // Keep paging blocked through the last finger of a pinch. ArkUI recognizers own movement and direction.
    if (!this.interactive()) { return; }
    if (event.type === TouchType.Down) {
      if (this.contacts.size === 0) { this.multiTouch = false; }
      event.changedTouches.forEach((point: TouchObject) => this.contacts.add(point.id));
    }
    if (event.touches.length > 1 || this.contacts.size > 1) { this.multiTouch = true; }
    if (event.type === TouchType.Cancel) {
      this.contacts.clear();
      this.multiTouch = true;
      this.endImageGesture();
    }
    if (event.type === TouchType.Up) { event.changedTouches.forEach((point: TouchObject) => this.contacts.delete(point.id)); }
  }

  private pagingEnabled(): boolean {
    return this.interactive() && this.model.images.length > 1 && this.model.zoom === 1 && !this.multiTouch;
  }

  private judgeGesture(event: BaseGestureEvent, recognizer: GestureRecognizer): GestureJudgeResult {
    if (recognizer.getType() !== GestureControl.GestureType.PAN_GESTURE) { return GestureJudgeResult.CONTINUE; }
    const allowed: boolean = recognizer.isBuiltIn() ?
      this.pagingEnabled() && (event.fingerInfos?.length ?? 1) === 1 :
      this.interactive() && !this.multiTouch && this.model.zoom > 1;
    return allowed ? GestureJudgeResult.CONTINUE : GestureJudgeResult.REJECT;
  }

  private step(direction: number): void {
    const index: number = this.model.index + direction;
    if (this.interactive() && index >= 0 && index < this.model.images.length) {
      this.swiper.changeIndex(index, !this.reducedMotion);
    }
  }

  private pinchStart(event: GestureEvent): void {
    if (!this.interactive() || this.model.images[this.model.index]?.value === undefined) { return; }
    this.multiTouch = true;
    this.panActive = false;
    this.pinching = true;
    this.pinchScale = 1;
    this.centerX = event.pinchCenterX - this.stageWidth() / 2;
    this.centerY = event.pinchCenterY - this.actualStageHeight() / 2;
    this.pinchUpdate(event);
  }

  private pinchUpdate(event: GestureEvent): void {
    if (!this.pinching || !this.interactive() || !Number.isFinite(event.scale) || event.scale <= 0 ||
      !Number.isFinite(event.pinchCenterX) || !Number.isFinite(event.pinchCenterY)) { return; }
    const x: number = event.pinchCenterX - this.stageWidth() / 2;
    const y: number = event.pinchCenterY - this.actualStageHeight() / 2;
    const zoom: number = Math.max(1, Math.min(4, this.model.zoom * event.scale / this.pinchScale));
    const ratio: number = zoom / this.model.zoom;
    this.pose(zoom, this.centerX + (this.model.x - this.centerX) * ratio + x - this.centerX,
      this.centerY + (this.model.y - this.centerY) * ratio + y - this.centerY);
    this.pinchScale = event.scale;
    this.centerX = x;
    this.centerY = y;
  }

  private panStart(event: GestureEvent): void {
    if (!this.interactive() || this.multiTouch || this.model.zoom === 1) { return; }
    this.panActive = true;
    this.panX = this.model.x;
    this.panY = this.model.y;
    this.panUpdate(event);
  }

  private panUpdate(event: GestureEvent): void {
    if (this.panActive && !this.multiTouch && this.interactive() && this.model.zoom > 1) {
      this.pose(this.model.zoom, this.panX + event.offsetX, this.panY + event.offsetY);
    }
  }

  @Builder
  slide(image: StarwardViewerImage, index: number) {
    Stack() {
      if (image.value !== undefined) {
        Stack() {
          Image(image.value.pixels).id(index === this.model.index ? 'image-viewer-pixels' : '')
            .width(this.imageWidth(image.value)).height(this.imageHeight(image.value))
            .objectFit(ImageFit.Contain).draggable(false).accessibilityText(`预览图片 ${index + 1}`)
            .scale({ x: index === this.model.index ? this.model.zoom : 1,
              y: index === this.model.index ? this.model.zoom : 1, centerX: '50%', centerY: '50%' })
        }.width(this.imageWidth(image.value)).height(this.imageHeight(image.value))
          .translate({ x: index === this.model.index ? this.model.x : 0, y: index === this.model.index ? this.model.y : 0 })
      } else if (index === this.model.index) {
        if (image.loadState === 'loading') {
          LoadingProgress().id('image-viewer-loading').width(28).height(28).color($r('app.color.media_viewer_accent'))
            .enableLoading(!this.reducedMotion).accessibilityText('正在载入题图')
        } else if (image.loadState === 'failed') {
          Column({ space: 4 }) {
            Text('图片加载失败').id('image-viewer-error').fontSize(13).lineHeight('22.1fp').fontColor('#b8b7ae')
            Button('重新加载', { type: ButtonType.Capsule }).id('image-viewer-retry')
              .constraintSize({ minHeight: 44, minWidth: 88 }).fontSize(13).fontColor('#d7d3c7')
              .backgroundColor(Color.Transparent).onClick(() => this.model.retry(this.sessionId))
          }
        }
      }
    }.width('100%').height('100%').clip(true)
      .accessibilityLevel(index === this.model.index ? 'auto' : 'no-hide-descendants')
  }

  @Builder
  stage() {
    Stack() {
      Swiper(this.swiper) {
        ForEach(this.model.images, (image: StarwardViewerImage, index: number) => {
          this.slide(image, index)
        }, (_image: StarwardViewerImage, index: number) => index.toString())
      }.id('image-viewer-swiper').width('100%').height('100%').opacity(this.positioned ? 1 : 0)
        .loop(false).indicator(false).cachedCount(1)
        .effectMode(this.reducedMotion ? EdgeEffect.None : EdgeEffect.Spring)
        .duration(this.reducedMotion ? 0 : STARWARD_PAGE_TRANSITION_MS).curve(Curve.EaseOut)
        .disableSwipe(!this.interactive() || this.model.images.length < 2 || this.model.zoom > 1)
        .onContentWillScroll(() => this.pagingEnabled())
        .onChange((index: number) => {
          if (this.positioned) { this.model.select(index, this.sessionId); }
        })
        .onTouch((event: TouchEvent) => this.touch(event))
        .onGestureRecognizerJudgeBegin((event: BaseGestureEvent, recognizer: GestureRecognizer) =>
          this.judgeGesture(event, recognizer), true)
        .parallelGesture(GestureGroup(GestureMode.Parallel,
          TapGesture({ count: 2, fingers: 1, isFingerCountLimited: true, distanceThreshold: 8 })
            .onAction((event: GestureEvent) => this.doubleTap(event)),
          PinchGesture({ fingers: 2, distance: 1, isFingerCountLimited: true })
            .onActionStart((event: GestureEvent) => this.pinchStart(event))
            .onActionUpdate((event: GestureEvent) => this.pinchUpdate(event))
            .onActionEnd(() => { this.pinching = false; })
            .onActionCancel(() => this.endImageGesture()),
          PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1, isFingerCountLimited: true })
            .allowedTypes([SourceTool.Finger])
            .onActionStart((event: GestureEvent) => this.panStart(event))
            .onActionUpdate((event: GestureEvent) => this.panUpdate(event))
            .onActionEnd((event: GestureEvent) => { this.panUpdate(event); this.panActive = false; })
            .onActionCancel(() => { this.panActive = false; })
        ))
      Column().width('100%').height('100%').border({ width: 7, color: '#05ffffff' })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      Column().width('100%').height('100%').border({ width: 1, color: '#29ffebb3' })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      if (this.model.images[this.model.index]?.value !== undefined) {
        StarwardMediaFrame({ stageWidth: this.stageWidth(), stageHeight: this.actualStageHeight(),
          reducedMotion: this.reducedMotion })
      }
    }.id('image-viewer-stage').width('100%').height(this.stageHeight()).clip(true)
      .accessibilityDescription(`缩放${Math.round(this.model.zoom * 100)}%；水平偏移${this.model.x.toFixed(1)}vp；垂直偏移${this.model.y.toFixed(1)}vp`)
      .onAreaChange((_previous: Area, current: Area) => {
        const width: number = Number(current.width);
        const height: number = Number(current.height);
        if (Number.isFinite(width) && width > 0) { this.measuredWidth = width; }
        if (Number.isFinite(height) && height > 0) { this.measuredHeight = height; }
        if (!this.positioned && width > 0 && height > 0 && this.interactive()) {
          // Position once. Reapplying .index() during UI updates can reset a live Swiper.
          this.swiper.changeIndex(this.model.index, false);
          this.positioned = true;
        }
        this.pose(this.model.zoom, this.model.x, this.model.y);
      })
  }

  @Builder
  zoomControls() {
    Row({ space: 12 }) {
      Text(`${Math.round(this.model.zoom * 100)}%`).id('image-viewer-percent').fontSize(16).lineHeight(22)
        .fontColor('#d7d3c7').constraintSize({ minWidth: 40 })
      Button('复位', { type: ButtonType.Capsule }).id('image-viewer-reset').height(40)
        .constraintSize({ minWidth: 58 }).padding({ left: 14, right: 14 }).fontSize(14).fontWeight(600).fontColor('#d7d3c7')
        .backgroundColor(Color.Transparent).border({ width: 1, color: '#55574f' })
        .enabled(this.interactive()).onClick(() => {
          if (this.interactive()) { this.endImageGesture(); this.model.reset(); }
        })
      Text('双击或双指缩放 · 放大后拖动').id('image-viewer-help').fontSize(13.3333).lineHeight(19).fontColor('#b8b7ae')
    }.height(40).justifyContent(FlexAlign.Center)
  }

  @Builder
  navigation() {
    Row({ space: 16 }) {
      Button('上一张', { type: ButtonType.Capsule }).id('image-viewer-previous').height(40)
        .padding({ left: 14, right: 14 }).fontSize(14).fontWeight(600).opacity(1)
        .fontColor(this.model.index === 0 ? '#85867f' : '#d7d3c7').backgroundColor(Color.Transparent)
        .border({ width: 1, color: this.model.index === 0 ? '#3d3f39' : '#55574f' })
        .enabled(this.interactive() && this.model.index > 0)
        .onClick(() => this.step(-1))
      Text(`${this.model.index + 1} / ${this.model.images.length}`).id('image-viewer-index')
        .constraintSize({ minWidth: 58 }).textAlign(TextAlign.Center).fontSize(16).lineHeight(22).fontColor('#b8b7ae')
      Button('下一张', { type: ButtonType.Capsule }).id('image-viewer-next').height(40)
        .padding({ left: 14, right: 14 }).fontSize(14).fontWeight(600).opacity(1)
        .fontColor(this.model.index === this.model.images.length - 1 ? '#85867f' : '#d7d3c7')
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: this.model.index === this.model.images.length - 1 ? '#3d3f39' : '#55574f' })
        .enabled(this.interactive() && this.model.index < this.model.images.length - 1)
        .onClick(() => this.step(1))
    }.id('image-viewer-navigation').padding(7).border({ width: 1, color: '#6b6d654e' }).borderRadius(999)
      .backgroundColor('#db0f100d').accessibilityDescription('可左右滑动切换图片。')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Button('', { type: ButtonType.Normal }).id('image-viewer-mask').width('100%').height('100%')
        .backgroundColor('#f0050605').accessibilityText('关闭媒体预览').onClick(() => this.model.close(this.sessionId))
      StarwardMediaAmbient({
        diameter: Math.min(1180, this.availableWidth() * 1.5), motionEnabled: this.motionEnabled
      }).position({ x: this.safeLeft() + (this.availableWidth() - Math.min(1180, this.availableWidth() * 1.5)) / 2,
        y: this.safeTop() + (this.availableHeight() - Math.min(1180, this.availableWidth() * 1.5)) / 2 })
      Stack({ alignContent: Alignment.TopEnd }) {
        Column({ space: 16 }) {
          this.stage()
          this.zoomControls()
          if (this.model.images.length > 1) { this.navigation() }
        }.id('image-viewer-panel').width('100%').hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
        Button('×', { type: ButtonType.Circle }).id('image-viewer-close').width(46).height(46)
          .fontSize(28).fontWeight(600).fontColor('#f0ecdf').backgroundColor('#d110110e').border({ width: 1, color: '#55574f' })
          .accessibilityText('关闭媒体预览').defaultFocus(true).onClick(() => this.model.close(this.sessionId))
      }.width(this.panelWidth()).position({ x: this.safeLeft() + (this.availableWidth() - this.panelWidth()) / 2,
        y: this.safeTop() + Math.max(14, (this.availableHeight() - this.stageHeight() - this.controlsHeight()) / 2) })
    }.id('image-viewer').width('100%').height('100%').backgroundColor($r('app.color.media_viewer_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .accessibilityText('图片预览')
  }
}

/** The same ArkUI cover is mounted in the page or its current sheet or dialog. */
@ComponentV2
export struct StarwardImageViewerCover {
  @Require @Param model: StarwardImageViewerState;
  @Param acceptsPresentation: boolean = true;
  @Param active: boolean = true;
  @Param reducedMotion: boolean = true;

  private options(): ContentCoverOptions {
    const sessionId: number = this.model.sessionId;
    // The full-screen cover stays edge-to-edge as it settles into place.
    const transition: TransitionEffect | undefined = this.reducedMotion ? undefined : TransitionEffect.opacity(0)
      .combine(TransitionEffect.scale({ x: 1.025, y: 1.025 }))
      .animation({ duration: STARWARD_PAGE_TRANSITION_MS, curve: Curve.EaseOut });
    return starwardMediaCoverOptions(this.reducedMotion, (action: DismissContentCoverAction) => {
      this.model.close(sessionId);
      action.dismiss();
    }, () => this.model.disappeared(sessionId), transition);
  }

  @Builder
  private viewer() {
    StarwardImageViewer({ model: this.model, reducedMotion: this.reducedMotion,
      motionEnabled: this.active && !this.reducedMotion && this.model.visible && !this.model.closing })
  }

  build() {
    Column() {}.width(0).height(0)
      .bindContentCover(this.acceptsPresentation && this.model.visible, this.viewer(), this.options())
  }
}
