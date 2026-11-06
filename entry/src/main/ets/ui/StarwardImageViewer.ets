import { window } from '@kit.ArkUI';
import { ImmersiveSurfaces } from '../platform/ImmersiveSurfaces';
import { QuestionImageFailure, QuestionImageLoader, QuestionImageResult } from '../platform/QuestionImageLoader';

async function releaseViewerImage(value: QuestionImageResult | undefined): Promise<void> {
  if (value !== undefined) {
    try { await value.pixels.release(); } catch { /* Native details can contain private media URLs. */ }
  }
}

/** UI-only cover/resource owner. It never changes gameplay or owns an application Window. */
@ObservedV2
export class StarwardImageViewerState {
  @Trace visible: boolean = false;
  @Trace closing: boolean = false;
  @Trace sessionId: number = 0;
  @Trace sources: string[] = [];
  @Trace index: number = 0;
  @Trace value: QuestionImageResult | undefined = undefined;
  @Trace loadState: string = 'idle';
  @Trace zoom: number = 1;
  @Trace x: number = 0;
  @Trace y: number = 0;
  private readonly loader: QuestionImageLoader = new QuestionImageLoader();
  private revision: number = 0;
  private leaseId: number = 0;
  private ownerCurrent: () => boolean = () => false;

  open(sources: string[], index: number, ownerCurrent: () => boolean): void {
    if (this.visible || this.closing || !ownerCurrent() || !Number.isInteger(index) ||
      index < 0 || index >= sources.length || sources.some((source: string) => source.length === 0)) {
      return;
    }
    let lease: number = 0;
    try { lease = ImmersiveSurfaces.acquireDark(); } catch { return; }
    this.sessionId++;
    this.sources = sources.slice();
    this.index = index;
    this.ownerCurrent = ownerCurrent;
    this.leaseId = lease;
    this.visible = true;
    this.load();
  }

  active(): boolean { return this.visible && !this.closing && this.ownerCurrent(); }

  validateOwner(): void {
    if ((this.visible || this.closing) && !this.ownerCurrent()) { this.close(this.sessionId, true); }
  }

  close(sessionId: number, invalidOwner: boolean = false): void {
    if (sessionId !== this.sessionId || (!this.visible && !this.closing && this.sources.length === 0 &&
      this.value === undefined)) { return; }
    this.closing = true;
    this.visible = false;
    this.revision++;
    this.loader.cancel();
    if (invalidOwner) {
      // Clear private state synchronously; resource cleanup does not wait for cover animation.
      this.clearContent();
      this.releaseLease();
    }
  }

  disappeared(sessionId: number): void {
    if (sessionId !== this.sessionId) { return; }
    this.revision++;
    this.loader.cancel();
    this.visible = false;
    this.clearContent();
    this.releaseLease();
    this.closing = false;
  }

  private clearContent(): void {
    const previous: QuestionImageResult | undefined = this.value;
    this.value = undefined;
    this.sources = [];
    this.index = 0;
    this.ownerCurrent = () => false;
    this.loadState = 'idle';
    this.reset();
    releaseViewerImage(previous);
  }

  private releaseLease(): void {
    const lease: number = this.leaseId;
    this.leaseId = 0;
    if (lease > 0) { ImmersiveSurfaces.releaseDark(lease); }
  }

  reset(): void { this.zoom = 1; this.x = 0; this.y = 0; }

  select(index: number, sessionId: number): void {
    if (sessionId !== this.sessionId || !this.active() || !Number.isInteger(index) ||
      index < 0 || index >= this.sources.length || index === this.index) {
      return;
    }
    this.index = index;
    this.load();
  }

  retry(sessionId: number): void {
    if (sessionId === this.sessionId && this.active() && this.loadState === 'failed') { this.load(); }
  }

  private current(revision: number, sessionId: number, index: number, source: string): boolean {
    return this.active() && revision === this.revision && sessionId === this.sessionId &&
      index === this.index && source === this.sources[index];
  }

  private async load(): Promise<void> {
    const revision: number = ++this.revision;
    const sessionId: number = this.sessionId;
    const index: number = this.index;
    const source: string = this.sources[index] || '';
    this.loader.cancel();
    const previous: QuestionImageResult | undefined = this.value;
    this.value = undefined;
    this.loadState = 'idle';
    this.reset();
    await releaseViewerImage(previous);
    if (!this.current(revision, sessionId, index, source) || source.length === 0) { return; }
    this.loadState = 'loading';
    try {
      const value: QuestionImageResult = await this.loader.load(source, 2048);
      if (!this.current(revision, sessionId, index, source)) { await releaseViewerImage(value); return; }
      this.value = value;
      this.loadState = 'ready';
    } catch (error) {
      if (this.current(revision, sessionId, index, source) &&
        !(error instanceof QuestionImageFailure && error.cancelled)) { this.loadState = 'failed'; }
    }
  }
}

/** Fixed native gesture stage; only the image within it is transformed. */
@ComponentV2
export struct StarwardImageViewer {
  @Env(ReadonlyEnvKey.WINDOW_SIZE) windowSize: window.SizeInVP;
  @Env(ReadonlyEnvKey.WINDOW_AVOID_AREA) avoidArea: window.UIEnvWindowAvoidAreaInfoVP;
  @Require @Param model: StarwardImageViewerState;
  @Require @Param sessionId: number;
  @Param reducedMotion: boolean = true;
  @Event close: () => void = () => {};
  @Local private measuredWidth: number = 0;
  @Local private measuredHeight: number = 0;
  private contacts: number[] = [];
  private cycle: number = 0;
  private swipeBlocked: boolean = true;
  private beganAtOne: boolean = false;
  private panActive: boolean = false;
  private panCycle: number = 0;
  private panAtOne: boolean = false;
  private panX: number = 0;
  private panY: number = 0;
  private pinching: boolean = false;
  private pinchScale: number = 1;
  private centerX: number = 0;
  private centerY: number = 0;
  private mounted: boolean = false;

  aboutToAppear(): void { this.mounted = true; }
  aboutToDisappear(): void { this.mounted = false; this.blockCycle(); }

  private interactive(): boolean { return this.mounted && this.sessionId === this.model.sessionId && this.model.active(); }

  @Monitor('model.index')
  imageChanged(): void { this.blockCycle(); }

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
  private controlsHeight(): number { return this.model.sources.length > 1 ? 128 : 56; }
  private stageHeight(): number {
    return Math.max(0, Math.min(720, this.availableHeight() * 0.65, this.availableHeight() - 28 - this.controlsHeight()));
  }
  private stageWidth(): number { return this.measuredWidth > 0 ? this.measuredWidth : this.panelWidth(); }
  private actualStageHeight(): number { return this.measuredHeight > 0 ? this.measuredHeight : this.stageHeight(); }
  private imageFit(): number {
    return this.model.value === undefined ? 0 : Math.max(0, Math.min(1,
      this.stageWidth() / this.model.value.naturalWidthPx, this.actualStageHeight() / this.model.value.naturalHeightPx));
  }
  private imageWidth(): number { return (this.model.value?.naturalWidthPx || 0) * this.imageFit(); }
  private imageHeight(): number { return (this.model.value?.naturalHeightPx || 0) * this.imageFit(); }

  private pose(zoom: number, x: number, y: number): void {
    if (!this.interactive()) { return; }
    const scale: number = Math.max(1, Math.min(4, zoom));
    const limitX: number = this.stageWidth() * (scale - 1) / 2;
    const limitY: number = this.actualStageHeight() * (scale - 1) / 2;
    this.model.zoom = scale;
    this.model.x = Math.max(-limitX, Math.min(limitX, x));
    this.model.y = Math.max(-limitY, Math.min(limitY, y));
  }

  private blockCycle(): void { this.swipeBlocked = true; this.panActive = false; this.pinching = false; }

  private touch(event: TouchEvent): void {
    // Lifecycle only: all distances/centres come from the official gesture recognizers below.
    if (!this.interactive()) { return; }
    if (event.type === TouchType.Down) {
      if (this.contacts.length === 0) {
        this.cycle++;
        this.swipeBlocked = false;
        this.beganAtOne = this.model.zoom === 1 && event.source === SourceType.TouchScreen;
      }
      for (const point of event.changedTouches) {
        if (!this.contacts.includes(point.id)) { this.contacts.push(point.id); }
      }
    }
    if (event.touches.length > 1 || this.contacts.length > 1) { this.swipeBlocked = true; }
    if (event.type === TouchType.Cancel) { this.blockCycle(); }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      const ended: number[] = event.changedTouches.map((point: TouchObject) => point.id);
      this.contacts = this.contacts.filter((id: number) => !ended.includes(id));
    }
  }

  private pinchStart(event: GestureEvent): void {
    if (!this.interactive()) { return; }
    this.swipeBlocked = true;
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
    if (!this.interactive() || this.pinching) { return; }
    this.panActive = true;
    this.panCycle = this.cycle;
    this.panAtOne = this.beganAtOne && !this.swipeBlocked && this.model.zoom === 1;
    this.panX = this.model.x;
    this.panY = this.model.y;
    this.panUpdate(event);
  }

  private panUpdate(event: GestureEvent): void {
    if (this.panActive && !this.pinching && this.interactive() && this.model.zoom > 1) {
      this.pose(this.model.zoom, this.panX + event.offsetX, this.panY + event.offsetY);
    }
  }

  private panEnd(event: GestureEvent): void {
    if (!this.panActive || !this.interactive()) { return; }
    this.panUpdate(event);
    const swipe: boolean = this.panCycle === this.cycle && this.panAtOne && !this.swipeBlocked &&
      !this.pinching && this.model.zoom === 1 && event.source === SourceType.TouchScreen;
    this.panActive = false;
    this.swipeBlocked = true;
    if (swipe && Math.abs(event.offsetX) > 48 && Math.abs(event.offsetX) > Math.abs(event.offsetY) * 1.15) {
      this.model.select(this.model.index + (event.offsetX < 0 ? 1 : -1), this.sessionId);
    }
  }

  @Builder
  stage() {
    Stack() {
      if (this.model.value !== undefined && this.model.loadState === 'ready') {
        Stack() {
          Image(this.model.value.pixels).id('image-viewer-pixels').width(this.imageWidth()).height(this.imageHeight())
            .objectFit(ImageFit.Contain).draggable(false).accessibilityText(`预览图片 ${this.model.index + 1}`)
            .scale({ x: this.model.zoom, y: this.model.zoom, centerX: '50%', centerY: '50%' })
        }.width(this.imageWidth()).height(this.imageHeight()).translate({ x: this.model.x, y: this.model.y })
      } else if (this.model.loadState === 'loading') {
        LoadingProgress().id('image-viewer-loading').width(28).height(28).color('#d4bc7d')
          .enableLoading(!this.reducedMotion).accessibilityText('正在载入题图')
      } else if (this.model.loadState === 'failed') {
        Column({ space: 4 }) {
          Text('图片加载失败').id('image-viewer-error').fontSize(13).lineHeight('22.1fp').fontColor('#b8b7ae')
          Button('重新加载', { type: ButtonType.Capsule }).id('image-viewer-retry')
            .constraintSize({ minHeight: 44, minWidth: 88 }).fontSize(13).fontColor('#d7d3c7')
            .backgroundColor(Color.Transparent).onClick(() => this.model.retry(this.sessionId))
        }
      }
      Column().width('100%').height('100%').border({ width: 7, color: '#05ffffff' })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      Column().width('100%').height('100%').border({ width: 1, color: '#29ffebb3' })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
    }.id('image-viewer-stage').width('100%').height(this.stageHeight()).clip(true)
      .accessibilityDescription(`缩放${Math.round(this.model.zoom * 100)}%；水平偏移${this.model.x.toFixed(1)}vp；垂直偏移${this.model.y.toFixed(1)}vp`)
      .onAreaChange((_previous: Area, current: Area) => {
        const width: number = Number(current.width);
        const height: number = Number(current.height);
        if (Number.isFinite(width) && width > 0) { this.measuredWidth = width; }
        if (Number.isFinite(height) && height > 0) { this.measuredHeight = height; }
        this.pose(this.model.zoom, this.model.x, this.model.y);
      })
      .onTouch((event: TouchEvent) => this.touch(event))
      .gesture(GestureGroup(GestureMode.Parallel,
        PinchGesture({ fingers: 2, distance: 1, isFingerCountLimited: true })
          .onActionStart((event: GestureEvent) => this.pinchStart(event))
          .onActionUpdate((event: GestureEvent) => this.pinchUpdate(event))
          .onActionEnd(() => { this.pinching = false; this.swipeBlocked = true; })
          .onActionCancel(() => this.blockCycle()),
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 1, isFingerCountLimited: true })
          .allowedTypes([SourceTool.Finger])
          .onActionStart((event: GestureEvent) => this.panStart(event))
          .onActionUpdate((event: GestureEvent) => this.panUpdate(event))
          .onActionEnd((event: GestureEvent) => this.panEnd(event))
          .onActionCancel(() => { this.panActive = false; this.swipeBlocked = true; })
      ))
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
          if (this.interactive()) { this.blockCycle(); this.model.reset(); }
        })
      Text('双指缩放 · 放大后拖动').id('image-viewer-help').fontSize(13.3333).lineHeight(19).fontColor('#b8b7ae')
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
        .onClick(() => this.model.select(this.model.index - 1, this.sessionId))
      Text(`${this.model.index + 1} / ${this.model.sources.length}`).id('image-viewer-index')
        .constraintSize({ minWidth: 58 }).textAlign(TextAlign.Center).fontSize(16).lineHeight(22).fontColor('#b8b7ae')
      Button('下一张', { type: ButtonType.Capsule }).id('image-viewer-next').height(40)
        .padding({ left: 14, right: 14 }).fontSize(14).fontWeight(600).opacity(1)
        .fontColor(this.model.index === this.model.sources.length - 1 ? '#85867f' : '#d7d3c7')
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: this.model.index === this.model.sources.length - 1 ? '#3d3f39' : '#55574f' })
        .enabled(this.interactive() && this.model.index < this.model.sources.length - 1)
        .onClick(() => this.model.select(this.model.index + 1, this.sessionId))
    }.id('image-viewer-navigation').padding(7).border({ width: 1, color: '#6b6d654e' }).borderRadius(999)
      .backgroundColor('#db0f100d').accessibilityDescription('可左右滑动切换图片。')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Button('', { type: ButtonType.Normal }).id('image-viewer-mask').width('100%').height('100%')
        .backgroundColor('#f0050605').accessibilityText('关闭媒体预览').onClick(() => this.close())
      Stack({ alignContent: Alignment.TopEnd }) {
        Column({ space: 16 }) {
          this.stage()
          this.zoomControls()
          if (this.model.sources.length > 1) { this.navigation() }
        }.id('image-viewer-panel').width('100%').hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
        Button('×', { type: ButtonType.Circle }).id('image-viewer-close').width(46).height(46)
          .fontSize(28).fontWeight(600).fontColor('#f0ecdf').backgroundColor('#d110110e').border({ width: 1, color: '#55574f' })
          .accessibilityText('关闭媒体预览').defaultFocus(true).onClick(() => this.close())
      }.width(this.panelWidth()).position({ x: this.safeLeft() + (this.availableWidth() - this.panelWidth()) / 2,
        y: this.safeTop() + Math.max(14, (this.availableHeight() - this.stageHeight() - this.controlsHeight()) / 2) })
    }.id('image-viewer').width('100%').height('100%').backgroundColor('#050605')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .accessibilityText('图片预览')
  }
}
