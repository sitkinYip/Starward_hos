import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { GameReward } from '../business/GameReward';
import { isLegacyInternalLink, legacyRichBlocks, LegacyRichBlock } from '../business/LegacyRichContent';
import { openExternalClueLink } from '../platform/ExternalClueLink';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { QuestionImageResult } from '../platform/QuestionImageLoader';
import { StarwardFeedback } from '../ui/StarwardFeedback';
import { StarwardImageViewer, StarwardImageViewerState } from '../ui/StarwardImageViewer';
import { starwardMediaCoverOptions } from '../ui/StarwardMediaCover';
import { StarwardRichContent } from '../ui/StarwardRichContent';
import { StarwardSheetHeader } from '../ui/StarwardSheet';
import { StarwardVideoViewer, StarwardVideoViewerState } from '../ui/StarwardVideoViewer';
import { STARWARD_RADIUS_CONTROL } from '../ui/StarwardRadii';

const rewardDate = new Intl.DateTimeFormat('zh-CN', {
  year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit'
});

function formattedRewardDate(value: string): string {
  const date: Date = new Date(value);
  return Number.isNaN(date.getTime()) ? '时间待确认' : rewardDate.format(date);
}

@ComponentV2
export struct RewardDetails {
  @Env(ReadonlyEnvKey.WINDOW_SIZE) windowSize: window.SizeInVP;
  @Env(ReadonlyEnvKey.WINDOW_AVOID_AREA) avoidArea: window.UIEnvWindowAvoidAreaInfoVP;
  @Require @Param reward: GameReward;
  @Require @Param ownerValid: (reward: GameReward) => boolean;
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
      this.ownerValid(this.reward);
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
    return Math.max(80, available - this.headerHeight);
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

  private imageCoverOptions(): ContentCoverOptions {
    const sessionId: number = this.image.sessionId;
    return starwardMediaCoverOptions(this.reducedMotion, (action: DismissContentCoverAction) => {
      this.image.close(sessionId);
      action.dismiss();
    }, () => this.image.disappeared(sessionId));
  }

  private videoCoverOptions(): ContentCoverOptions {
    const sessionId: number = this.video.sessionId;
    return starwardMediaCoverOptions(this.reducedMotion, (action: DismissContentCoverAction) => {
      if (!this.video.exitFullscreen(sessionId)) { this.video.close(sessionId); action.dismiss(); }
    }, () => this.video.disappeared(sessionId));
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
    StarwardSheetHeader({ title: this.reward.snapshot.name, titleId: 'rewards-detail-title',
      closeId: 'rewards-detail-close', closeLabel: '关闭详情', close: () => this.close() })
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
              .backgroundColor($r('app.color.reward_soft'))
              .border({ width: 1, radius: STARWARD_RADIUS_CONTROL, color: $r('app.color.reward_border') })
          }
          if (this.reward.redeemedAt.length > 0) {
            Text(`领取于 ${formattedRewardDate(this.reward.redeemedAt)}`).id('rewards-redeemed-at')
              .width('100%').fontSize(13).lineHeight('23.4fp').fontColor($r('app.color.muted')).margin({ top: 12 })
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
          .padding({ left: 16, right: 16, top: 12, bottom: this.bottomPadding() })
      }.id('rewards-detail-scroll').width('100%').constraintSize({ maxHeight: this.maximumBodyHeight() })
        .align(Alignment.Top).scrollBar(BarState.Off)
      Column() {}.width(0).height(0).bindContentCover(this.image.visible, this.imageCover(), this.imageCoverOptions())
      Column() {}.width(0).height(0).bindContentCover(this.video.visible, this.videoCover(), this.videoCoverOptions())
    }.id('rewards-detail-sheet').width('100%').alignItems(HorizontalAlign.Start)
  }
}
