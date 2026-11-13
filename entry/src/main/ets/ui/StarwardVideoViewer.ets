import { window } from '@kit.ArkUI';
import { ClueVideoFile, ClueVideoFileLoader } from '../platform/ClueVideoFile';
import { ImmersiveSurfaces } from '../platform/ImmersiveSurfaces';
import { StarwardMediaAmbient, StarwardMediaFrame } from './StarwardClueMotion';

class VideoAttempt {
  readonly controller: VideoController = new VideoController();
  file: ClueVideoFile | null = null;

  release(): void {
    try { this.controller.stop(); } catch { /* The native player may not have prepared yet. */ }
    this.file?.release();
    this.file = null;
  }
}

/** Owns one authorized playback and reports its outcome after the cover disappears. */
@ObservedV2
export class StarwardVideoViewerState {
  @Trace visible: boolean = false;
  @Trace closing: boolean = false;
  @Trace sessionId: number = 0;
  @Trace phase: 'idle' | 'loading' | 'ready' | 'failed' = 'idle';
  @Trace attempt: VideoAttempt | null = null;
  private request: VideoAttempt | null = null;
  private loader: ClueVideoFileLoader | null = null;
  private source: string = '';
  private ownerCurrent: () => boolean = () => false;
  private finished: ((ended: boolean) => void) | undefined = undefined;
  private endedNaturally: boolean = false;
  private fullscreen: boolean = false;
  private lease: number = 0;

  open(source: string, cacheDir: string, ownerCurrent: () => boolean,
    finished?: (ended: boolean) => void): boolean {
    if (this.visible || this.closing || source.length === 0 || !ownerCurrent()) { return false; }
    try { this.lease = ImmersiveSurfaces.acquireDark(); } catch { return false; }
    this.sessionId++;
    this.source = source;
    this.ownerCurrent = ownerCurrent;
    this.finished = finished;
    this.endedNaturally = false;
    this.loader = new ClueVideoFileLoader(cacheDir);
    this.visible = true;
    this.load(this.sessionId);
    return true;
  }

  private active(sessionId: number): boolean {
    return this.visible && !this.closing && sessionId === this.sessionId && this.ownerCurrent();
  }

  private current(sessionId: number, attempt: VideoAttempt): boolean {
    return this.active(sessionId) && this.request === attempt;
  }

  private async load(sessionId: number): Promise<void> {
    const loader: ClueVideoFileLoader | null = this.loader;
    if (!this.active(sessionId) || loader === null) { return; }
    const attempt: VideoAttempt = new VideoAttempt();
    this.request = attempt;
    this.phase = 'loading';
    try {
      const file: ClueVideoFile = await loader.load(this.source);
      if (!this.current(sessionId, attempt)) { file.release(); return; }
      attempt.file = file;
      this.attempt = attempt;
    } catch {
      this.fail(sessionId, attempt);
    }
  }

  retry(sessionId: number): void {
    if (this.active(sessionId) && this.phase === 'failed') { this.load(sessionId); }
  }

  prepared(sessionId: number, attempt: VideoAttempt): void {
    if (!this.current(sessionId, attempt) || this.phase !== 'loading') { return; }
    this.phase = 'ready';
    try { attempt.controller.start(); } catch { this.fail(sessionId, attempt); }
  }

  fail(sessionId: number, attempt: VideoAttempt): void {
    if (!this.current(sessionId, attempt)) { return; }
    this.clearAttempt();
    this.phase = 'failed';
  }

  ended(sessionId: number, attempt: VideoAttempt): void {
    if (!this.current(sessionId, attempt) || this.phase !== 'ready') { return; }
    this.endedNaturally = true;
    this.close(sessionId);
  }

  fullscreenChanged(sessionId: number, attempt: VideoAttempt, fullscreen: boolean): void {
    if (this.current(sessionId, attempt)) { this.fullscreen = fullscreen; }
  }

  exitFullscreen(sessionId: number): boolean {
    if (sessionId !== this.sessionId || !this.fullscreen || this.request === null) { return false; }
    try { this.request.controller.exitFullscreen(); } catch { return false; }
    return true;
  }

  validateOwner(): void {
    if (this.visible && !this.ownerCurrent()) { this.close(this.sessionId, true); }
  }

  close(sessionId: number, immediate: boolean = false): void {
    if (sessionId !== this.sessionId || (!this.visible && !this.closing)) { return; }
    this.visible = false;
    this.closing = !immediate;
    this.clearAttempt();
    this.loader = null;
    this.source = '';
    this.ownerCurrent = () => false;
    this.phase = 'idle';
    if (immediate) {
      this.finished = undefined;
      this.endedNaturally = false;
      this.releaseLease();
    }
  }

  disappeared(sessionId: number): void {
    if (sessionId !== this.sessionId) { return; }
    const finished = this.finished;
    const ended: boolean = this.endedNaturally;
    this.close(sessionId, true);
    this.releaseLease();
    finished?.(ended);
  }

  private clearAttempt(): void {
    const attempt: VideoAttempt | null = this.request;
    const fullscreen: boolean = this.fullscreen;
    this.request = null;
    this.fullscreen = false;
    this.loader?.cancel();
    if (fullscreen && attempt !== null) {
      try { attempt.controller.exitFullscreen(); } catch { /* Closing also unmounts the player. */ }
    }
    attempt?.release();
    this.attempt = null;
  }

  private releaseLease(): void {
    const lease: number = this.lease;
    this.lease = 0;
    if (lease > 0) { ImmersiveSurfaces.releaseDark(lease); }
  }
}

@ComponentV2
export struct StarwardVideoViewer {
  @Env(ReadonlyEnvKey.WINDOW_SIZE) windowSize: window.SizeInVP;
  @Env(ReadonlyEnvKey.WINDOW_AVOID_AREA) avoidArea: window.UIEnvWindowAvoidAreaInfoVP;
  @Require @Param model: StarwardVideoViewerState;
  @Require @Param sessionId: number;
  @Param reducedMotion: boolean = true;
  @Param motionEnabled: boolean = false;

  private safeTop(): number {
    return Math.max(this.avoidArea.statusBar.topRect.height, this.avoidArea.cutout.topRect.height);
  }

  private safeBottom(): number {
    return Math.max(this.avoidArea.statusBar.bottomRect.height, this.avoidArea.cutout.bottomRect.height,
      this.avoidArea.navigationIndicator.bottomRect.height);
  }

  private safeLeft(): number {
    return Math.max(this.avoidArea.statusBar.leftRect.width, this.avoidArea.cutout.leftRect.width,
      this.avoidArea.navigationIndicator.leftRect.width);
  }

  private availableWidth(): number {
    return this.windowSize.width - this.safeLeft() - Math.max(this.avoidArea.statusBar.rightRect.width,
      this.avoidArea.cutout.rightRect.width, this.avoidArea.navigationIndicator.rightRect.width);
  }

  private availableHeight(): number { return this.windowSize.height - this.safeTop() - this.safeBottom(); }
  private panelWidth(): number {
    const width: number = this.availableWidth();
    return Math.max(1, Math.min(1100, width - (width <= 620 ? 28 : 56)));
  }

  private aspect(): number {
    const file: ClueVideoFile | null | undefined = this.model.attempt?.file;
    return file && file.width > 0 && file.height > 0 ? file.width / file.height : 16 / 9;
  }

  private stageWidth(): number {
    const natural: number = this.model.attempt?.file?.width || this.panelWidth();
    return Math.max(1, Math.min(this.panelWidth(), natural, Math.max(1, this.availableHeight() - 130) * this.aspect()));
  }

  private stageHeight(): number { return this.stageWidth() / this.aspect(); }

  @Builder
  player(attempt: VideoAttempt) {
    Video({ src: attempt.file?.uri, controller: attempt.controller, posterOptions: { showFirstFrame: true } })
      .id('gameplay-video-player').width('100%').height('100%').objectFit(ImageFit.Contain).controls(true)
      .onPrepared(() => this.model.prepared(this.sessionId, attempt))
      .onError(() => this.model.fail(this.sessionId, attempt))
      .onFinish(() => this.model.ended(this.sessionId, attempt))
      .onFullscreenChange((event: FullscreenInfo) => this.model.fullscreenChanged(this.sessionId, attempt, event.fullscreen))
  }

  @Builder
  stage() {
    Stack() {
      if (this.model.attempt !== null) { this.player(this.model.attempt) }
      if (this.model.phase === 'loading') {
        LoadingProgress().id('gameplay-video-loading').width(28).height(28).color('#d4bc7d')
          .enableLoading(!this.reducedMotion).accessibilityText('正在载入视频')
      } else if (this.model.phase === 'failed') {
        Column({ space: 4 }) {
          Text('视频加载失败').id('gameplay-video-error').fontSize(13).lineHeight('22.1fp').fontColor('#b8b7ae')
          Button('重新加载', { type: ButtonType.Capsule }).id('gameplay-video-retry')
            .constraintSize({ minHeight: 44, minWidth: 88 }).fontSize(13).fontColor('#f0ecdf')
            .backgroundColor(Color.Transparent).onClick(() => this.model.retry(this.sessionId))
        }
      }
      Column().width('100%').height('100%').border({ width: 1, color: '#29ffebb3' })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      if (this.model.phase === 'ready') {
        StarwardMediaFrame({ stageWidth: this.stageWidth(), stageHeight: this.stageHeight(),
          reducedMotion: this.reducedMotion })
      }
    }.id('gameplay-video-stage').width(this.stageWidth()).height(this.stageHeight())
      .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Button('', { type: ButtonType.Normal }).id('gameplay-video-mask').width('100%').height('100%')
        .backgroundColor('#f0050605').accessibilityLevel('no').onClick(() => this.model.close(this.sessionId))
      StarwardMediaAmbient({
        diameter: Math.min(1180, this.availableWidth() * 1.5), motionEnabled: this.motionEnabled
      }).position({ x: this.safeLeft() + (this.availableWidth() - Math.min(1180, this.availableWidth() * 1.5)) / 2,
        y: this.safeTop() + (this.availableHeight() - Math.min(1180, this.availableWidth() * 1.5)) / 2 })
      Stack({ alignContent: Alignment.Center }) {
        this.stage()
        Button('×', { type: ButtonType.Circle }).id('gameplay-video-close').width(46).height(46)
          .fontSize(28).fontWeight(600).fontColor('#f0ecdf').backgroundColor('#d110110e')
          .border({ width: 1, color: '#55574f' }).position({ x: Math.max(0, this.panelWidth() - 46), y: 0 })
          .defaultFocus(true)
          .accessibilityText('关闭媒体预览').onClick(() => this.model.close(this.sessionId))
      }.width(this.panelWidth()).height(Math.max(46, this.stageHeight()))
        .position({ x: this.safeLeft() + (this.availableWidth() - this.panelWidth()) / 2,
          y: this.safeTop() + Math.max(0, (this.availableHeight() - Math.max(46, this.stageHeight())) / 2) })
    }.id('gameplay-video-viewer').width('100%').height('100%').backgroundColor('#050605')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]).accessibilityText('视频播放器')
  }
}
