import { common } from '@kit.AbilityKit';
import { curves, UIUtils, window } from '@kit.ArkUI';
import { GameReward, RewardStatus } from '../business/GameReward';
import { isLegacyInternalLink, legacyRichBlocks, LegacyRichBlock } from '../business/LegacyRichContent';
import { openExternalClueLink } from '../platform/ExternalClueLink';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { QuestionImageLoader, QuestionImageResult } from '../platform/QuestionImageLoader';
import { ErrorNotice } from '../ui/ErrorMessages';
import { StarwardFeedback } from '../ui/StarwardFeedback';
import { StarwardImageViewer, StarwardImageViewerState } from '../ui/StarwardImageViewer';
import { StarwardRefresh } from '../ui/StarwardRefresh';
import { StarwardRichContent } from '../ui/StarwardRichContent';
import { StarwardVideoViewer, StarwardVideoViewerState } from '../ui/StarwardVideoViewer';
import { RewardsViewModel } from './RewardsViewModel';

const rewardDate = new Intl.DateTimeFormat('zh-CN', {
  year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
});
const DETAIL_TOP_PADDING: number = 30;

function formattedRewardDate(value: string): string {
  const date: Date = new Date(value);
  return Number.isNaN(date.getTime()) ? '时间待确认' : rewardDate.format(date);
}

function rewardStatus(status: RewardStatus): string {
  switch (status) {
    case 'available': return '礼物待领取';
    case 'redeemed': return '已领取 · 已核销';
    case 'voided': return '已失效';
  }
}

function reveal(motion: boolean, delay: number = 0): AnimateParam {
  return { duration: motion ? 640 : 0, delay: motion ? delay : 0,
    curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) };
}

@ComponentV2
struct RewardThumbnail {
  @Require @Param source: string;
  @Require @Param name: string;
  @Require @Param owner: string;
  @Require @Param imageCache: QuestionImageCache;
  @Require @Param ownerValid: (owner: string) => boolean;
  @Param active: boolean = false;
  @Local private value: QuestionImageResult | undefined = undefined;
  private loader: QuestionImageLoader = new QuestionImageLoader();
  private generation: number = 0;
  private inView: boolean = false;
  private mounted: boolean = false;

  aboutToAppear(): void { this.mounted = true; }

  aboutToDisappear(): void {
    this.mounted = false;
    this.clear();
  }

  @Monitor('active', 'owner', 'source')
  private inputsChanged(): void {
    this.clear();
    void this.load();
  }

  private clear(): void {
    this.generation++;
    this.loader.cancel();
    const previous: QuestionImageResult | undefined = this.value;
    this.value = undefined;
    previous?.release();
  }

  private stillOwned(generation: number, owner: string, source: string): boolean {
    return this.mounted && this.active && owner.length > 0 && this.generation === generation &&
      this.owner === owner && this.source === source && this.ownerValid(owner);
  }

  private async load(): Promise<void> {
    if (!this.inView || this.value !== undefined) { return; }
    const generation: number = ++this.generation;
    const owner: string = this.owner;
    const source: string = this.source;
    if (!this.stillOwned(generation, owner, source)) { return; }
    const cached: QuestionImageResult | undefined = this.imageCache.acquire(source);
    if (cached !== undefined) { this.value = cached; return; }
    const cacheGeneration: number = this.imageCache.version();
    try {
      const loaded: QuestionImageResult = await this.loader.load(source);
      if (!this.stillOwned(generation, owner, source)) { await loaded.release(); return; }
      this.imageCache.remember(source, loaded, cacheGeneration);
      this.value = loaded;
    } catch { /* Keep the themed art fallback when an image is unavailable. */ }
  }

  build() {
    Stack() {
      if (this.value !== undefined) {
        Image(this.value.pixels).width(72).height(72).objectFit(ImageFit.Cover).draggable(false)
          .borderRadius(10).accessibilityText(this.name)
      } else {
        Image($r('app.media.icon_sparkle')).width(40).height(40).objectFit(ImageFit.Contain)
          .fillColor($r('app.color.accent_muted')).accessibilityLevel('no')
      }
    }.width(72).height(72).borderRadius(10).backgroundColor($r('app.color.accent_faint'))
      .onVisibleAreaChange([0], (_expanded: boolean, ratio: number) => {
        const entered: boolean = ratio > 0 && !this.inView;
        this.inView = ratio > 0;
        if (entered) { void this.load(); }
      })
  }
}

@ComponentV2
struct RewardCard {
  @Require @Param model: RewardsViewModel;
  @Require @Param rewardId: string;
  @Require @Param displayFont: string;
  @Require @Param imageCache: QuestionImageCache;
  @Require @Param ownerValid: (owner: string) => boolean;
  @Param active: boolean = false;
  @Param reducedMotion: boolean = true;
  @Param delay: number = 0;
  @Local private revealed: boolean = false;

  @Computed
  get entry(): GameReward | undefined { return this.model.entries.find((item: GameReward) => item.id === this.rewardId); }

  @Monitor('active')
  private updateReveal(): void { UIUtils.applySync(() => { this.revealed = this.active; }); }

  @Builder
  private art() {
    if (this.entry !== undefined) {
      Column({ space: 16 }) {
        if (this.entry.snapshot.image.length > 0) {
          RewardThumbnail({ source: this.entry.snapshot.image, name: this.entry.snapshot.name, owner: this.entry.player,
            imageCache: this.imageCache, ownerValid: this.ownerValid, active: this.active })
        } else {
          Stack() {
            Image($r('app.media.icon_sparkle')).width(38).height(38).objectFit(ImageFit.Contain)
              .fillColor($r('app.color.accent_muted')).accessibilityLevel('no')
          }.width(64).height(64).border({ width: 1, radius: 32, color: $r('app.color.accent_border') })
            .backgroundColor($r('app.color.accent_faint'))
        }
        Text(`× ${this.entry.quantity}`).fontFamily('monospace').fontSize(13).lineHeight('18.2fp')
          .fontColor($r('app.color.accent_muted')).textAlign(TextAlign.Center)
      }.width(72).padding({ top: 12 })
    }
  }

  build() {
    if (this.entry !== undefined) {
      Row({ space: 16 }) {
        this.art()
        Column() {
          Text(rewardStatus(this.entry.status)).fontSize(13).lineHeight('19fp')
            .fontColor(this.entry.status === 'available' ? $r('app.color.accent_text') : $r('app.color.muted'))
            .width('100%')
          Text(this.entry.snapshot.name).fontFamily(this.displayFont).fontSize(21).fontWeight(FontWeight.Medium)
            .lineHeight('31.5fp').wordBreak(WordBreak.BREAK_WORD).fontColor($r('app.color.strong'))
            .margin({ top: 8, bottom: 13 }).width('100%')
          if (this.entry.snapshot.description.length > 0) {
            Text(this.entry.snapshot.description).fontSize(13).lineHeight('23.4fp').fontColor($r('app.color.muted'))
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).wordBreak(WordBreak.BREAK_WORD)
              .width('100%').margin({ bottom: 13 })
          }
          Button({ type: ButtonType.Normal, stateEffect: !this.reducedMotion }) {
            Row({ space: 4 }) {
              Text('查看详情').fontSize(14).fontWeight(600).fontColor($r('app.color.text'))
              Image($r('app.media.icon_arrow_up_right')).width(13).height(13).objectFit(ImageFit.Contain)
                .fillColor($r('app.color.text')).accessibilityLevel('no')
            }
          }.id(`reward-details-${this.rewardId}`).constraintSize({ minHeight: 40 }).padding({ left: 14, right: 14 })
            .margin({ top: 12 }).borderRadius(10).backgroundColor(Color.Transparent)
            .accessibilityText(`查看${this.entry.snapshot.name}详情`)
            .onClick(() => { if (this.active) { this.model.open(this.rewardId); } })
        }.layoutWeight(1).constraintSize({ minWidth: 0 }).alignItems(HorizontalAlign.Start)
      }.id(`reward-card-${this.rewardId}`).width('100%').alignItems(VerticalAlign.Top).padding(20)
        .backgroundColor($r('app.color.surface'))
        .radialGradient({ center: ['0%', '0%'], radius: '65%',
          colors: [[$r('app.color.accent_faint'), 0], [Color.Transparent, 1]] })
        .border({ width: 1, radius: 18, color: this.entry.status === 'available' ?
          $r('app.color.accent_border') : $r('app.color.border') })
        .opacity(this.reducedMotion || this.revealed ? 1 : 0)
        .translate({ y: this.reducedMotion || this.revealed ? 0 : 14 })
        .animation(reveal(this.active && !this.reducedMotion, this.delay))
        .onAppear(() => this.updateReveal())
    }
  }
}

@ComponentV2
struct RewardLoadingCard {
  @Param animated: boolean = false;
  @Local private pulsed: boolean = false;

  build() {
    Row({ space: 16 }) {
      Column().width(70).height(110).borderRadius(10).backgroundColor($r('app.color.accent_soft'))
      Column({ space: 16 }) {
        Column().width('100%').height(47).borderRadius(10).backgroundColor($r('app.color.accent_soft'))
        Column().width('65%').height(47).borderRadius(10).backgroundColor($r('app.color.accent_soft'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').constraintSize({ minHeight: 160 }).padding(24).alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.surface')).border({ width: 1, color: $r('app.color.border'), radius: 18 })
      .opacity(this.animated ? (this.pulsed ? 0.85 : 0.4) : 1).accessibilityLevel('no-hide-descendants')
      .onAppear(() => {
        if (this.animated) {
          this.getUIContext().animateTo({ duration: 1000, iterations: -1, playMode: PlayMode.Alternate,
            curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) },
          () => UIUtils.applySync(() => { this.pulsed = true; }));
        }
      })
  }
}

@ComponentV2
struct RewardDetails {
  @Env(ReadonlyEnvKey.WINDOW_SIZE) windowSize: window.SizeInVP;
  @Env(ReadonlyEnvKey.WINDOW_AVOID_AREA) avoidArea: window.UIEnvWindowAvoidAreaInfoVP;
  @Require @Param reward: GameReward;
  @Require @Param displayFont: string;
  @Require @Param ownerValid: (id: string, player: string) => boolean;
  @Param active: boolean = false;
  @Param reducedMotion: boolean = true;
  @Event close: () => void = () => {};
  @Event openInternalLink: (href: string) => boolean = () => false;
  @Local private headerHeight: number = 60;
  @Local private detailRevision: number = 0;
  @Local private inlineSlot: string = '';
  private readonly imageCache: QuestionImageCache = new QuestionImageCache(() => this.ownerKey());
  @Local private image: StarwardImageViewerState = new StarwardImageViewerState(this.imageCache);
  @Local private video: StarwardVideoViewerState = new StarwardVideoViewerState();
  @Local private inlineVideo: StarwardVideoViewerState = new StarwardVideoViewerState(true);

  aboutToDisappear(): void { this.clearMedia(); }

  @Monitor('reward', 'active')
  private detailChanged(): void { this.clearMedia(); }

  private ownerKey(): string {
    return this.active ? `${this.reward.player}:${this.reward.id}:${this.detailRevision}` : '';
  }

  private current(owner: string): boolean {
    return this.active && owner.length > 0 && this.ownerKey() === owner &&
      this.ownerValid(this.reward.id, this.reward.player);
  }

  private clearMedia(): void {
    this.detailRevision++;
    this.image.close(this.image.sessionId, true);
    this.image.disappeared(this.image.sessionId);
    this.video.close(this.video.sessionId, true);
    this.inlineVideo.close(this.inlineVideo.sessionId, true);
    this.inlineSlot = '';
    this.imageCache.clear();
  }

  private showClaim(): boolean { return this.reward.status === 'available' && this.reward.claimDetails.length > 0; }

  private bottomPadding(): number {
    return Math.max(20, this.avoidArea.navigationIndicator.bottomRect.height);
  }

  private maximumBodyHeight(): number {
    const top: number = Math.max(this.avoidArea.statusBar.topRect.height, this.avoidArea.cutout.topRect.height);
    const bottom: number = this.avoidArea.navigationIndicator.bottomRect.height;
    const available: number = (this.windowSize.height - top - bottom) * 0.88 + bottom;
    return Math.max(80, available - this.headerHeight - DETAIL_TOP_PADDING);
  }

  private async openLink(href: string): Promise<void> {
    const owner: string = this.ownerKey();
    if (!this.current(owner)) { return; }
    try {
      if (isLegacyInternalLink(href)) {
        if (!this.openInternalLink(href) && this.current(owner)) {
          StarwardFeedback.toast(this.getUIContext(), '暂时无法打开链接，请重试。');
        }
      } else {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
        await openExternalClueLink(context, href);
      }
    } catch {
      if (this.current(owner)) { StarwardFeedback.toast(this.getUIContext(), '暂时无法打开链接，请重试。'); }
    }
  }

  private openImages(content: string, partIndex: number): void {
    const blocks: LegacyRichBlock[] = legacyRichBlocks(content);
    const sources: string[] = [];
    let selected: number = -1;
    blocks.forEach((block: LegacyRichBlock, index: number) => {
      if (block.kind === 'image') {
        if (index === partIndex) { selected = sources.length; }
        sources.push(block.url);
      }
    });
    if (selected < 0) { return; }
    this.inlineVideo.close(this.inlineVideo.sessionId, true);
    this.inlineSlot = '';
    const owner: string = this.ownerKey();
    this.image.open(sources, selected, () => this.current(owner));
  }

  private openVideo(content: string, nodeId: string, index: number, inline: boolean): void {
    const owner: string = this.ownerKey();
    const block: LegacyRichBlock | undefined = legacyRichBlocks(content)[index];
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!context || !block || block.kind !== 'video' || !this.current(owner)) { return; }
    this.inlineVideo.close(this.inlineVideo.sessionId, true);
    this.inlineSlot = '';
    const player: StarwardVideoViewerState = inline ? this.inlineVideo : this.video;
    const poster: QuestionImageResult | undefined = block.poster.length > 0 ? this.imageCache.acquire(block.poster) : undefined;
    const opened: boolean = player.open(block.url, context.cacheDir, () => this.current(owner),
      undefined, undefined, poster);
    poster?.release();
    if (inline && opened) { this.inlineSlot = `${nodeId}-video-${index}`; }
  }

  private modalTransition(): ModalTransition { return this.reducedMotion ? ModalTransition.NONE : ModalTransition.ALPHA; }

  private imageCoverOptions(): ContentCoverOptions {
    const sessionId: number = this.image.sessionId;
    return { backgroundColor: '#050605', enableSafeArea: false, modalTransition: this.modalTransition(),
      onWillDismiss: (action: DismissContentCoverAction) => { this.image.close(sessionId); action.dismiss(); },
      onDisappear: () => this.image.disappeared(sessionId) };
  }

  private videoCoverOptions(): ContentCoverOptions {
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
      motionEnabled: this.active && !this.reducedMotion && this.image.active(), close: () => this.image.close(this.image.sessionId) })
  }

  @Builder
  private videoCover() {
    StarwardVideoViewer({ model: this.video, sessionId: this.video.sessionId, reducedMotion: this.reducedMotion,
      motionEnabled: this.active && !this.reducedMotion && this.video.visible && !this.video.closing })
  }

  @Builder
  private rich(content: string, nodeId: string, cover: boolean = false) {
    StarwardRichContent({ content: content, nodeId: nodeId, ownerKey: this.ownerKey(),
      ownerIsCurrent: (owner: string) => this.current(owner), imageCache: this.imageCache,
      color: $r('app.color.text'), inlineVideo: this.inlineVideo, inlineVideoSlot: this.inlineSlot,
      active: this.active, maxMediaHeight: cover ? this.windowSize.height * 3 : 420,
      mediaMargin: cover ? 0 : 8, reducedMotion: this.reducedMotion,
      imageLabel: '奖品图片', videoPlayLabel: '播放奖品视频',
      openImage: (index: number) => this.openImages(content, index),
      openVideo: (index: number) => this.openVideo(content, nodeId, index, false),
      playVideo: (index: number) => this.openVideo(content, nodeId, index, true),
      openLink: (href: string) => { void this.openLink(href); } })
  }

  @Builder
  private header() {
    Row({ space: 12 }) {
      Text(this.reward.snapshot.name).id('rewards-detail-title').layoutWeight(1).fontFamily(this.displayFont)
        .fontSize(30).fontWeight(FontWeight.Medium).lineHeight('42fp').wordBreak(WordBreak.BREAK_WORD)
        .fontColor($r('app.color.strong')).margin({ top: 6 })
      Button({ type: ButtonType.Normal }) {
        Image($r('app.media.icon_close')).width(24).height(24).objectFit(ImageFit.Contain)
          .fillColor($r('app.color.muted')).accessibilityLevel('no')
      }.id('rewards-detail-close').width(44).height(44).padding(0).borderRadius(10)
        .backgroundColor($r('app.color.surface_hover')).accessibilityText('关闭详情').onClick(() => this.close())
    }.width('100%').alignItems(VerticalAlign.Top).padding({ bottom: 12 })
      .border({ width: { bottom: 1 }, color: $r('app.color.border_strong') })
      .onAreaChange((_old: Area, area: Area) => {
        const measured: number = Number(area.height);
        if (Number.isFinite(measured) && measured > 0 && Math.abs(measured - this.headerHeight) > 0.5) {
          this.headerHeight = measured;
        }
      })
  }

  build() {
    Column() {
      this.header()
      Scroll() {
        Column() {
          if (this.reward.snapshot.image.length > 0) {
            this.rich(`{{${this.reward.snapshot.image}}}`, 'rewards-detail-art', true)
          }
          if (this.reward.snapshot.description.length > 0) {
            Text(this.reward.snapshot.description).id('rewards-detail-description').fontSize(13).lineHeight('23.4fp')
              .fontColor($r('app.color.muted')).wordBreak(WordBreak.BREAK_WORD).width('100%').margin({ top: 8 })
          }
          if (this.reward.snapshot.publicInstructions.length > 0) {
            Column({ space: 12 }) {
              Text('领取指引').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.accent_text'))
              this.rich(this.reward.snapshot.publicInstructions, 'rewards-public-instructions')
            }.id('rewards-public-instructions-section').width('100%').alignItems(HorizontalAlign.Start)
              .padding({ top: 16 }).margin({ top: 20 })
              .border({ width: { top: 1 }, color: $r('app.color.border') })
          }
          if (this.showClaim()) {
            Column({ space: 12 }) {
              Text('你的领取线索').fontSize(15).fontWeight(FontWeight.Medium).fontColor($r('app.color.accent_text'))
              this.rich(this.reward.claimDetails, 'rewards-private-instructions')
            }.id('rewards-claim-details').width('100%').alignItems(HorizontalAlign.Start).padding(16).margin({ top: 20 })
              .backgroundColor($r('app.color.accent_faint')).border({ width: { left: 2 }, color: $r('app.color.accent') })
          }
          if (this.reward.redeemedAt.length > 0) {
            Text(`领取于 ${formattedRewardDate(this.reward.redeemedAt)}`).id('rewards-redeemed-at')
              .width('100%').fontSize(13).lineHeight('23.4fp').fontColor($r('app.color.muted')).margin({ top: 12 })
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 12, bottom: this.bottomPadding() })
      }.id('rewards-detail-scroll').width('100%').constraintSize({ maxHeight: this.maximumBodyHeight() })
        .align(Alignment.Top).scrollBar(BarState.Off)
      Column() {}.width(0).height(0).bindContentCover(this.image.visible, this.imageCover(), this.imageCoverOptions())
      Column() {}.width(0).height(0).bindContentCover(this.video.visible, this.videoCover(), this.videoCoverOptions())
    }.id('rewards-detail-sheet').width('100%').alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: DETAIL_TOP_PADDING })
  }
}

/** The collection uses the same native tab and refresh surfaces as other main destinations. */
@ComponentV2
export struct RewardsPage {
  @Require @Param model: RewardsViewModel;
  @Require @Param playerId: string;
  @Require @Param displayFont: string;
  @Param bottomClearance: number = 80;
  @Param reducedMotion: boolean = true;
  @Param active: boolean = false;
  @Param canReturnToAssignment: boolean = false;
  @Event returnHome: () => void = () => {};
  @Event returnToAssignment: () => void = () => {};
  @Event openInternalLink: (href: string) => boolean = () => false;
  @Local private revealed: boolean = false;
  @Local private detailVisible: boolean = false;
  private presentedDetail: string = '';
  private readonly artCache: QuestionImageCache = new QuestionImageCache(() => this.active ? this.playerId : '');

  aboutToDisappear(): void { this.artCache.clear(); }

  @Monitor('playerId', 'active')
  private scopeChanged(): void { this.artCache.validateOwner(); }

  @Monitor('active')
  private updateReveal(): void { UIUtils.applySync(() => { this.revealed = this.active; }); }

  private validOwner(owner: string): boolean { return this.active && owner.length > 0 && this.playerId === owner; }

  @Monitor('model.selected', 'playerId', 'active')
  private syncDetailVisibility(): void {
    const selected: GameReward | null = this.model.selected;
    if (selected === null || !this.validOwner(selected.player)) {
      this.presentedDetail = '';
      this.detailVisible = false;
      return;
    }
    const identity: string = `${selected.player}:${selected.id}`;
    // A live snapshot refresh must not reopen a sheet already dismissing this grant.
    if (identity !== this.presentedDetail) {
      this.presentedDetail = identity;
      this.detailVisible = true;
    }
  }

  @Builder
  private detail() {
    if (this.model.selected !== null && this.validOwner(this.model.selected.player)) {
      RewardDetails({ reward: this.model.selected, displayFont: this.displayFont, active: this.detailVisible,
        ownerValid: (id: string, player: string) => this.model.selected?.id === id && this.validOwner(player),
        reducedMotion: this.reducedMotion, close: () => { this.detailVisible = false; },
        openInternalLink: (href: string) => this.openInternalLink(href) })
    }
  }

  @Builder
  private heading() {
    Column() {
      Text('冒险的收获').fontSize(10).lineHeight('12fp').fontWeight(600).letterSpacing(1.4)
        .fontColor($r('app.color.accent_muted')).width('100%')
      Text('把奇遇，收入囊中。').fontFamily(this.displayFont).fontSize(28).lineHeight('40.6fp').letterSpacing('0.42fp')
        .fontWeight(FontWeight.Medium).fontColor($r('app.color.strong')).lineBreakStrategy(LineBreakStrategy.BALANCED)
        .width('100%').margin({ top: 6, bottom: 6 })
      Text('那些解开的谜，留下了这些礼物。').fontSize(14).lineHeight('26.6fp')
        .fontColor($r('app.color.muted')).width('100%')
    }.id('rewards-heading').width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 16 })
  }

  @Builder
  private empty() {
    Column({ space: 16 }) {
      Image($r('app.media.icon_compass_thin')).width(64).height(64).objectFit(ImageFit.Contain)
        .fillColor($r('app.color.accent_muted')).accessibilityLevel('no')
      Text('留个位置，给下一份惊喜。').fontFamily(this.displayFont).fontSize(21).lineHeight('31.5fp')
        .fontWeight(FontWeight.Medium).fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
      Text('还没有获得奖品。完成场次后，再来看看你的收获。').fontSize(13).lineHeight('24.7fp')
        .fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
      Button('去探索新的故事', { type: ButtonType.Normal }).id('rewards-explore').constraintSize({ minHeight: 46 })
        .fontSize(13).fontWeight(600).fontColor($r('app.color.accent_text')).padding({ left: 20, right: 20 }).borderRadius(10)
        .backgroundColor(Color.Transparent).border({ width: 1, color: $r('app.color.accent_border') })
        .onClick(() => this.returnHome())
    }.id('rewards-empty').width('100%').constraintSize({ minHeight: 280 })
      .padding({ top: 32, bottom: 32, left: 20, right: 20 }).justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.accent_faint')).borderRadius(18)
  }

  @Builder
  private content() {
    Scroll() {
      Column() {
        if (this.canReturnToAssignment) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 8 }) {
              Image($r('app.media.icon_arrow_left')).width(16).height(16).objectFit(ImageFit.Contain)
                .fillColor($r('app.color.accent_text')).accessibilityLevel('no')
              Text('返回当前场次').fontSize(13).fontColor($r('app.color.accent_text'))
            }
          }.id('rewards-return-assignment').constraintSize({ minHeight: 44 }).padding({ left: 0, right: 10 })
            .backgroundColor(Color.Transparent).margin({ bottom: 12 }).onClick(() => this.returnToAssignment())
        }
        this.heading()
        if (!this.model.loaded && this.model.error.length === 0 && this.active) {
          Column({ space: 16 }) {
            RewardLoadingCard({ animated: !this.reducedMotion })
            RewardLoadingCard({ animated: !this.reducedMotion })
          }.id('rewards-loading').width('100%').accessibilityText('正在打开你的收藏…').accessibilityLevel('yes')
        }
        if (this.model.error.length > 0) {
          Column() {
            ErrorNotice({ message: this.model.error, retryable: !this.model.loading, topMargin: 0,
              retry: () => { void this.model.refresh(); }, returnHome: () => this.returnHome() })
          }.id('rewards-error').width('100%')
        }
        if (this.model.entries.length > 0) {
          Column({ space: 16 }) {
            ForEach(this.model.entries, (reward: GameReward, index: number) => {
              RewardCard({ model: this.model, rewardId: reward.id, displayFont: this.displayFont, imageCache: this.artCache,
                ownerValid: (player: string) => this.validOwner(player), active: this.active,
                reducedMotion: this.reducedMotion, delay: index === 0 ? 0 : (index === 1 ? 70 : 120) })
            }, (reward: GameReward) => reward.id)
          }.id('rewards-list').width('100%')
        } else if (this.model.loaded && this.model.error.length === 0) {
          this.empty()
        }
      }.width('100%').constraintSize({ maxWidth: 760 }).alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, top: 16, bottom: this.bottomClearance })
    }.id('rewards-scroll').width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      StarwardRefresh({ refreshEnabled: this.active && !this.model.loading,
        request: async () => { await this.model.refresh(); }, content: () => { this.content() } })
    }.id('rewards-page').width('100%').height('100%')
      .opacity(this.reducedMotion || this.revealed ? 1 : 0)
      .translate({ y: this.reducedMotion || this.revealed ? 0 : 14 })
      .animation(reveal(this.active && !this.reducedMotion))
      .onAppear(() => { this.updateReveal(); this.syncDetailVisibility(); })
      .bindSheet(this.detailVisible!!, this.detail(), {
        height: SheetSize.FIT_CONTENT, preferType: SheetType.BOTTOM, dragBar: true, showClose: false,
        backgroundColor: $r('app.color.surface'), maskColor: $r('app.color.clue_mask'),
        onDisappear: () => { this.model.close(); }
      })
  }
}
