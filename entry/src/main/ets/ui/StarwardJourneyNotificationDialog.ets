import { common } from '@kit.AbilityKit';
import { curves, UIUtils, window } from '@kit.ArkUI';
import { GameNotification } from '../business/GameNotification';
import { ClueSpan } from '../business/GameplayClues';
import { journeyNotificationBlocks, JourneyNotificationBlock } from '../business/JourneyNotificationContent';
import { externalClueLinkHref, openExternalClueLink } from '../platform/ExternalClueLink';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { QuestionImageResult } from '../platform/QuestionImageLoader';
import { StarwardFeedback } from './StarwardFeedback';
import { StarwardImageViewer, StarwardImageViewerState } from './StarwardImageViewer';
import { StarwardQuestionImages } from './StarwardQuestionImages';
import { StarwardVideoPoster } from './StarwardVideoPoster';
import { StarwardVideoViewer, StarwardVideoViewerState } from './StarwardVideoViewer';

const NOTICE_CURVE: ICurve = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
const SIGNAL_CURVE: ICurve = curves.cubicBezierCurve(0.32, 0.72, 0, 1);

function entrance(enabled: boolean, delay: number): AnimateParam {
  return { duration: enabled ? 720 : 0, delay: enabled ? delay : 0, curve: NOTICE_CURVE };
}

function internalLink(href: string): boolean { return href.startsWith('/') && !href.startsWith('//'); }

@ComponentV2
struct JourneyNotificationSignal {
  @Require @Param widthVp: number;
  @Require @Param heightVp: number;
  @Param motionEnabled: boolean = false;
  @Local private pulse: boolean = false;
  private mounted: boolean = false;

  @Monitor('motionEnabled')
  syncMotion(): void {
    if (!this.mounted) { return; }
    this.getUIContext().animateTo({
      duration: this.motionEnabled ? 3200 : 0, iterations: this.motionEnabled ? -1 : 1,
      playMode: PlayMode.Alternate, curve: SIGNAL_CURVE
    }, () => UIUtils.applySync(() => { this.pulse = this.motionEnabled; }));
  }

  aboutToDisappear(): void { this.mounted = false; }

  @Builder
  ring(diameter: number, dashed: boolean = false, center: boolean = false) {
    Circle().width(diameter).height(diameter).fill(center ? $r('app.color.journey_notice_glow') : Color.Transparent)
      .stroke($r('app.color.journey_notice_signal')).strokeWidth(1).strokeDashArray(dashed ? [3, 4] : [])
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack() {
        this.ring(320)
        this.ring(286)
        this.ring(231, true)
        this.ring(163)
        this.ring(61, false, true)
      }.width(340).height(340).position({ x: this.widthVp - 230, y: -140 })
        .opacity(this.motionEnabled ? (this.pulse ? 0.44 : 0.14) : 0.24)
        .scale({ x: this.pulse ? 1.08 : 0.82, y: this.pulse ? 1.08 : 0.82 })
      Column() {}.width(Math.max(0, this.widthVp - 14)).height(Math.max(0, this.heightVp - 14))
        .position({ x: 7, y: 7 }).border({ width: 1, color: $r('app.color.journey_notice_glow') })
      Column() {}.width(this.widthVp * 0.7).height(1)
        .linearGradient({ direction: GradientDirection.Right,
          colors: [[Color.Transparent, 0], [$r('app.color.journey_notice_signal'), 0.5], [Color.Transparent, 1]] })
        .position({ x: this.widthVp * 0.15, y: 0 })
        .opacity(this.pulse ? 0.76 : 0.26).scale({ x: this.pulse ? 1 : 0.38, y: 1 })
    }.width(this.widthVp).height(this.heightVp).clip(true)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      .onAppear(() => { this.mounted = true; this.syncMotion(); })
  }
}

@ComponentV2
struct JourneyNotificationPanel {
  @Require @Param note: GameNotification;
  @Require @Param widthVp: number;
  @Require @Param maxHeight: number;
  @Require @Param playerId: string;
  @Require @Param accountCurrent: (owner: string) => boolean;
  @Require @Param imageCache: QuestionImageCache;
  @Param displayFont: string = 'serif';
  @Param active: boolean = true;
  @Param reducedMotion: boolean = true;
  @Param pending: boolean = false;
  @Param error: string = '';
  @Param queuedCount: number = 1;
  @Param acknowledgeLabel: string = '';
  @Event acknowledge: (id: string) => void = () => {};
  @Event openImage: (id: string, source: string) => void = () => {};
  @Event openVideo: (id: string, source: string, poster: string) => void = () => {};
  @Event openLink: (id: string, href: string) => void = () => {};
  @Local private revealed: boolean = true;
  @Local private heightVp: number = 0;

  aboutToAppear(): void { this.revealed = this.reducedMotion || !this.active; }

  private motion(): boolean { return this.active && !this.reducedMotion; }
  private shown(): boolean { return this.revealed || !this.motion(); }
  private horizontalInset(minimum: number): number { return Math.max(minimum, Math.min(58, (this.widthVp + 48) * 0.06)); }

  @Builder
  private paragraph(block: JourneyNotificationBlock, index: number) {
    Text() {
      ForEach(block.spans, (span: ClueSpan) => {
        if (span.highlight) {
          Span(span.text).fontColor($r('app.color.journey_notice_mark'))
            .textBackgroundStyle({ color: $r('app.color.journey_notice_mark_background') })
        } else if (internalLink(span.linkTarget) || externalClueLinkHref(span.linkTarget).length > 0) {
          Span(span.text).fontColor($r('app.color.journey_notice_link'))
            .decoration({ type: TextDecorationType.Underline, color: $r('app.color.journey_notice_link') })
            .onClick(() => this.openLink(this.note.id, span.linkTarget))
        } else {
          Span(span.text)
        }
      }, (_span: ClueSpan, position: number) => position.toString())
    }.id(`journey-notification-text-${index}`).width('100%').fontSize(16).lineHeight('30.4fp')
      .fontColor($r('app.color.journey_notice_body')).wordBreak(WordBreak.BREAK_WORD)
  }

  @Builder
  private reading() {
    Column() {
      Column() {
        Text('INCOMING TRANSMISSION').fontFamily('monospace').fontSize(11).lineHeight('13.2fp')
          .fontWeight(600).letterSpacing('1.76fp').fontColor($r('app.color.accent_muted'))
          .opacity(this.shown() ? 1 : 0).translate({ y: this.shown() ? 0 : 28 }).animation(entrance(this.motion(), 0))
        Text(this.note.popupTitle || '✨ 魔法通知 ✨').id('journey-notification-title')
          .fontFamily(this.displayFont).fontSize(Math.max(30, Math.min(48, (this.widthVp + 48) * 0.06)))
          .fontColor($r('app.color.journey_notice_title')).fontWeight(FontWeight.Medium)
          .wordBreak(WordBreak.BREAK_WORD).margin({ top: 12 }).width('100%')
          .opacity(this.shown() ? 1 : 0).translate({ y: this.shown() ? 0 : 28 }).animation(entrance(this.motion(), 70))
        if (this.note.title.length > 0) {
          Text(this.note.title).id('journey-notification-subtitle').fontSize(16).lineHeight('27.2fp')
            .fontColor($r('app.color.journey_notice_body')).margin({ top: 12 })
            .wordBreak(WordBreak.BREAK_WORD).width('100%').opacity(this.shown() ? 1 : 0)
            .translate({ y: this.shown() ? 0 : 28 }).animation(entrance(this.motion(), 120))
        }
      }.width('100%').padding({ bottom: 22 }).alignItems(HorizontalAlign.Start)
        .border({ width: { bottom: 1 }, color: $r('app.color.journey_notice_rule') })
      Column() {
        ForEach(journeyNotificationBlocks(this.note.content), (block: JourneyNotificationBlock, index: number) => {
          if (block.kind === 'image') {
            StarwardQuestionImages({ sources: [block.url], imageCache: this.imageCache, ownerKey: this.playerId,
              ownerIsCurrent: this.accountCurrent, active: this.active, groupId: `journey-notification-image-${index}`,
              imageLabel: '查看通知图片', maxHeight: 420, reducedMotion: this.reducedMotion,
              opened: () => this.openImage(this.note.id, block.url) }).margin({ top: 20, bottom: 20 })
          } else if (block.kind === 'video') {
            StarwardVideoPoster({ source: block.poster, ownerKey: this.playerId, ownerIsCurrent: this.accountCurrent,
              imageCache: this.imageCache, nodeId: `journey-notification-video-${index}`, playLabel: '播放通知视频',
              placeholderLabel: '点击播放视频', active: this.active, maxHeight: 420,
              play: () => this.openVideo(this.note.id, block.url, block.poster) }).margin({ top: 20, bottom: 20 })
          } else {
            this.paragraph(block, index)
          }
        }, (_block: JourneyNotificationBlock, index: number) => `${this.note.id}:${index}`)
      }.id('journey-notification-content').width('100%').margin({ top: 26 }).alignItems(HorizontalAlign.Start)
        .opacity(this.shown() ? 1 : 0).translate({ y: this.shown() ? 0 : 28 })
        .scale({ x: this.shown() ? 1 : 0.98, y: this.shown() ? 1 : 0.98 }).animation(entrance(this.motion(), 170))
    }.width('100%').alignItems(HorizontalAlign.Start)
      .padding({ top: this.horizontalInset(30), right: this.horizontalInset(30), bottom: 30,
        left: this.horizontalInset(30) })
  }

  @Builder
  private footer() {
    Column() {
      if (this.error.length > 0) {
        Text(this.error).id('journey-notification-read-error').fontSize(13).lineHeight('22.1fp')
          .fontColor($r('app.color.danger')).width('100%').margin({ bottom: 12 }).wordBreak(WordBreak.BREAK_WORD)
      }
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Text(this.queuedCount > 1 ? `还有 ${this.queuedCount - 1} 条讯息` : '').fontSize(12)
          .fontColor($r('app.color.journey_notice_body'))
        Button(this.pending ? '正在收下…' : this.acknowledgeLabel || this.note.buttonText || '✨ 知晓了',
          { type: ButtonType.Capsule }).id('journey-notification-acknowledge')
          .constraintSize({ minHeight: 46, maxWidth: Math.max(0, this.widthVp - 2 * this.horizontalInset(20) - 2) })
          .padding({ left: 22, right: 22, top: 8, bottom: 8 }).fontSize(16).fontWeight(600)
          .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
          .enabled(!this.pending).accessibilityDescription(this.error.length > 0 ? '重试收下' : '')
          .onClick(() => this.acknowledge(this.note.id))
      }.width('100%')
    }.id('journey-notification-footer').width('100%').flexShrink(0)
      .padding({ left: this.horizontalInset(20), right: this.horizontalInset(20), top: 18, bottom: 18 })
      .backgroundColor($r('app.color.journey_notice_footer'))
      .border({ width: { top: 1 }, color: $r('app.color.journey_notice_rule') })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.heightVp > 2) {
        JourneyNotificationSignal({ widthVp: this.widthVp - 2, heightVp: this.heightVp - 2, motionEnabled: this.motion() })
          .position({ x: 0, y: 0 })
      }
      Flex({ direction: FlexDirection.Column }) {
        Scroll() {
          this.reading()
        }.id('journey-notification-scroll').width('100%').flexShrink(1)
          .constraintSize({ maxHeight: this.maxHeight }).align(Alignment.Top).scrollBar(BarState.Off)
        this.footer()
      }.width('100%').height('auto').constraintSize({ maxHeight: this.maxHeight })
    }.id('journey-notification-dialog').width(this.widthVp).constraintSize({ maxHeight: this.maxHeight })
      .backgroundColor($r('app.color.journey_notice_surface'))
      .radialGradient({ center: ['50%', '0%'], radius: this.widthVp * 0.7,
        colors: [[$r('app.color.journey_notice_glow'), 0], [Color.Transparent, 1]] })
      .border({ width: 1, color: $r('app.color.journey_notice_border') })
      .shadow({ radius: 44, color: $r('app.color.journey_notice_shadow'), offsetY: 22 })
      .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
      .onAppear(() => UIUtils.applySync(() => { this.revealed = true; }))
      .onAreaChange((_previous: Area, area: Area) => {
        const height: number = Number(area.height);
        if (height > 0 && Number.isFinite(height) && height !== this.heightVp) { this.heightVp = height; }
      })
  }
}

/** Shared reading surface. Its owner chooses whether closing should acknowledge the notification. */
@ComponentV2
export struct StarwardJourneyNotificationDialog {
  @Env(ReadonlyEnvKey.WINDOW_SIZE) windowSize: window.SizeInVP;
  @Env(ReadonlyEnvKey.WINDOW_AVOID_AREA) avoidArea: window.UIEnvWindowAvoidAreaInfoVP;
  @Require @Param note: GameNotification | null;
  @Require @Param playerId: string;
  @Param active: boolean = true;
  @Param displayFont: string = 'serif';
  @Param reducedMotion: boolean = true;
  @Param pending: boolean = false;
  @Param error: string = '';
  @Param queuedCount: number = 1;
  @Param acknowledgeLabel: string = '';
  @Param playbackReady: () => Promise<boolean> = async () => true;
  @Event close: (id: string) => void = () => {};
  @Event acknowledge: (id: string) => void = () => {};
  @Event playingChanged: (playing: boolean) => void = () => {};
  @Event openInternalLink: (href: string) => boolean = () => false;
  @Event backHandlerChanged: (handler: (() => boolean) | null) => void = () => {};
  @Local private presented: GameNotification[] = [];
  private previousOwner: string = '';
  private videoOpen: boolean = false;
  private readonly imageCache: QuestionImageCache = new QuestionImageCache(() => this.playerId);
  @Local private image: StarwardImageViewerState = new StarwardImageViewerState(this.imageCache);
  @Local private video: StarwardVideoViewerState = new StarwardVideoViewerState();

  private readonly handleBack = (): boolean => {
    if (this.video.visible) {
      const sessionId: number = this.video.sessionId;
      if (!this.video.exitFullscreen(sessionId)) { this.video.close(sessionId); }
      return true;
    }
    if (this.video.closing) { return true; }
    if (this.image.visible) {
      this.image.close(this.image.sessionId);
      return true;
    }
    if (this.image.closing) { return true; }
    if (this.presented.length > 0 || (this.note !== null && this.playerId.length > 0)) {
      this.requestClose();
      return true;
    }
    return false;
  };

  aboutToAppear(): void {
    this.syncNote();
    this.backHandlerChanged(this.handleBack);
  }

  aboutToDisappear(): void {
    this.backHandlerChanged(null);
    this.clearMedia();
    this.imageCache.clear();
    this.presented = [];
  }

  @Monitor('note', 'playerId', 'active')
  private syncNote(): void {
    const incoming: GameNotification | null = this.note;
    if (this.previousOwner !== this.playerId) {
      this.presented = [];
      this.previousOwner = this.playerId;
      this.imageCache.validateOwner();
    }
    if (incoming === null || !this.active || this.presented[0]?.id !== incoming.id) { this.clearMedia(); }
    // Keep the last immutable record through the native cover's exit transition.
    if (incoming !== null && this.playerId.length > 0 && incoming !== this.presented[0]) {
      this.presented = [incoming];
    }
  }

  private clearMedia(): void {
    const sessionId: number = this.image.sessionId;
    this.image.close(sessionId, true);
    this.image.disappeared(sessionId);
    this.video.close(this.video.sessionId, true);
    this.setVideoOpen(false);
  }

  private setVideoOpen(open: boolean): void {
    if (this.videoOpen === open) { return; }
    this.videoOpen = open;
    this.playingChanged(open);
  }

  private current(id: string, owner: string): boolean {
    return this.active && owner.length > 0 && this.playerId === owner && this.note?.id === id;
  }

  private openImageSource(id: string, source: string): void {
    const owner: string = this.playerId;
    this.image.open([source], 0, () => this.current(id, owner));
  }

  private openVideoSource(id: string, source: string, posterSource: string): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    const owner: string = this.playerId;
    if (!context || !this.current(id, owner)) { return; }
    const poster: QuestionImageResult | undefined = posterSource.length > 0 ? this.imageCache.acquire(posterSource) : undefined;
    const opened: boolean = this.video.open(source, context.cacheDir, () => this.current(id, owner),
      () => this.setVideoOpen(false), this.playbackReady, poster);
    poster?.release();
    if (opened) { this.setVideoOpen(true); }
  }

  private async openLinkHref(id: string, source: string): Promise<void> {
    const owner: string = this.playerId;
    if (!this.current(id, owner)) { return; }
    if (internalLink(source)) {
      if (!this.openInternalLink(source) && this.current(id, owner)) {
        StarwardFeedback.toast(this.getUIContext(), '暂时无法打开链接，请重试。');
      }
      return;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      await openExternalClueLink(context, source);
    } catch {
      if (this.current(id, owner)) { StarwardFeedback.toast(this.getUIContext(), '暂时无法打开链接，请重试。'); }
    }
  }

  private requestClose(): void {
    const note: GameNotification | undefined = this.presented[0];
    if (note !== undefined && this.current(note.id, this.playerId)) { this.close(note.id); }
  }

  private safeTop(): number {
    return Math.max(0, this.avoidArea.statusBar.topRect.height, this.avoidArea.cutout.topRect.height,
      this.avoidArea.navigationIndicator.topRect.height);
  }

  private safeBottom(): number {
    return Math.max(0, this.avoidArea.statusBar.bottomRect.height, this.avoidArea.cutout.bottomRect.height,
      this.avoidArea.navigationIndicator.bottomRect.height);
  }

  private safeLeft(): number {
    return Math.max(0, this.avoidArea.statusBar.leftRect.width, this.avoidArea.cutout.leftRect.width,
      this.avoidArea.navigationIndicator.leftRect.width);
  }

  private safeRight(): number {
    return Math.max(0, this.avoidArea.statusBar.rightRect.width, this.avoidArea.cutout.rightRect.width,
      this.avoidArea.navigationIndicator.rightRect.width);
  }

  private readingWidth(): number {
    return Math.max(0, Math.min(640, this.windowSize.width - this.safeLeft() - this.safeRight() - 48));
  }

  private readingMaxHeight(): number {
    return Math.max(0, this.windowSize.height - this.safeTop() - this.safeBottom() - 48);
  }

  private modalTransition(): ModalTransition { return this.reducedMotion ? ModalTransition.NONE : ModalTransition.ALPHA; }

  private imageOptions(): ContentCoverOptions {
    const sessionId: number = this.image.sessionId;
    return { backgroundColor: '#050605', enableSafeArea: false, modalTransition: this.modalTransition(),
      onWillDismiss: (action: DismissContentCoverAction) => { this.image.close(sessionId); action.dismiss(); },
      onDisappear: () => this.image.disappeared(sessionId) };
  }

  private videoOptions(): ContentCoverOptions {
    const sessionId: number = this.video.sessionId;
    return { backgroundColor: '#050605', enableSafeArea: false, modalTransition: this.modalTransition(),
      onWillDismiss: (action: DismissContentCoverAction) => {
        if (!this.video.exitFullscreen(sessionId)) { this.video.close(sessionId); action.dismiss(); }
      },
      onDisappear: () => this.video.disappeared(sessionId) };
  }

  @Builder
  private imageCover() {
    StarwardImageViewer({ model: this.image, sessionId: this.image.sessionId, reducedMotion: this.reducedMotion,
      motionEnabled: this.active && !this.reducedMotion && this.image.active(),
      close: () => this.image.close(this.image.sessionId) })
  }

  @Builder
  private videoCover() {
    StarwardVideoViewer({ model: this.video, sessionId: this.video.sessionId, reducedMotion: this.reducedMotion,
      motionEnabled: this.active && !this.reducedMotion && this.video.visible && !this.video.closing })
  }

  @Builder
  private readingCover() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {}.id('journey-notification-backdrop').width('100%').height('100%')
        .onClick(() => this.requestClose())
      Stack({ alignContent: Alignment.Center }) {
        if (this.readingWidth() > 0 && this.readingMaxHeight() > 0) {
          ForEach(this.presented, (note: GameNotification) => {
            JourneyNotificationPanel({ note: note, widthVp: this.readingWidth(), maxHeight: this.readingMaxHeight(),
              displayFont: this.displayFont, reducedMotion: this.reducedMotion,
              active: this.active && this.note !== null, pending: this.pending, error: this.error,
              playerId: this.playerId, accountCurrent: (owner: string) => owner === this.playerId && owner.length > 0,
              imageCache: this.imageCache, queuedCount: this.queuedCount, acknowledgeLabel: this.acknowledgeLabel,
              acknowledge: (id: string) => { if (this.current(id, this.playerId)) { this.acknowledge(id); } },
              openImage: (id: string, source: string) => this.openImageSource(id, source),
              openVideo: (id: string, source: string, poster: string) => this.openVideoSource(id, source, poster),
              openLink: (id: string, href: string) => { void this.openLinkHref(id, href); } })
          }, (note: GameNotification) => note.id)
        }
      }.width('100%').height('100%')
        .padding({ top: this.safeTop(), bottom: this.safeBottom(), left: this.safeLeft(), right: this.safeRight() })
        .hitTestBehavior(HitTestMode.Transparent)
      Column() {}.width(0).height(0).bindContentCover(this.image.visible, this.imageCover(), this.imageOptions())
      Column() {}.width(0).height(0).bindContentCover(this.video.visible, this.videoCover(), this.videoOptions())
    }.width('100%').height('100%').backgroundBlurStyle(BlurStyle.Thick)
      .backgroundColor($r('app.color.journey_notice_backdrop'))
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT],
        [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  build() {
    Column() {}.width(0).height(0)
      .bindContentCover(this.note !== null && this.playerId.length > 0, this.readingCover(), {
        backgroundColor: Color.Transparent, enableSafeArea: false, modalTransition: this.modalTransition(),
        onWillDismiss: () => this.requestClose(),
        onDisappear: () => { if (this.note === null) { this.presented = []; } }
      })
  }
}
