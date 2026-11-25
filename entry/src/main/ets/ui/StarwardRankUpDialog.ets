import { curves, UIUtils } from '@kit.ArkUI';
import { StarwardRankCrest } from './StarwardRankCrest';

const PANEL_RADIUS: number = 24;

// Motion Prompt #022 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#022
@ComponentV2
struct RankPanelSweep {
  @Require @Param panelWidth: number;
  @Require @Param panelHeight: number;
  @Local private travel: number = 0;
  @Local private strength: number = 0;

  private play(): void {
    const context: UIContext = this.getUIContext();
    const impact = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
    context.keyframeAnimateTo({ delay: 260, iterations: 1 }, [
      { duration: 432, event: () => {} },
      { duration: 1392, curve: impact, event: () => UIUtils.applySync(() => { this.travel = 4.6; }) },
      { duration: 576, event: () => {} }
    ]);
    context.keyframeAnimateTo({ delay: 260, iterations: 1 }, [
      { duration: 432, event: () => {} },
      { duration: 576, curve: impact, event: () => UIUtils.applySync(() => { this.strength = 0.68; }) },
      { duration: 816, curve: impact, event: () => UIUtils.applySync(() => { this.strength = 0; }) },
      { duration: 576, event: () => {} }
    ]);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column().width(this.panelWidth * 0.34).height(this.panelHeight * 1.4)
        .position({ x: this.panelWidth * -0.42, y: this.panelHeight * -0.2 })
        .linearGradient({ direction: GradientDirection.Right, colors: [[$r('app.color.reward_sweep_clear'), 0],
          [$r('app.color.reward_sweep_soft'), 0.25], [$r('app.color.reward_sweep'), 0.5],
          [$r('app.color.reward_sweep_soft'), 0.75], [$r('app.color.reward_sweep_clear'), 1]] })
        .rotate({ angle: 18 }).translate({ x: this.panelWidth * 0.34 * this.travel }).opacity(this.strength)
    }.id('gameplay-rank-up-sweep').width(this.panelWidth).height(this.panelHeight).clip(true)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      .onAppear(() => this.play())
  }
}

@ComponentV2
struct RankUpCopy {
  @Require @Param rankOrder: number;
  @Require @Param rankName: string;
  @Require @Param headingSize: number;
  @Require @Param opening: boolean;
  @Local private revealed: boolean = false;

  private play(): void {
    if (!this.opening) { return; }
    this.getUIContext().animateTo({ delay: 140, duration: 460,
      curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) },
      () => UIUtils.applySync(() => { this.revealed = true; }));
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Polygon().points([[6, 0], [7.6, 4.4], [12, 6], [7.6, 7.6], [6, 12],
          [4.4, 7.6], [0, 6], [4.4, 4.4]]).width(12).height(12)
          .fill($r('app.color.reward')).strokeWidth(0).accessibilityLevel('no')
        Text('等级突破').fontSize(12).fontWeight(FontWeight.Bold).letterSpacing(0.96)
          .fontColor($r('app.color.reward'))
      }.id('gameplay-rank-up-badge').padding({ top: 5, bottom: 5, left: 14, right: 14 }).borderRadius(999)
        .backgroundColor($r('app.color.reward_soft'))
        .border({ width: 1, color: $r('app.color.reward_border') })
      Text(this.rankName).id('gameplay-rank-up-title').width('100%')
        .fontSize(this.headingSize).lineHeight(this.headingSize * 1.2).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.strong')).letterSpacing(-0.02 * this.headingSize)
        .textShadow({ radius: 16, color: $r('app.color.reward_glow') })
        .textAlign(TextAlign.Center).wordBreak(WordBreak.BREAK_WORD).lineBreakStrategy(LineBreakStrategy.BALANCED)
      Text('Lv.' + this.rankOrder + ' · 新的冒险等级已经生效').id('gameplay-rank-up-detail')
        .width('100%').fontSize(14).lineHeight('22.4fp').fontFeature("'tnum' 1")
        .fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
    }.width('100%').alignItems(HorizontalAlign.Center)
      .opacity(this.opening && !this.revealed ? 0 : 1).translate({ y: this.opening && !this.revealed ? 14 : 0 })
      .onAppear(() => this.play())
  }
}

/** The native dialog host owns presentation and acknowledgement. */
@ComponentV2
export struct StarwardRankUpDialog {
  @Require @Param rankOrder: number;
  @Require @Param rankName: string;
  @Require @Param panelWidth: number;
  @Require @Param maxHeight: number;
  @Require @Param viewportWidth: number;
  @Param displayFont: string = '';
  @Param motionEnabled: boolean = false;
  @Event acknowledge: () => void = () => {};
  @Local private panelHeight: number = 0;
  @Local private opening: boolean = false;

  aboutToAppear(): void { this.opening = this.motionEnabled; }

  @Monitor('motionEnabled')
  private motionChanged(): void {
    if (!this.motionEnabled) { this.opening = false; }
  }

  private compact(): boolean { return this.viewportWidth <= 620; }

  private contentWidth(): number {
    return Math.max(1, Math.min(440, this.panelWidth, this.viewportWidth - (this.compact() ? 32 : 40)));
  }

  private sideInset(): number {
    return Math.min(this.contentWidth() * 0.18, this.compact() ? 20 : Math.max(22, Math.min(34, this.viewportWidth * 0.05)));
  }

  @Builder
  private panelLight() {
    Stack() {
      Column().width(this.contentWidth()).height(this.panelHeight)
        .radialGradient({ center: ['50%', '18%'], radius: '54%',
          colors: [[$r('app.color.reward_soft'), 0], [Color.Transparent, 0.8]] })
      Column().width(this.contentWidth()).height(this.panelHeight)
        .radialGradient({ center: ['50%', '88%'], radius: '54%',
          colors: [[$r('app.color.accent_faint'), 0], [Color.Transparent, 0.82]] })
    }.id('gameplay-rank-up-decoration').width(this.contentWidth()).height(this.panelHeight)
      .position({ x: 0, y: 0 }).hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }

  @Builder
  private scrollContent() {
    Scroll() {
      Column({ space: this.compact() ? 12 : 14 }) {
        StarwardRankCrest({ rankOrder: this.rankOrder,
          stageSize: Math.min(this.compact() ? 196 : 228, this.contentWidth()),
          badgeSize: this.compact() ? 68 : 78, motionEnabled: this.motionEnabled })
        RankUpCopy({ rankOrder: this.rankOrder, rankName: this.rankName,
          headingSize: Math.max(28, Math.min(38, this.viewportWidth * 0.064)), opening: this.opening && this.motionEnabled })
        Button('继续冒险', { type: ButtonType.Capsule, stateEffect: this.motionEnabled })
          .id('gameplay-rank-up-ack').constraintSize({ minHeight: 48,
            minWidth: Math.max(1, Math.min(204, this.contentWidth() - 2 * this.sideInset() - 2)) })
          .padding({ left: 20, right: 20, top: 8, bottom: 8 }).margin({ top: 6 })
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.on_accent'))
          .backgroundColor($r('app.color.accent'))
          .linearGradient({ angle: 180, colors: [[$r('app.color.accent_strong'), 0], [$r('app.color.accent'), 1]] })
          .shadow({ radius: 18, offsetY: 6, color: $r('app.color.glow_accent') })
          .defaultFocus(true).onClick(() => this.acknowledge())
      }.width('100%').alignItems(HorizontalAlign.Center)
        .padding({ top: this.compact() ? 26 : 40, bottom: this.compact() ? 24 : 34,
          left: this.sideInset(), right: this.sideInset() })
    }.id('gameplay-rank-up-scroll').width('100%').constraintSize({ maxHeight: Math.max(1, this.maxHeight - 2) })
      .align(Alignment.Top).scrollBar(BarState.Auto)
  }

  build() {
    Column() {
      Column() {
        if (this.panelHeight > 0) {
          this.panelLight()
          if (this.opening && this.motionEnabled) {
            RankPanelSweep({ panelWidth: this.contentWidth(), panelHeight: this.panelHeight }).position({ x: 0, y: 0 })
          }
        }
        this.scrollContent()
      }.id('gameplay-rank-up').width(this.contentWidth())
        .backgroundColor($r('app.color.rank_up_surface'))
        .border({ width: 1, radius: PANEL_RADIUS, color: $r('app.color.reward_border') })
        .borderRadius(PANEL_RADIUS).clip(true)
        .shadow({ radius: 36, offsetY: 12, color: $r('app.color.reward_glow') })
        .onAreaChange((_previous: Area, current: Area) => {
          const height: number = Number(current.height);
          if (Number.isFinite(height) && height > 0 && height !== this.panelHeight) { this.panelHeight = height; }
        })
    }.width(this.panelWidth).alignItems(HorizontalAlign.Center)
  }
}
