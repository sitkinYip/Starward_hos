import { curves, LengthMetrics, SegmentButtonV2Items, UIUtils } from '@kit.ArkUI';
import { GameReward } from '../business/GameReward';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { InlineError } from '../ui/ErrorMessages';
import { starwardListReveal } from '../ui/StarwardMotion';
import { StarwardPageHeading } from '../ui/StarwardPageHeading';
import { StarwardRefresh } from '../ui/StarwardRefresh';
import { StarwardSyncNotice } from '../ui/StarwardSyncNotice';
import { StarwardCapsuleSegment, StarwardPaneTabs } from '../ui/StarwardTabs';
import {
  STARWARD_RADIUS_BADGE, STARWARD_RADIUS_CONTROL, STARWARD_RADIUS_PANEL, STARWARD_RADIUS_ROUND
} from '../ui/StarwardRadii';
import { RewardCard } from './RewardCard';
import { RewardDetails } from './RewardDetails';
import { RewardsViewModel } from './RewardsViewModel';

@ComponentV2
struct RewardLoadingCard {
  @Param animated: boolean = false;
  @Local private pulsed: boolean = false;

  build() {
    Column({ space: 12 }) {
      Column().width('100%').height(92).borderRadius(STARWARD_RADIUS_CONTROL)
        .backgroundColor($r('app.color.accent_soft'))
      Column().width('65%').height(18).borderRadius(STARWARD_RADIUS_BADGE).backgroundColor($r('app.color.accent_faint'))
    }.width('100%').alignItems(HorizontalAlign.Start).padding(12)
      .backgroundColor($r('app.color.glass_card_top'))
      .border({ width: 1, color: $r('app.color.border'), radius: STARWARD_RADIUS_PANEL })
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

/** The collection uses the same native tab and refresh surfaces as other main destinations. */
@ComponentV2
export struct RewardsPage {
  @Require @Param model: RewardsViewModel;
  @Require @Param playerId: string;
  @Param bottomClearance: number = 80;
  @Param reducedMotion: boolean = true;
  @Param active: boolean = false;
  @Param canReturnToAssignment: boolean = false;
  @Event returnHome: () => void = () => {};
  @Event returnToAssignment: () => void = () => {};
  @Event openInternalLink: (href: string) => boolean = () => false;
  @Local private revealed: boolean = false;
  @Local private selectedCategory: number = 0;
  @Local private detailVisible: boolean = false;
  private presentedDetail: string = '';
  private readonly artCache: QuestionImageCache = new QuestionImageCache(() => this.active ? this.playerId : '');
  private readonly categories: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '待领', accessibilityText: '待领' },
    { text: '已领', accessibilityText: '已领' }
  ]);

  @Computed
  get pendingRewards(): GameReward[] { return this.model.entries.filter((reward: GameReward) => reward.status === 'available'); }

  @Computed
  get claimedRewards(): GameReward[] { return this.model.entries.filter((reward: GameReward) => reward.status !== 'available'); }

  private selectCategory(index: number): void {
    if ((index === 0 || index === 1) && this.selectedCategory !== index) { this.selectedCategory = index; }
  }

  private categoryRewards(index: number): GameReward[] { return index === 0 ? this.pendingRewards : this.claimedRewards; }

  @Monitor('playerId')
  private ownerChanged(): void { this.selectedCategory = 0; }

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
      RewardDetails({ reward: this.model.selected, active: this.detailVisible,
        ownerValid: (reward: GameReward) => this.model.selected === reward && this.validOwner(reward.player),
        reducedMotion: this.reducedMotion, close: () => { this.detailVisible = false; },
        openInternalLink: (href: string) => this.openInternalLink(href) })
    }
  }

  @Builder
  private heading() {
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
      StarwardPageHeading({ title: '收藏', nodeId: 'rewards-heading' }).margin({ bottom: 16 })
      StarwardCapsuleSegment({ items: this.categories, selectedIndex: this.selectedCategory,
        nodeId: 'rewards-segment', reducedMotion: this.reducedMotion,
        selectionChanged: (index: number) => this.selectCategory(index) }).margin({ bottom: 18 })
    }.width('100%').constraintSize({ maxWidth: 760 }).alignItems(HorizontalAlign.Start)
      .padding({ left: 20, right: 20, top: 16 })
  }

  @Builder
  private empty() {
    Column({ space: 16 }) {
      Image($r('app.media.icon_compass_thin')).width(64).height(64).objectFit(ImageFit.Contain)
        .fillColor($r('app.color.accent_muted')).accessibilityLevel('no')
      Text('留个位置，给下一份惊喜。').fontSize(21).lineHeight('31.5fp')
        .fontWeight(FontWeight.Medium).fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
      Text('还没有获得奖品。完成场次后，再来看看你的收获。').fontSize(13).lineHeight('24.7fp')
        .fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
      Button('去探索新的故事', { type: ButtonType.Normal }).id('rewards-explore').constraintSize({ minHeight: 46 })
        .fontSize(13).fontWeight(600).fontColor($r('app.color.accent_text')).padding({ left: 20, right: 20 })
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: $r('app.color.accent_border'), radius: STARWARD_RADIUS_ROUND })
        .onClick(() => this.returnHome())
    }.id('rewards-empty').width('100%').constraintSize({ minHeight: 280 })
      .padding({ top: 32, bottom: 32, left: 20, right: 20 }).justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.accent_faint')).borderRadius(STARWARD_RADIUS_PANEL)
  }

  @Builder
  private emptyCategory(category: number) {
    Column({ space: 8 }) {
      Text(category === 0 ? '暂无待领收藏' : '暂无已领收藏')
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
      Text(category === 0 ? '所有已获得的收藏都已收好，可切换至「已领」查看。' :
        '完成领取后的纪念收藏会收录在这里。')
        .fontSize(13).lineHeight('22fp').fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
    }.id('rewards-category-empty').width('100%').constraintSize({ minHeight: 116 })
      .justifyContent(FlexAlign.Center).padding(16).backgroundColor($r('app.color.glass_card_top'))
      .border({ width: 1, radius: STARWARD_RADIUS_PANEL, color: $r('app.color.border') })
  }

  @Builder
  private content(category: number) {
    Scroll() {
      Column() {
        if (!this.model.loaded && this.model.error.length === 0 && this.active) {
          Row({ space: 12 }) {
            RewardLoadingCard({ animated: !this.reducedMotion }).layoutWeight(1)
            RewardLoadingCard({ animated: !this.reducedMotion }).layoutWeight(1)
          }.id('rewards-loading').width('100%').accessibilityText('正在打开你的收藏…').accessibilityLevel('yes')
        }
        if (this.model.error.length > 0) {
          Column({ space: 4 }) {
            InlineError({ message: this.model.error, fieldId: 'rewards-error-message' })
            Button('重新尝试', { type: ButtonType.Normal }).id('rewards-retry')
              .constraintSize({ minHeight: 44 }).borderRadius(STARWARD_RADIUS_ROUND).padding({ left: 12, right: 12 })
              .fontSize(13).fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
              .enabled(!this.model.loading).onClick(() => { void this.model.refresh(); })
          }.id('rewards-error').width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 12 })
        }
        if (this.categoryRewards(category).length > 0) {
          GridRow({ columns: 2, gutter: 12 }) {
            ForEach(this.categoryRewards(category), (reward: GameReward, index: number) => {
              GridCol({ span: 1 }) {
                RewardCard({ model: this.model, rewardId: reward.id, imageCache: this.artCache,
                  ownerValid: (player: string) => this.validOwner(player), active: this.active && this.selectedCategory === category,
                  reducedMotion: this.reducedMotion, delay: index === 0 ? 0 : (index === 1 ? 70 : 120) })
              }
            }, (reward: GameReward) => reward.id)
          }.id('rewards-list').width('100%')
        } else if (this.model.loaded && this.model.error.length === 0) {
          if (this.model.entries.length === 0) { this.empty() }
          else { this.emptyCategory(category) }
        }
      }.width('100%').constraintSize({ maxWidth: 760 }).alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, bottom: this.bottomClearance })
    }.id(category === 0 ? 'rewards-pending-scroll' : 'rewards-claimed-scroll')
      .width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  @Builder
  private pane(category: number) {
    StarwardRefresh({ refreshEnabled: this.active && this.selectedCategory === category && !this.model.loading,
      request: async () => { await this.model.refresh(); }, content: () => { this.content(category) } })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        this.heading()
        StarwardPaneTabs({ selectedIndex: this.selectedCategory, reducedMotion: this.reducedMotion, nodeId: 'rewards-panes',
          selectionChanged: (index: number) => this.selectCategory(index),
          first: () => { this.pane(0) }, second: () => { this.pane(1) } }).layoutWeight(1)
      }.width('100%').height('100%')
      if (this.active && !this.detailVisible && this.model.showSyncNotice) {
        Column() {
          StarwardSyncNotice({ nodePrefix: 'rewards-sync-notice', reducedMotion: this.reducedMotion,
            description: '当前收藏仍可查看，连接恢复后会自动同步。', dismiss: () => this.model.dismissSyncNotice() })
        }.width('100%').alignItems(HorizontalAlign.Center)
          .padding({ left: 16, right: 16 }).margin({ top: 8 })
          .hitTestBehavior(HitTestMode.Transparent).zIndex(2)
      }
    }.id('rewards-page').width('100%').height('100%')
      .opacity(this.reducedMotion || this.revealed ? 1 : 0)
      .translate({ y: this.reducedMotion || this.revealed ? 0 : 14 })
      .animation(starwardListReveal(this.active && !this.reducedMotion))
      .onAppear(() => { this.updateReveal(); this.syncDetailVisibility(); })
      .bindSheet(this.detailVisible!!, this.detail(), {
        height: SheetSize.FIT_CONTENT, preferType: SheetType.BOTTOM, dragBar: true, showClose: false,
        radius: LengthMetrics.vp(STARWARD_RADIUS_PANEL),
        backgroundColor: $r('app.color.raised'), blurStyle: BlurStyle.Thin, maskColor: $r('app.color.modal_mask'),
        onDisappear: () => { this.model.close(); }
      })
  }
}
