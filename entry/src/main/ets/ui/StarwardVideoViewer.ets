import { curves, window } from '@kit.ArkUI';
import { ClueVideoFile, ClueVideoFileLoader } from '../platform/ClueVideoFile';
import { ImmersiveSurfaces } from '../platform/ImmersiveSurfaces';
import { QuestionImageResult } from '../platform/QuestionImageLoader';
import { StarwardMediaAmbient, StarwardMediaFrame } from './StarwardClueMotion';
import { STARWARD_PAGE_TRANSITION_MS } from './StarwardMotion';

class VideoAttempt {
  readonly controller: VideoController = new VideoController();
  file: ClueVideoFile | null = null;

  release(): void {
    try { this.controller.stop(); } catch { /* The native player may not have prepared yet. */ }
    this.file?.release();
    this.file = null;
  }
}

/** Owns one authorized playback. Cover playbacks report their outcome after dismissal. */
@ObservedV2
export class StarwardVideoViewerState {
  @Trace visible: boolean = false;
  @Trace closing: boolean = false;
  @Trace sessionId: number = 0;
  @Trace phase: 'idle' | 'loading' | 'ready' | 'failed' = 'idle';
  @Trace attempt: VideoAttempt | null = null;
  @Trace poster: QuestionImageResult | undefined = undefined;
  private request: VideoAttempt | null = null;
  private loader: ClueVideoFileLoader | null = null;
  private source: string = '';
  private ownerCurrent: () => boolean = () => false;
  private playbackReady: (() => Promise<boolean>) | undefined;
  private finished: ((ended: boolean) => void) | undefined = undefined;
  private endedNaturally: boolean = false;
  private fullscreen: boolean = false;
  private lease: number = 0;
  private readonly embedded: boolean;
  private pausedAt: number = 0;
  private playbackTime: number = 0;

  constructor(embedded: boolean = false) {
    this.embedded = embedded;
  }

  open(source: string, cacheDir: string, ownerCurrent: () => boolean,
    finished?: (ended: boolean) => void, playbackReady?: () => Promise<boolean>,
    poster?: QuestionImageResult, pausedAt: number = 0): boolean {
    if (this.visible || this.closing || source.length === 0 || !ownerCurrent()) { return false; }
    if (!this.embedded) {
      try { this.lease = ImmersiveSurfaces.acquireDark(); } catch { return false; }
    }
    this.sessionId++;
    this.source = source;
    this.ownerCurrent = ownerCurrent;
    this.finished = finished;
    this.playbackReady = playbackReady;
    this.poster = poster?.retain();
    this.pausedAt = this.embedded ? pausedAt : 0;
    this.playbackTime = 0;
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

  async prepared(sessionId: number, attempt: VideoAttempt, duration: number): Promise<void> {
    if (!this.current(sessionId, attempt) || this.phase !== 'loading') { return; }
    try {
      const gate = this.playbackReady;
      const ready: boolean = gate === undefined || await gate();
      if (!this.current(sessionId, attempt) || this.phase !== 'loading') { return; }
      if (!ready) { this.fail(sessionId, attempt); return; }
      if (this.restoringPaused()) {
        this.playbackTime = Number.isFinite(duration) && duration > 0 ? Math.min(this.pausedAt, duration) : this.pausedAt;
        attempt.controller.setCurrentTime(this.playbackTime, SeekMode.Accurate);
        this.phase = 'ready';
      } else {
        this.phase = 'ready';
        attempt.controller.start();
      }
    } catch {
      this.fail(sessionId, attempt);
    }
  }

  restoringPaused(): boolean { return this.pausedAt > 0; }

  pausePosition(): number {
    return this.embedded && this.phase === 'ready' && this.active(this.sessionId) ? this.playbackTime : 0;
  }

  positionChanged(sessionId: number, attempt: VideoAttempt, time: number): void {
    if (this.embedded && this.phase === 'ready' && this.current(sessionId, attempt) &&
      Number.isFinite(time) && time >= 0) { this.playbackTime = time; }
  }

  fail(sessionId: number, attempt: VideoAttempt): void {
    if (!this.current(sessionId, attempt)) { return; }
    this.clearAttempt();
    this.phase = 'failed';
  }

  ended(sessionId: number, attempt: VideoAttempt): void {
    if (!this.current(sessionId, attempt) || this.phase !== 'ready') { return; }
    this.endedNaturally = true;
    this.close(sessionId, this.embedded);
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
    const poster: QuestionImageResult | undefined = this.poster;
    this.poster = undefined;
    poster?.release();
    this.source = '';
    this.ownerCurrent = () => false;
    this.playbackReady = undefined;
    this.pausedAt = 0;
    this.playbackTime = 0;
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
struct StarwardNativeVideo {
  @Require @Param model: StarwardVideoViewerState;
  @Require @Param sessionId: number;
  @Require @Param attempt: VideoAttempt;
  @Require @Param nodeId: string;

  build() {
    Video({ src: this.attempt.file?.uri, controller: this.attempt.controller, previewUri: this.model.poster?.pixels,
      posterOptions: { showFirstFrame: this.model.poster === undefined || this.model.restoringPaused() } })
      .id(this.nodeId).width('100%').height('100%').objectFit(ImageFit.Contain)
      .autoPlay(false)
      .controls(this.model.phase === 'ready')
      .hitTestBehavior(this.model.phase === 'ready' ? HitTestMode.Default : HitTestMode.None)
      .onPrepared((event: PreparedInfo) => this.model.prepared(this.sessionId, this.attempt, event.duration))
      .onUpdate((event: PlaybackInfo) => this.model.positionChanged(this.sessionId, this.attempt, event.time))
      .onSeeked((event: PlaybackInfo) => this.model.positionChanged(this.sessionId, this.attempt, event.time))
      .onError(() => this.model.fail(this.sessionId, this.attempt))
      .onFinish(() => this.model.ended(this.sessionId, this.attempt))
      .onFullscreenChange((event: FullscreenInfo) =>
        this.model.fullscreenChanged(this.sessionId, this.attempt, event.fullscreen))
  }
}

@ComponentV2
export struct StarwardInlineVideo {
  @Require @Param model: StarwardVideoViewerState;
  @Require @Param sessionId: number;
  @Require @Param nodeId: string;
  @Param reducedMotion: boolean = true;

  build() {
    Stack() {
      if (this.model.attempt !== null) {
        StarwardNativeVideo({ model: this.model, sessionId: this.sessionId, attempt: this.model.attempt,
          nodeId: `${this.nodeId}-player` })
      } else if (this.model.phase === 'loading' && this.model.poster !== undefined) {
        Image(this.model.poster.pixels).width('100%').height('100%').objectFit(ImageFit.Contain)
          .draggable(false).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      }
      if (this.model.phase === 'loading') {
        LoadingProgress().id(`${this.nodeId}-loading`).width(28).height(28).color($r('app.color.accent'))
          .enableLoading(!this.reducedMotion).accessibilityText('正在载入视频')
      } else if (this.model.phase === 'failed') {
        Column({ space: 4 }) {
          Text('视频加载失败').id(`${this.nodeId}-error`).fontSize(13).fontColor($r('app.color.muted'))
          Button('重新加载', { type: ButtonType.Capsule }).id(`${this.nodeId}-retry`)
            .constraintSize({ minHeight: 44, minWidth: 88 }).fontSize(13).fontColor($r('app.color.accent_text'))
            .backgroundColor(Color.Transparent).onClick(() => this.model.retry(this.sessionId))
        }
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.media_surface'))
      .border({ width: 1, color: $r('app.color.border_strong') }).clip(true)
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

  @Computed
  get awaitingReveal(): boolean {
    return this.motionEnabled && !this.reducedMotion && this.model.phase === 'loading';
  }

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
  stage() {
    Stack() {
      if (this.model.phase === 'loading' && this.model.poster !== undefined &&
        (this.model.attempt === null || this.awaitingReveal)) {
        Image(this.model.poster.pixels).width('100%').height('100%').objectFit(ImageFit.Contain)
          .draggable(false).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      }
      if (this.model.attempt !== null) {
        Stack() {
          StarwardNativeVideo({ model: this.model, sessionId: this.sessionId, attempt: this.model.attempt,
            nodeId: 'gameplay-video-player' })
        }.width('100%').height('100%')
          .opacity(this.awaitingReveal ? 0 : 1).translate({ y: this.awaitingReveal ? 24 : 0 })
          .scale({ x: this.awaitingReveal ? 0.9 : 1, y: this.awaitingReveal ? 0.9 : 1 })
          .animation({ duration: this.motionEnabled && !this.reducedMotion ? STARWARD_PAGE_TRANSITION_MS : 0,
            curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) })
      }
      if (this.model.phase === 'loading') {
        LoadingProgress().id('gameplay-video-loading').width(28).height(28).color($r('app.color.media_viewer_accent'))
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
    }.id('gameplay-video-viewer').width('100%').height('100%')
    .backgroundColor($r('app.color.media_viewer_background'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]).accessibilityText('视频播放器')
  }
}
