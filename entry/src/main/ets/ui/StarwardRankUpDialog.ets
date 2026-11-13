import { curves, UIUtils } from '@kit.ArkUI';

const RAY_ANGLES: number[] = [8, 26, 44, 62, 80, 98, 116, 134, 152, 170];

@ComponentV2
struct StarwardRankUpRays {
  @Require @Param panelWidth: number;
  @Require @Param panelHeight: number;
  @Param animated: boolean = false;
  @Local private turn: number = 0;

  private span(): number { return Math.hypot(this.panelWidth, this.panelHeight) * 1.08; }

  build() {
    Stack() {
      ForEach(RAY_ANGLES, (angle: number) => {
        Column() {}
          .width(this.span()).height(2)
          .linearGradient({ direction: GradientDirection.Right, colors: [[Color.Transparent, 0],
            [$r('app.color.accent'), 0.32], [$r('app.color.accent'), 0.68], [Color.Transparent, 1]] })
          .rotate({ angle: angle })
      }, (angle: number) => angle.toString())
    }.id('gameplay-rank-up-rays').width(this.panelWidth).height(this.panelHeight).opacity(0.075).blur(1)
      .rotate({ angle: this.turn }).scale({ x: 1 + this.turn / 9000, y: 1 + this.turn / 9000 })
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      .onAppear(() => {
        if (!this.animated) { return; }
        this.getUIContext().animateTo({ duration: 18000, iterations: -1,
          curve: curves.cubicBezierCurve(0.45, 0.02, 0.55, 0.98) }, () => UIUtils.applySync(() => {
          this.turn = 360;
        }));
      })
  }
}

@ComponentV2
struct StarwardRankUpSweep {
  @Require @Param panelWidth: number;
  @Require @Param panelHeight: number;
  @Local private travel: number = 0;
  @Local private strength: number = 0;

  private start(): void {
    const context = this.getUIContext();
    const impact = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
    context.keyframeAnimateTo({ delay: 420, iterations: 1 }, [
      { duration: 396, curve: impact, event: () => UIUtils.applySync(() => {
        this.travel = 0;
        this.strength = 0;
      }) },
      { duration: 528, curve: impact, event: () => UIUtils.applySync(() => {
        this.travel = 0.57;
        this.strength = 0.18;
      }) },
      { duration: 748, curve: impact, event: () => UIUtils.applySync(() => {
        this.travel = 1.38;
        this.strength = 0;
      }) },
      { duration: 528, curve: impact, event: () => UIUtils.applySync(() => {
        this.travel = 1.38;
        this.strength = 0;
      }) }
    ]);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {}
        .width(this.panelWidth * 0.38).height(this.panelHeight * 1.36)
        .position({ x: this.panelWidth * -0.35, y: this.panelHeight * -0.18 })
        .linearGradient({ direction: GradientDirection.Right, colors: [[Color.Transparent, 0],
          [$r('app.color.strong'), 0.42], [$r('app.color.strong'), 0.64], [Color.Transparent, 1]] })
        .rotate({ angle: 18 }).translate({ x: this.panelWidth * this.travel }).opacity(this.strength)
    }.id('gameplay-rank-up-sweep').width(this.panelWidth).height(this.panelHeight).clip(true)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants').onAppear(() => this.start())
  }
}

@ComponentV2
struct StarwardRankUpOrbits {
  @Require @Param geometryScale: number;
  @Param animated: boolean = false;
  @Local private middleTurn: number = 0;
  @Local private outerTurn: number = 0;
  @Local private pulse: boolean = false;

  private start(): void {
    if (!this.animated) { return; }
    const context = this.getUIContext();
    context.animateTo({ duration: 12000, iterations: -1, curve: Curve.Linear }, () => UIUtils.applySync(() => {
      this.middleTurn = 360;
    }));
    context.animateTo({ duration: 8000, iterations: -1, curve: Curve.Linear }, () => UIUtils.applySync(() => {
      this.outerTurn = -360;
    }));
    context.animateTo({ duration: 2400, iterations: -1, playMode: PlayMode.Alternate,
      curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) }, () => UIUtils.applySync(() => {
      this.pulse = true;
    }));
  }

  build() {
    Stack() {
      Circle().width(188 * this.geometryScale).height(188 * this.geometryScale).fill(Color.Transparent)
        .stroke($r('app.color.accent')).strokeWidth(1).strokeDashArray([1, 2]).opacity(0.18)
        .rotate({ angle: this.outerTurn })
      Circle().width(154 * this.geometryScale).height(154 * this.geometryScale).fill(Color.Transparent)
        .stroke($r('app.color.accent')).strokeWidth(1).strokeDashArray([4, 3]).opacity(0.58)
        .rotate({ angle: this.middleTurn })
      Circle().width(128 * this.geometryScale).height(128 * this.geometryScale).fill(Color.Transparent)
        .stroke($r('app.color.accent')).strokeWidth(1).opacity(0.32)
      Circle().width(120 * this.geometryScale).height(120 * this.geometryScale).fill(Color.Transparent)
        .stroke($r('app.color.accent')).strokeWidth(1).opacity(this.pulse ? 0.33 : 0.1)
        .scale({ x: this.pulse ? 1.12 : 1, y: this.pulse ? 1.12 : 1 })
    }.id('gameplay-rank-up-orbits').width(188 * this.geometryScale).height(188 * this.geometryScale)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants').onAppear(() => this.start())
  }
}

@ComponentV2
struct StarwardRankUpEmblem {
  @Require @Param rankOrder: number;
  @Require @Param compact: boolean;
  @Require @Param motionEnabled: boolean;

  private factor(): number { return this.compact ? 0.88 : 1; }
  private emblemWidth(): number { return this.compact ? 186 : 214; }
  private emblemHeight(): number { return this.compact ? 134 : 180; }
  private coreSize(): number { return 96 * this.factor(); }

  @Builder
  wing(length: number, angle: number) {
    Column() {}
      .width(length * this.factor()).height(1)
      .linearGradient({ direction: GradientDirection.Right,
        colors: [[Color.Transparent, 0], [$r('app.color.accent'), 1]] })
      .position({ x: this.emblemWidth() / 2 - (52 + length) * this.factor(),
        y: this.emblemHeight() / 2 })
      .rotate({ angle: angle, centerX: length * this.factor(), centerY: 0.5 })
      .shadow({ radius: 18, color: $r('app.color.rank_up_glow') })
  }

  build() {
    Stack() {
      Column() {}
        .width(206 * this.factor()).height(206 * this.factor())
        .radialGradient({ center: ['50%', '50%'], radius: 103 * this.factor(),
          colors: [[$r('app.color.rank_up_glow'), 0], [$r('app.color.accent_soft'), 0.62],
            [Color.Transparent, 1]] })
      this.wing(58, 28)
      this.wing(42, -22)
      if (this.motionEnabled) {
        StarwardRankUpOrbits({ geometryScale: this.factor(), animated: true })
      } else {
        StarwardRankUpOrbits({ geometryScale: this.factor() })
      }
      // The frozen Web's four overlapping frame corners read as a register mark above the medallion.
      Stack() {
        Column() {}.width(68).height(4).backgroundColor($r('app.color.accent'))
        Column() {}.width(4).height(68).backgroundColor($r('app.color.accent'))
      }.width(68).height(68).opacity(0.72)
        .position({ x: this.emblemWidth() / 2 - 22, y: this.emblemHeight() / 2 - (this.compact ? 99 : 111) })
      // The counter-rotation in Web cancels the parent orbit: text remains still.
      Column({ space: 2 }) {
        Text('RANK').fontFamily('monospace').fontSize(9 * this.factor()).letterSpacing('1.6fp')
          .fontColor($r('app.color.accent_text'))
        Text(`${this.rankOrder}`).fontSize(40 * this.factor()).fontWeight(FontWeight.Bold)
          .lineHeight(`${40 * this.factor()}fp`).letterSpacing(`${-2.4 * this.factor()}fp`)
          .fontColor($r('app.color.accent_text')).textAlign(TextAlign.Center)
      }.width(this.coreSize()).height(this.coreSize()).justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.inset')).borderRadius(this.coreSize() / 2)
        .radialGradient({ center: ['50%', '50%'], radius: this.coreSize() / 2,
          colors: [[$r('app.color.accent_soft'), 0], [Color.Transparent, 0.72]] })
        .border({ width: 1, radius: this.coreSize() / 2, color: $r('app.color.accent') })
        .shadow({ radius: this.getUIContext().vp2px(28), color: $r('app.color.rank_up_glow') })
        .accessibilityLevel('no-hide-descendants')
    }.id('gameplay-rank-up-emblem').width(this.emblemWidth()).height(this.emblemHeight()).clip(false)
      .margin({ bottom: this.compact ? 0 : 4 }).hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no')
  }
}

/** Branded content of the native rank-up dialog. Presentation and acknowledgement belong to the host. */
@ComponentV2
export struct StarwardRankUpDialog {
  @Require @Param rankOrder: number;
  @Require @Param rankName: string;
  @Require @Param panelWidth: number;
  @Require @Param maxHeight: number;
  @Require @Param viewportWidth: number;
  @Param displayFont: string = 'serif';
  @Param motionEnabled: boolean = false;
  @Event acknowledge: () => void = () => {};
  @Local private panelHeight: number = 0;
  private maySweep: boolean = false;

  aboutToAppear(): void { this.maySweep = this.motionEnabled; }

  @Monitor('motionEnabled')
  private motionPolicyChanged(): void {
    if (!this.motionEnabled) { this.maySweep = false; }
  }

  private compact(): boolean { return this.viewportWidth <= 620; }
  private wideInset(): number { return Math.max(34, Math.min(62, this.viewportWidth * 0.06)); }
  private inset(): number { return Math.min(this.panelWidth * 0.18, this.compact() ? 22 : this.wideInset()); }
  private titleSize(): number { return Math.max(44, Math.min(76, this.viewportWidth * 0.09)); }

  @Builder
  ornament() {
    Stack() {
      Column() {}
        .width('100%').height('100%')
        .radialGradient({ center: ['50%', '0%'], radius: Math.hypot(this.panelWidth / 2, this.panelHeight) * 0.43,
          colors: [[$r('app.color.accent_soft'), 0], [Color.Transparent, 1]] })
      if (this.motionEnabled) {
        StarwardRankUpRays({ panelWidth: this.panelWidth, panelHeight: this.panelHeight, animated: true })
        if (this.maySweep) {
          StarwardRankUpSweep({ panelWidth: this.panelWidth, panelHeight: this.panelHeight })
        }
        Particle({
          particles: [{
            emitter: {
              particle: { type: ParticleType.POINT, config: { radius: 1.5 }, count: -1, lifetime: 3800 },
              emitRate: this.compact() ? 2 : 5, position: ['50%', '54%'], size: [1, 1]
            },
            color: { range: ['#E0C67D', '#E0C67D'] },
            velocity: { speed: [48, 75], angle: [0, 360] },
            opacity: { range: [0, 0], updater: { type: ParticleUpdater.CURVE, config: [
              { from: 0, to: 0.85, startMillis: 0, endMillis: 836, curve: Curve.EaseOut },
              { from: 0.85, to: 0.22, startMillis: 836, endMillis: 2964, curve: Curve.EaseOut },
              { from: 0.22, to: 0, startMillis: 2964, endMillis: 3800, curve: Curve.EaseIn }
            ] } }
          }]
        }).id('gameplay-rank-up-particles').width('100%').height('100%')
      } else {
        StarwardRankUpRays({ panelWidth: this.panelWidth, panelHeight: this.panelHeight })
      }
    }.id('gameplay-rank-up-decoration').width(this.panelWidth).height(this.panelHeight)
      .clip(true).position({ x: 0, y: 0 }).hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no-hide-descendants')
  }

  @Builder
  frame() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {}
        .width(this.panelWidth - 14).height(this.panelHeight - 14)
        .border({ width: 1, color: $r('app.color.strong'), radius: 11 }).opacity(0.05)
        .position({ x: 7, y: 7 })
    }.width(this.panelWidth).height(this.panelHeight).position({ x: 0, y: 0 })
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }

  @Builder
  status() {
    Row({ space: 12 }) {
      Stack() {
        Column() {}.width(24).height(24)
          .radialGradient({ center: ['50%', '50%'], radius: 12,
            colors: [[$r('app.color.rank_up_glow'), 0], [Color.Transparent, 1]] })
        Polygon().width(24).height(24)
          .points([[14, 1], [4, 13], [10, 15], [9, 23], [20, 11], [13, 9]])
          .fill($r('app.color.accent_text')).strokeWidth(0)
      }.width(24).height(24).accessibilityLevel('no-hide-descendants')
      Column({ space: 3 }) {
        Text(`RANK ${this.rankOrder}`).id('gameplay-rank-up-order').fontFamily('monospace')
          .fontSize(12).lineHeight('14.4fp').fontWeight(600).letterSpacing('1.44fp')
          .fontColor($r('app.color.accent_text'))
        Text('能力权限已同步').fontSize(11).lineHeight('15.4fp').fontColor($r('app.color.muted'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.id('gameplay-rank-up-status').width('100%').constraintSize({ maxWidth: 320 })
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.accent_faint'))
      .border({ width: 1, radius: 10, color: $r('app.color.accent_border') })
  }

  @Builder
  content() {
    Scroll() {
      Column({ space: this.compact() ? 10 : 12 }) {
        StarwardRankUpEmblem({ rankOrder: this.rankOrder, compact: this.compact(), motionEnabled: this.motionEnabled })
        Text('等级突破').id('gameplay-rank-up-eyebrow').fontFamily('monospace')
          .fontSize(12).lineHeight('14.4fp').fontWeight(600).letterSpacing('2.64fp')
          .fontColor($r('app.color.accent_text')).textAlign(TextAlign.Center)
        Text(this.rankName).id('gameplay-rank-up-title').width('100%')
          .fontFamily(this.displayFont).fontWeight(FontWeight.Medium).fontSize(this.titleSize())
          .lineHeight(`${this.titleSize() * 1.1}fp`).letterSpacing(`${-0.045 * this.titleSize()}fp`)
          .fontColor($r('app.color.strong')).textShadow({ radius: 42, color: $r('app.color.rank_up_glow') })
          .textAlign(TextAlign.Center).wordBreak(WordBreak.BREAK_WORD).lineBreakStrategy(LineBreakStrategy.BALANCED)
        Text('新的冒险等级已经生效').id('gameplay-rank-up-detail').fontSize(16).lineHeight('23fp')
          .fontColor($r('app.color.muted')).textAlign(TextAlign.Center).margin({ bottom: 8 })
        this.status()
        Button('继续冒险', { type: ButtonType.Capsule }).id('gameplay-rank-up-ack')
          .constraintSize({ minWidth: Math.min(180, this.panelWidth - 2 * this.inset() - 2),
            minHeight: 46, maxWidth: '100%' })
          .fontSize(16).fontWeight(600).fontColor($r('app.color.on_accent'))
          .padding({ left: 20, right: 20, top: 8, bottom: 8 }).margin({ top: 8 })
          .backgroundColor($r('app.color.accent')).shadow({ radius: this.getUIContext().vp2px(24),
            offsetY: this.getUIContext().vp2px(10), color: $r('app.color.rank_up_glow') })
          .defaultFocus(true).onClick(() => this.acknowledge())
      }.width('100%').alignItems(HorizontalAlign.Center)
        .padding({ top: this.compact() ? 51 : this.wideInset() + 25, bottom: this.compact() ? 26 : this.wideInset(),
          left: this.inset(), right: this.inset() })
    }.id('gameplay-rank-up-scroll').width('100%').constraintSize({ maxHeight: Math.max(1, this.maxHeight - 2) })
      .align(Alignment.Top).scrollBar(BarState.Auto)
  }

  build() {
    // Only the Scroll participates in size measurement. The ornament follows its viewport, not the text height.
    Column() {
      Column() {
        if (this.panelHeight > 24) { this.ornament(); }
        this.content()
        if (this.panelHeight > 24) { this.frame(); }
      }.width('100%').backgroundColor($r('app.color.rank_up_surface'))
        .border({ width: 1, radius: 18, color: $r('app.color.accent') }).clip(true)
        .onAreaChange((_previous: Area, current: Area) => {
          const height = Number(current.height);
          if (Number.isFinite(height) && height > 0 && height !== this.panelHeight) { this.panelHeight = height; }
        })
    }.id('gameplay-rank-up').width(this.panelWidth).borderRadius(18)
      .shadow({ radius: this.getUIContext().vp2px(60), offsetY: this.getUIContext().vp2px(18),
        color: $r('app.color.rank_up_glow') })
  }
}
