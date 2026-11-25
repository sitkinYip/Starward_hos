import { curves, UIUtils } from '@kit.ArkUI';
import { GameReward, RewardStatus } from '../business/GameReward';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { QuestionImageLoader, QuestionImageResult } from '../platform/QuestionImageLoader';
import { starwardListReveal } from '../ui/StarwardMotion';
import { RewardsViewModel } from './RewardsViewModel';

function rewardStatus(status: RewardStatus): string {
  switch (status) {
    case 'available': return '礼物待领取';
    case 'redeemed': return '已领取 · 已核销';
    case 'voided': return '已失效';
  }
}

// Motion Prompt #022 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#022
@ComponentV2
struct RewardSweep {
  @Require @Param cardWidth: number;
  @Require @Param cardHeight: number;
  @Local private travel: number = 0;
  @Local private strength: number = 0;

  private play(): void {
    const curve = curves.cubicBezierCurve(0.45, 0.05, 0.55, 0.95);
    this.getUIContext().keyframeAnimateTo({ iterations: -1 }, [
      { duration: 1, event: () => UIUtils.applySync(() => { this.travel = 0; this.strength = 0; }) },
      { duration: 755, event: () => {} },
      { duration: 1008, curve, event: () => UIUtils.applySync(() => { this.travel = 0.8; this.strength = 0.58; }) },
      { duration: 1344, curve, event: () => UIUtils.applySync(() => { this.travel = 1.72; this.strength = 0; }) },
      { duration: 1092, event: () => {} }
    ]);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column().width(this.cardWidth * 0.44).height(this.cardHeight * 1.8)
        .position({ x: -0.52 * this.cardWidth, y: -0.4 * this.cardHeight })
        .linearGradient({ direction: GradientDirection.Right, colors: [
          [$r('app.color.reward_sweep_clear'), 0], [$r('app.color.reward_sweep_soft'), 0.27],
          [$r('app.color.reward_sweep'), 0.52], [$r('app.color.reward_sweep_soft'), 0.73],
          [$r('app.color.reward_sweep_clear'), 1]
        ] })
        .rotate({ angle: 24 }).translate({ x: this.cardWidth * this.travel }).opacity(this.strength)
    }.id('rewards-card-sweep').width(this.cardWidth).height(this.cardHeight).clip(true)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants').onAppear(() => this.play())
  }
}

@ComponentV2
struct RewardThumbnail {
  @Require @Param source: string;
  @Require @Param nodeId: string;
  @Require @Param owner: string;
  @Require @Param imageCache: QuestionImageCache;
  @Require @Param ownerValid: (owner: string) => boolean;
  @Param pending: boolean = false;
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
    if (!this.inView || this.value !== undefined || this.source.length === 0) { return; }
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
        Image(this.value.pixels).id(this.nodeId).width('100%').height(92).objectFit(ImageFit.Cover).draggable(false)
          .accessibilityLevel('no')
      } else {
        Image($r('app.media.icon_sparkle')).width(44).height(44).objectFit(ImageFit.Contain)
          .fillColor(this.pending ? $r('app.color.reward') : $r('app.color.accent_text')).accessibilityLevel('no')
      }
    }.width('100%').height(92).borderRadius(16).clip(true)
      .backgroundColor(this.pending ? $r('app.color.reward_soft') : $r('app.color.accent_soft'))
      .onVisibleAreaChange([0], (_expanded: boolean, ratio: number) => {
        const entered: boolean = ratio > 0 && !this.inView;
        this.inView = ratio > 0;
        if (entered) { void this.load(); }
      })
  }
}

/** One collection card. The model owns details and the session owns the disposable image cache. */
@ComponentV2
export struct RewardCard {
  @Require @Param model: RewardsViewModel;
  @Require @Param rewardId: string;
  @Require @Param imageCache: QuestionImageCache;
  @Require @Param ownerValid: (owner: string) => boolean;
  @Param active: boolean = false;
  @Param reducedMotion: boolean = true;
  @Param delay: number = 0;
  @Local private revealed: boolean = false;
  @Local private inView: boolean = false;
  @Local private cardWidth: number = 0;
  @Local private cardHeight: number = 0;

  @Computed
  get entry(): GameReward | undefined { return this.model.entries.find((item: GameReward) => item.id === this.rewardId); }

  @Computed
  get pending(): boolean { return this.entry?.status === 'available'; }

  @Monitor('active')
  private updateReveal(): void { UIUtils.applySync(() => { this.revealed = this.active; }); }

  @Builder
  private sweep() {
    if (this.pending && this.active && this.inView && !this.reducedMotion &&
      this.cardWidth > 0 && this.cardHeight > 0) {
      RewardSweep({ cardWidth: this.cardWidth, cardHeight: this.cardHeight })
    }
  }

  build() {
    if (this.entry !== undefined) {
      Column() {
        Button({ type: ButtonType.Normal, stateEffect: !this.reducedMotion }) {
          Column({ space: 12 }) {
            RewardThumbnail({ source: this.entry.snapshot.image, owner: this.entry.player,
              nodeId: 'reward-thumbnail-' + this.rewardId, imageCache: this.imageCache,
              ownerValid: this.ownerValid, active: this.active, pending: this.pending })
            Row({ space: 8 }) {
              Text(this.entry.snapshot.name).fontSize(15).fontWeight(FontWeight.Medium)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('app.color.strong'))
                .layoutWeight(1).constraintSize({ minWidth: 0 })
              Text('×' + this.entry.quantity.toString()).fontSize(13).fontFeature("'tnum' 1").fontWeight(FontWeight.Medium)
                .fontColor(this.pending ? $r('app.color.reward') : $r('app.color.muted')).flexShrink(0)
            }.width('100%')
          }.width('100%').padding(12)
        }.id('reward-details-' + this.rewardId).width('100%').padding(0).backgroundColor(Color.Transparent)
          .accessibilityText('查看' + this.entry.snapshot.name + '详情，' + rewardStatus(this.entry.status) + '，数量 ' +
            this.entry.quantity.toString())
          .onClick(() => { if (this.active) { this.model.open(this.rewardId); } })
      }.id('reward-card-' + this.rewardId).width('100%').backgroundColor($r('app.color.glass_card_top'))
        .background(this.sweep(), { align: Alignment.TopStart })
        .border({ width: 1, radius: 24, color: this.pending ? $r('app.color.reward_border') : $r('app.color.border') })
        .borderRadius(24).clip(true)
        .shadow({ radius: this.pending ? 14 : 8, offsetY: 5,
          color: this.pending ? $r('app.color.reward_glow') : $r('app.color.shadow') })
        .opacity(this.reducedMotion || this.revealed ? 1 : 0)
        .translate({ y: this.reducedMotion || this.revealed ? 0 : 14 })
        .animation(starwardListReveal(this.active && !this.reducedMotion, this.delay))
        .onAppear(() => this.updateReveal())
        .onAreaChange((_previous: Area, current: Area) => {
          const width: number = Number(current.width);
          const height: number = Number(current.height);
          if (Number.isFinite(width) && width > 0) { this.cardWidth = width; }
          if (Number.isFinite(height) && height > 0) { this.cardHeight = height; }
        })
        .onVisibleAreaChange([0], (visible: boolean, ratio: number) => { this.inView = visible && ratio > 0; })
    }
  }
}
