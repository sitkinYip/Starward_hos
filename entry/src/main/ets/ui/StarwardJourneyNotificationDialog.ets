import { common } from '@kit.AbilityKit';
import { curves, uiMaterial, UIUtils, window } from '@kit.ArkUI';
import { GameNotification } from '../business/GameNotification';
import { ClueSpan } from '../business/GameplayClues';
import { journeyNotificationBlocks, JourneyNotificationBlock, journeyNotificationHasLink,
  journeyNotificationHasMedia } from '../business/JourneyNotificationContent';
import { isLegacyInternalLink } from '../business/LegacyRichContent';
import { externalClueLinkHref, openExternalClueLink } from '../platform/ExternalClueLink';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { QuestionImageResult } from '../platform/QuestionImageLoader';
import { StarwardFeedback } from './StarwardFeedback';
import { StarwardGlassDialog } from './StarwardGlassDialog';
import { StarwardImageViewer, StarwardImageViewerState } from './StarwardImageViewer';
import { StarwardMaterial } from './StarwardMaterial';
import { starwardMediaCoverOptions } from './StarwardMediaCover';
import { StarwardQuestionImages } from './StarwardQuestionImages';
import { StarwardVideoPoster } from './StarwardVideoPoster';
import { StarwardVideoViewer, StarwardVideoViewerState } from './StarwardVideoViewer';

const NOTICE_CURVE: ICurve = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
const SIGNAL_CURVE: ICurve = curves.cubicBezierCurve(0.32, 0.72, 0, 1);

function entrance(enabled: boolean, delay: number): AnimateParam {
  return { duration: enabled ? 720 : 0, delay: enabled ? delay : 0, curve: NOTICE_CURVE };
}

class JourneyNotificationPresentation {
  readonly owner: string;
  readonly note: GameNotification;

  constructor(owner: string, note: GameNotification) {
    this.owner = owner;
    this.note = note;
  }
}

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
    }, () => {
      try { UIUtils.applySync(() => { this.pulse = this.motionEnabled; }); } catch { this.pulse = this.motionEnabled; }
    });
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
  @Local private material: uiMaterial.ImmersiveMaterial | undefined = undefined;

  aboutToAppear(): void {
    this.revealed = this.reducedMotion || !this.active;
    this.materialChanged();
  }

  @Monitor('reducedMotion')
  private materialChanged(): void {
    this.material = StarwardMaterial.create(uiMaterial.ImmersiveStyle.THIN, !this.reducedMotion,
      $r('app.color.accent'));
  }

  private motion(): boolean { return this.active && !this.reducedMotion; }
  private shown(): boolean { return this.revealed || !this.motion(); }
  private horizontalInset(minimum: number): number { return Math.max(minimum, Math.min(40, (this.widthVp + 40) * 0.05)); }

  private heading(): string { return this.note.popupTitle.trim() || this.note.title.trim() || '魔法通知'; }

  @Builder
  private paragraph(block: JourneyNotificationBlock, index: number) {
    Text() {
      ForEach(block.spans, (span: ClueSpan) => {
        if (span.highlight) {
          Span(span.text).fontColor($r('app.color.highlight_text'))
            .textBackgroundStyle({ color: $r('app.color.highlight_surface') })
        } else if (isLegacyInternalLink(span.linkTarget) || externalClueLinkHref(span.linkTarget).length > 0) {
          Span(span.text).fontColor($r('app.color.accent_text'))
            .decoration({ type: TextDecorationType.Underline, color: $r('app.color.accent_text') })
            .onClick(() => this.openLink(this.note.id, span.linkTarget))
        } else {
          Span(span.text)
        }
      }, (_span: ClueSpan, position: number) => position.toString())
    }.id(`journey-notification-text-${index}`).width('100%').fontSize(15).lineHeight('27fp')
      .fontColor($r('app.color.text')).wordBreak(WordBreak.BREAK_WORD)
  }

  @Builder
  private reading() {
    Column() {
      Column() {
        Text(this.heading()).id('journey-notification-title')
          .fontSize(Math.max(24, Math.min(32, (this.widthVp + 40) * 0.045)))
          .fontColor($r('app.color.strong')).fontWeight(FontWeight.Bold)
          .wordBreak(WordBreak.BREAK_WORD).width('100%')
          .opacity(this.shown() ? 1 : 0).translate({ y: this.shown() ? 0 : 28 }).animation(entrance(this.motion(), 70))
        if (this.note.title.trim().length > 0 && this.note.title.trim() !== this.heading()) {
          Text(this.note.title).id('journey-notification-subtitle').fontSize(14).lineHeight('22.4fp')
            .fontColor($r('app.color.muted')).margin({ top: 8 })
            .wordBreak(WordBreak.BREAK_WORD).width('100%').opacity(this.shown() ? 1 : 0)
            .translate({ y: this.shown() ? 0 : 28 }).animation(entrance(this.motion(), 120))
        }
      }.width('100%').padding({ bottom: 18 }).alignItems(HorizontalAlign.Start)
        .border({ width: { bottom: 1 }, color: $r('app.color.border') })
      Column() {
        ForEach(journeyNotificationBlocks(this.note.content), (block: JourneyNotificationBlock, index: number) => {
          if (block.kind === 'image') {
            StarwardQuestionImages({ sources: [block.url], imageCache: this.imageCache, ownerKey: this.playerId,
              ownerIsCurrent: this.accountCurrent, active: this.active, groupId: `journey-notification-image-${index}`,
              imageLabel: '查看通知图片', maxHeight: 420, reducedMotion: this.reducedMotion,
              opened: () => this.openImage(this.note.id, block.url) }).margin({ top: 18, bottom: 18 })
              .borderRadius(16).clip(true)
          } else if (block.kind === 'video') {
            StarwardVideoPoster({ source: block.poster, ownerKey: this.playerId, ownerIsCurrent: this.accountCurrent,
              imageCache: this.imageCache, nodeId: `journey-notification-video-${index}`, playLabel: '播放通知视频',
              placeholderLabel: '点击播放视频', active: this.active, maxHeight: 420,
              play: () => this.openVideo(this.note.id, block.url, block.poster) }).margin({ top: 18, bottom: 18 })
              .borderRadius(16).clip(true)
          } else {
            this.paragraph(block, index)
          }
        }, (block: JourneyNotificationBlock, index: number) => `${index}:${JSON.stringify(block)}`)
      }.id('journey-notification-content').width('100%').margin({ top: 22 }).alignItems(HorizontalAlign.Start)
        .opacity(this.shown() ? 1 : 0).translate({ y: this.shown() ? 0 : 28 })
        .scale({ x: this.shown() ? 1 : 0.98, y: this.shown() ? 1 : 0.98 }).animation(entrance(this.motion(), 170))
    }.width('100%').alignItems(HorizontalAlign.Start)
      .padding({ top: this.horizontalInset(24), right: this.horizontalInset(24), bottom: 24,
        left: this.horizontalInset(24) })
  }

  @Builder
  private footer() {
    Column() {
      if (this.error.length > 0) {
        Text(this.error).id('journey-notification-read-error').fontSize(13).lineHeight('22.1fp')
          .fontColor($r('app.color.danger_strong')).width('100%').margin({ bottom: 12 }).wordBreak(WordBreak.BREAK_WORD)
      }
      Flex({ wrap: FlexWrap.Wrap, justifyContent: this.queuedCount > 1 ? FlexAlign.SpaceBetween : FlexAlign.End,
        alignItems: ItemAlign.Center }) {
        if (this.queuedCount > 1) {
          Text(`还有 ${this.queuedCount - 1} 条讯息`).fontSize(12).fontColor($r('app.color.muted'))
            .fontFeature("'tnum' 1")
        }
        Button(this.pending ? '正在收下…' : this.acknowledgeLabel || this.note.buttonText || '✨ 知晓了',
          { type: ButtonType.Capsule }).id('journey-notification-acknowledge')
          .constraintSize({ minHeight: 46, maxWidth: Math.max(0, this.widthVp - 2 * this.horizontalInset(20) - 2) })
          .padding({ left: 22, right: 22, top: 8, bottom: 8 }).fontSize(16).fontWeight(600)
          .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
          .enabled(this.active && !this.pending).accessibilityDescription(this.error.length > 0 ? '重试收下' : '')
          .onClick(() => this.acknowledge(this.note.id))
      }.width('100%')
    }.id('journey-notification-footer').width('100%').flexShrink(0)
      .padding({ left: this.horizontalInset(20), right: this.horizontalInset(20), top: 16, bottom: 16 })
      .backgroundColor($r('app.color.glass_floating'))
      .border({ width: { top: 1 }, color: $r('app.color.border') })
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
      .backgroundColor(this.material ? Color.Transparent : $r('app.color.raised'))
      .systemMaterial(this.material).border({ width: 1, radius: 24, color: $r('app.color.border') }).clip(true)
      .shadow({ radius: 44, color: $r('app.color.journey_notice_shadow'), offsetY: 22 })
      .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
      .onAppear(() => {
        try { UIUtils.applySync(() => { this.revealed = true; }); } catch { this.revealed = true; }
      })
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
  @Local private presented: JourneyNotificationPresentation[] = [];
  private previousOwner: string = '';
  private videoOpen: boolean = false;
  private readonly imageCache: QuestionImageCache = new QuestionImageCache(() => this.playerId);
  @Local private image: StarwardImageViewerState = new StarwardImageViewerState(this.imageCache);
  @Local private video: StarwardVideoViewerState = new StarwardVideoViewerState();

  @Computed
  get currentBlocks(): JourneyNotificationBlock[] {
    return journeyNotificationBlocks(this.note?.content ?? '');
  }

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
    if (this.active && this.note !== null && this.playerId.length > 0) {
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
    if (incoming === null || !this.active || this.presented[0]?.note.id !== incoming.id) {
      this.clearMedia();
    } else {
      this.image.validateOwner();
      this.video.validateOwner();
      if (!this.video.visible && !this.video.closing) { this.setVideoOpen(false); }
    }
    // Keep the last immutable record through the native dialog's exit transition.
    if (incoming !== null && this.active && this.playerId.length > 0 && incoming !== this.presented[0]?.note) {
      this.presented = [new JourneyNotificationPresentation(this.playerId, incoming)];
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

  private openImageSource(id: string, owner: string, source: string): void {
    this.image.open([source], 0, () => this.current(id, owner) &&
      journeyNotificationHasMedia(this.currentBlocks, 'image', source));
  }

  private openVideoSource(id: string, owner: string, source: string, posterSource: string): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    const current = (): boolean => this.current(id, owner) &&
      journeyNotificationHasMedia(this.currentBlocks, 'video', source, posterSource);
    if (!context || !current()) { return; }
    const poster: QuestionImageResult | undefined = posterSource.length > 0 ? this.imageCache.acquire(posterSource) : undefined;
    const opened: boolean = this.video.open(source, context.cacheDir, current,
      () => this.setVideoOpen(false), this.playbackReady, poster);
    poster?.release();
    if (opened) { this.setVideoOpen(true); }
  }

  private async openLinkHref(id: string, owner: string, source: string): Promise<void> {
    const current = (): boolean => this.current(id, owner) && journeyNotificationHasLink(this.currentBlocks, source);
    if (!current()) { return; }
    if (isLegacyInternalLink(source)) {
      if (!this.openInternalLink(source) && current()) {
        StarwardFeedback.toast(this.getUIContext(), '暂时无法打开链接，请重试。');
      }
      return;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      await openExternalClueLink(context, source);
    } catch {
      if (current()) { StarwardFeedback.toast(this.getUIContext(), '暂时无法打开链接，请重试。'); }
    }
  }

  private requestClose(): void {
    const request: JourneyNotificationPresentation | undefined = this.presented[0];
    if (request !== undefined && this.current(request.note.id, request.owner)) { this.close(request.note.id); }
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
    return Math.max(0, Math.min(600, this.windowSize.width - this.safeLeft() - this.safeRight() - 40));
  }

  private readingMaxHeight(): number {
    return Math.max(0, this.windowSize.height - this.safeTop() - this.safeBottom() - 48);
  }

  private imageOptions(): ContentCoverOptions {
    const sessionId: number = this.image.sessionId;
    return starwardMediaCoverOptions(this.reducedMotion,
      (action: DismissContentCoverAction) => { this.image.close(sessionId); action.dismiss(); },
      () => this.image.disappeared(sessionId));
  }

  private imageCloseAction(): () => void {
    const sessionId: number = this.image.sessionId;
    return () => this.image.close(sessionId);
  }

  private videoOptions(): ContentCoverOptions {
    const sessionId: number = this.video.sessionId;
    return starwardMediaCoverOptions(this.reducedMotion,
      (action: DismissContentCoverAction) => {
        if (!this.video.exitFullscreen(sessionId)) { this.video.close(sessionId); action.dismiss(); }
      },
      () => this.video.disappeared(sessionId));
  }

  @Builder
  private imageCover() {
    StarwardImageViewer({ model: this.image, sessionId: this.image.sessionId, reducedMotion: this.reducedMotion,
      motionEnabled: this.active && !this.reducedMotion && this.image.active(),
      close: this.imageCloseAction() })
  }

  @Builder
  private videoCover() {
    StarwardVideoViewer({ model: this.video, sessionId: this.video.sessionId, reducedMotion: this.reducedMotion,
      motionEnabled: this.active && !this.reducedMotion && this.video.visible && !this.video.closing })
  }

  @Builder
  private readingPane() {
    Stack({ alignContent: Alignment.Center }) {
      ForEach(this.presented, (presentation: JourneyNotificationPresentation) => {
        JourneyNotificationPanel({ note: this.presented[0]?.note ?? presentation.note, widthVp: this.readingWidth(),
          maxHeight: this.readingMaxHeight(), reducedMotion: this.reducedMotion,
          active: this.active && this.note !== null, pending: this.pending, error: this.error,
          playerId: presentation.owner, accountCurrent: (owner: string) => this.current(presentation.note.id, owner),
          imageCache: this.imageCache, queuedCount: this.queuedCount, acknowledgeLabel: this.acknowledgeLabel,
          acknowledge: (id: string) => { if (this.current(id, presentation.owner)) { this.acknowledge(id); } },
          openImage: (id: string, source: string) => this.openImageSource(id, presentation.owner, source),
          openVideo: (id: string, source: string, poster: string) => this.openVideoSource(id, presentation.owner, source, poster),
          openLink: (id: string, href: string) => { void this.openLinkHref(id, presentation.owner, href); } })
      }, (presentation: JourneyNotificationPresentation) => `${presentation.owner}:${presentation.note.id}`)
      Column() {}.width(0).height(0).bindContentCover(this.image.visible, this.imageCover(), this.imageOptions())
      Column() {}.width(0).height(0).bindContentCover(this.video.visible, this.videoCover(), this.videoOptions())
    }
  }

  build() {
    StarwardGlassDialog({ visible: this.active && this.note !== null && this.playerId.length > 0 &&
      this.readingWidth() > 0 && this.readingMaxHeight() > 0, panelWidth: this.readingWidth(), dismissOnTapOutside: true,
      reducedMotion: this.reducedMotion, content: () => { this.readingPane() },
      back: () => { this.handleBack(); }, failed: () => this.requestClose(), dismissed: () => {
        if (!this.active || this.note === null) { this.presented = []; }
      } })
  }
}
