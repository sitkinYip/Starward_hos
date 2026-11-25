import { curves, PathShape, UIUtils } from '@kit.ArkUI';

const ART_SIZE: number = 280;
const CREST_GOLD: string = 'M 140 58 Q 146 130 222 140 Q 146 150 140 222 Q 134 150 58 140 Q 134 130 140 58 Z';
const CREST_ICE: string = 'M 140 34 Q 148 124 232 140 Q 148 156 140 246 Q 132 156 48 140 Q 132 124 140 34 Z';
const RAY_INDICES: number[] = [0, 1, 2, 3, 4, 5];

interface RankSparkPoint {
  x: number;
  y: number;
  gold: boolean;
  size: number;
}

const SPARK_POINTS: RankSparkPoint[] = [
  { x: -94, y: -62, gold: true, size: 5 },
  { x: 98, y: -56, gold: false, size: 6 },
  { x: -108, y: 18, gold: false, size: 4 },
  { x: 112, y: 26, gold: true, size: 5 },
  { x: -72, y: 82, gold: true, size: 4 },
  { x: 76, y: 84, gold: false, size: 5 },
  { x: -34, y: -102, gold: false, size: 4 },
  { x: 38, y: -100, gold: true, size: 5 },
  { x: -12, y: 102, gold: true, size: 3.5 },
  { x: 120, y: -16, gold: true, size: 3.5 }
];

@ComponentV2
struct RankRestingSparks {
  @Require @Param stageSize: number;
  @Require @Param opening: boolean;
  @Local private landed: boolean = false;

  private play(): void {
    if (!this.opening) { return; }
    this.getUIContext().animateTo({ delay: 820, duration: 280, curve: Curve.EaseOut },
      () => UIUtils.applySync(() => { this.landed = true; }));
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(SPARK_POINTS, (spark: RankSparkPoint) => {
        Circle().width(spark.size).height(spark.size)
          .fill(spark.gold ? $r('app.color.reward') : $r('app.color.accent_strong'))
          .position({ x: this.stageSize / 2 + spark.x - spark.size / 2, y: this.stageSize / 2 + spark.y - spark.size / 2 })
      }, (_spark: RankSparkPoint, index: number) => index.toString())
    }.width(this.stageSize).height(this.stageSize).clip(false)
      .opacity(this.opening && !this.landed ? 0 : 0.52).onAppear(() => this.play())
  }
}

@ComponentV2
struct RankShockwave {
  @Require @Param stageSize: number;
  @Require @Param gold: boolean;
  @Local private expansion: number = 0.28;
  @Local private strength: number = 0.92;

  private play(): void {
    const curve = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
    const delay: number = this.gold ? 140 : 0;
    const context: UIContext = this.getUIContext();
    context.animateTo({ delay, duration: 960, curve }, () => UIUtils.applySync(() => { this.expansion = 1.42; }));
    context.keyframeAnimateTo({ delay, iterations: 1 }, [
      { duration: 624, curve, event: () => UIUtils.applySync(() => { this.strength = 0.42; }) },
      { duration: 336, curve, event: () => UIUtils.applySync(() => { this.strength = 0; }) }
    ]);
  }

  build() {
    Circle().width(this.stageSize).height(this.stageSize).fill(Color.Transparent).strokeWidth(2)
      .stroke(this.gold ? $r('app.color.reward') : $r('app.color.accent_strong'))
      .shadow({ radius: 20, color: this.gold ? $r('app.color.reward_glow') : $r('app.color.glow_accent_soft') })
      .opacity(this.strength).scale({ x: this.expansion, y: this.expansion }).onAppear(() => this.play())
  }
}

@ComponentV2
struct RankRaySet {
  @Require @Param stageSize: number;
  @Require @Param gold: boolean;
  @Require @Param opening: boolean;
  @Local private distance: number = 76;
  @Local private elongation: number = 0.76;
  @Local private strength: number = 0.24;

  aboutToAppear(): void {
    if (this.opening) {
      this.distance = 24;
      this.elongation = 0.25;
      this.strength = 0;
    }
  }

  private play(): void {
    if (!this.opening) { return; }
    const curve = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
    this.getUIContext().keyframeAnimateTo({ delay: this.gold ? 130 : 90, iterations: 1 }, [
      { duration: 279, curve, event: () => UIUtils.applySync(() => {
        this.distance = 58;
        this.elongation = 1.12;
        this.strength = 0.96;
      }) },
      { duration: 541, curve, event: () => UIUtils.applySync(() => {
        this.distance = 76;
        this.elongation = 0.76;
        this.strength = 0.24;
      }) }
    ]);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(RAY_INDICES, (index: number) => {
        Stack({ alignContent: Alignment.Center }) {
          Column().width((this.gold ? 52 : 42) * this.stageSize / 228).height(2).borderRadius(999)
            .linearGradient({ direction: GradientDirection.Right, colors: [
              [this.gold ? $r('app.color.reward') : $r('app.color.accent_strong'), 0], [Color.Transparent, 1]
            ] })
            .scale({ x: this.elongation, y: 1, centerX: 0 })
            .translate({ x: this.distance * this.stageSize / 228 })
        }.width(this.stageSize).height(this.stageSize).rotate({ angle: index * 60 + (this.gold ? 0 : 30) })
      }, (index: number) => index.toString())
    }.width(this.stageSize).height(this.stageSize).opacity(this.strength).onAppear(() => this.play())
  }
}

@ComponentV2
struct RankCrestArtwork {
  @Require @Param stageSize: number;
  @Require @Param ambient: boolean;
  @Require @Param opening: boolean;
  @Local private outerAngle: number = 0;
  @Local private innerAngle: number = 0;
  @Local private auraLifted: boolean = false;
  @Local private iceLifted: boolean = false;
  @Local private goldLifted: boolean = false;
  @Local private crownScale: number = 1;
  @Local private crownAngle: number = 0;
  @Local private crownOpacity: number = 1;

  aboutToAppear(): void {
    if (this.opening) {
      this.crownScale = 0.45;
      this.crownAngle = -18;
      this.crownOpacity = 0;
    }
  }

  private vp(value: number): number { return this.stageSize * value / ART_SIZE; }
  private px(value: number): number { return this.getUIContext().vp2px(this.vp(value)); }

  private crestPath(commands: string): string {
    return commands.replace(/\d+/g, (value: string): string => this.px(Number(value)).toFixed(3));
  }

  private orbitBand(gold: boolean, front: boolean): string {
    const rx: number = gold ? 108 : 116;
    const ry: number = gold ? 28 : 32;
    const half: number = (gold ? (front ? 6 : 3.6) : (front ? 7.5 : 4.2)) / 2;
    const direction: number = front ? -1 : 1;
    const center: number = this.px(140);
    const cap: number = this.px(half);
    const startOuter: number = this.px(140 - direction * (rx + half));
    const endOuter: number = this.px(140 + direction * (rx + half));
    const startInner: number = this.px(140 + direction * (rx - half));
    const endInner: number = this.px(140 - direction * (rx - half));
    return `M ${startOuter} ${center} A ${this.px(rx + half)} ${this.px(ry + half)} 0 0 1 ` +
      `${endOuter} ${center} A ${cap} ${cap} 0 0 1 ${startInner} ${center} ` +
      `A ${this.px(rx - half)} ${this.px(ry - half)} 0 0 0 ${endInner} ${center} ` +
      `A ${cap} ${cap} 0 0 1 ${startOuter} ${center} Z`;
  }

  private play(): void {
    const context: UIContext = this.getUIContext();
    if (this.ambient) {
      const ease = curves.cubicBezierCurve(0.2, 0, 0, 1);
      context.animateTo({ duration: 5200, iterations: -1, curve: Curve.Linear },
        () => UIUtils.applySync(() => { this.outerAngle = 360; }));
      context.animateTo({ duration: 15000, iterations: -1, curve: Curve.Linear },
        () => UIUtils.applySync(() => { this.innerAngle = -360; }));
      context.animateTo({ duration: 3600, iterations: -1, playMode: PlayMode.Alternate, curve: ease },
        () => UIUtils.applySync(() => { this.auraLifted = true; }));
      context.animateTo({ duration: 2400, iterations: -1, playMode: PlayMode.Alternate, curve: ease },
        () => UIUtils.applySync(() => { this.iceLifted = true; }));
      context.animateTo({ duration: 2400, delay: -2200, iterations: -1, playMode: PlayMode.Alternate, curve: ease },
        () => UIUtils.applySync(() => { this.goldLifted = true; }));
    }
    if (this.opening) {
      const spring = curves.cubicBezierCurve(0.22, 0.9, 0.24, 1);
      context.keyframeAnimateTo({ iterations: 1 }, [
        { duration: 406, curve: spring, event: () => UIUtils.applySync(() => {
          this.crownScale = 1.10;
          this.crownAngle = 3;
          this.crownOpacity = 1;
        }) },
        { duration: 202, curve: spring, event: () => UIUtils.applySync(() => {
          this.crownScale = 0.97;
          this.crownAngle = -1;
        }) },
        { duration: 172, curve: spring, event: () => UIUtils.applySync(() => {
          this.crownScale = 1;
          this.crownAngle = 0;
        }) }
      ]);
    }
  }

  @Builder
  private orbitalNode(x: number, y: number, radius: number, tint: ResourceColor) {
    Circle().width(this.vp(radius * 2)).height(this.vp(radius * 2)).fill(tint)
      .position({ x: this.vp(x - radius), y: this.vp(y - radius) })
  }

  @Builder
  private outerOrbit() {
    Stack({ alignContent: Alignment.Center }) {
      Circle().width(this.vp(232)).height(this.vp(232)).fill(Color.Transparent)
        .stroke($r('app.color.reward_border')).strokeWidth(this.vp(1))
      Stack({ alignContent: Alignment.Center }) {
        Circle().width(this.vp(232)).height(this.vp(232)).fill(Color.Transparent)
          .stroke($r('app.color.reward')).strokeWidth(this.vp(2.6)).strokeLineCap(LineCapStyle.Round)
          .strokeDashArray([this.vp(132), this.vp(610)]).rotate({ angle: -84 }).opacity(0.75)
        this.orbitalNode(140, 24, 10.5, $r('app.color.reward_glow'))
        this.orbitalNode(140, 24, 4.6, $r('app.color.reward'))
        this.orbitalNode(140, 256, 3.2, $r('app.color.accent_strong'))
      }.width(this.stageSize).height(this.stageSize).rotate({ angle: this.outerAngle })
    }.width(this.stageSize).height(this.stageSize)
  }

  @Builder
  private innerOrbit() {
    Stack({ alignContent: Alignment.Center }) {
      Circle().width(this.vp(176)).height(this.vp(176)).fill(Color.Transparent)
        .stroke($r('app.color.accent_border')).strokeWidth(this.vp(1.2))
        .strokeDashArray([this.vp(5), this.vp(9)])
      this.orbitalNode(228, 140, 2.8, $r('app.color.accent_strong'))
      this.orbitalNode(52, 140, 2.4, $r('app.color.reward'))
    }.width(this.stageSize).height(this.stageSize).rotate({ angle: this.innerAngle })
  }

  @Builder
  private slantedArc(gold: boolean, front: boolean) {
    Column().width(this.stageSize).height(this.stageSize)
      .linearGradient({ direction: GradientDirection.Right, colors: gold ?
        [[$r('app.color.reward_soft'), 0], [$r('app.color.reward'), 0.48], [$r('app.color.reward_glow'), 1]] :
        [[$r('app.color.accent_faint'), 0], [$r('app.color.accent_strong'), 0.4], [$r('app.color.accent_soft'), 1]] })
      .clipShape(new PathShape({ commands: this.orbitBand(gold, front) }))
      .opacity(front ? 1 : 0.52)
      .rotate({ angle: (gold ? 16 : -18) + ((gold ? this.goldLifted : this.iceLifted) ? 3.5 : 0) })
      .scale({ x: (gold ? this.goldLifted : this.iceLifted) ? 1.035 : 1,
        y: (gold ? this.goldLifted : this.iceLifted) ? 1.035 : 1 })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width(this.stageSize).height(this.stageSize)
        .radialGradient({ center: ['50%', '50%'], radius: '39%',
          colors: [[$r('app.color.reward_glow'), 0], [$r('app.color.glow_accent_soft'), 0.48],
            [Color.Transparent, 1]] })
        .opacity(this.ambient && !this.auraLifted ? 0.72 : 1)
        .scale({ x: this.auraLifted ? 1.045 : 1, y: this.auraLifted ? 1.045 : 1 })
      this.outerOrbit()
      this.innerOrbit()
      this.slantedArc(false, false)
      this.slantedArc(true, false)
      Stack({ alignContent: Alignment.Center }) {
        Column().width(this.stageSize).height(this.stageSize)
          .linearGradient({ angle: 135, colors: [[$r('app.color.glass_highlight'), 0],
            [$r('app.color.reward'), 0.55], [$r('app.color.reward_glow'), 1]] })
          .clipShape(new PathShape({ commands: this.crestPath(CREST_GOLD) })).rotate({ angle: 45 }).opacity(0.88)
        Column().width(this.stageSize).height(this.stageSize)
          .radialGradient({ center: ['50%', '46%'], radius: '58%',
            colors: [[$r('app.color.star_core'), 0], [$r('app.color.star_mid'), 0.52], [$r('app.color.star_edge'), 1]] })
          .clipShape(new PathShape({ commands: this.crestPath(CREST_ICE) }))
      }.width(this.stageSize).height(this.stageSize).opacity(this.crownOpacity).rotate({ angle: this.crownAngle })
        .scale({ x: this.crownScale, y: this.crownScale })
      this.slantedArc(false, true)
      this.slantedArc(true, true)
    }.id('gameplay-rank-up-orbits').width(this.stageSize).height(this.stageSize).onAppear(() => this.play())
  }
}

@ComponentV2
struct RankLevelBadge {
  @Require @Param rankOrder: number;
  @Require @Param stageSize: number;
  @Require @Param opening: boolean;
  @Local private badgeScale: number = 1;

  // Motion Prompt #007 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#007
  private play(): void {
    if (!this.opening) { return; }
    const spring = curves.cubicBezierCurve(0.22, 0.9, 0.24, 1);
    this.getUIContext().keyframeAnimateTo({ delay: 280, iterations: 1 }, [
      { duration: 198, curve: spring, event: () => UIUtils.applySync(() => { this.badgeScale = 1.07; }) },
      { duration: 224, curve: spring, event: () => UIUtils.applySync(() => { this.badgeScale = 0.99; }) },
      { duration: 198, curve: spring, event: () => UIUtils.applySync(() => { this.badgeScale = 1; }) }
    ]);
  }

  build() {
    Row({ space: 2 }) {
      Text('Lv.').fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.reward'))
      Text(this.rankOrder.toString()).id('gameplay-rank-up-order')
        .fontSize(this.stageSize <= 68 ? 24 : 28).fontWeight(FontWeight.Bolder)
        .fontColor($r('app.color.strong')).fontFeature("'tnum' 1")
    }.width(this.stageSize).height(this.stageSize).justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.raised')).border({ width: 1.5, color: $r('app.color.reward_border'), radius: 999 })
      .radialGradient({ center: ['50%', '24%'], radius: '62%',
        colors: [[$r('app.color.reward_soft'), 0], [$r('app.color.glow_accent_faint'), 0.58], [Color.Transparent, 1]] })
      .shadow({ radius: 24, color: $r('app.color.reward_glow') })
      .scale({ x: this.badgeScale, y: this.badgeScale }).onAppear(() => this.play())
  }
}

/** Decorative stage of the rank dialog. Its owner supplies only the accepted level and geometry. */
@ComponentV2
export struct StarwardRankCrest {
  @Require @Param rankOrder: number;
  @Require @Param stageSize: number;
  @Require @Param badgeSize: number;
  @Param motionEnabled: boolean = false;
  @Local private inView: boolean = true;
  @Local private opening: boolean = false;

  aboutToAppear(): void { this.opening = this.motionEnabled; }

  @Monitor('motionEnabled')
  private motionChanged(): void {
    if (!this.motionEnabled) { this.opening = false; }
  }

  private mode(): number {
    if (!this.motionEnabled || !this.inView) { return 0; }
    return this.opening ? 2 : 1;
  }

  @Builder
  private sparks() {
    Particle({
      particles: [{
        emitter: { particle: { type: ParticleType.POINT, config: { radius: 1.8 }, count: 5, lifetime: 920 },
          emitRate: 56, position: ['50%', '50%'], size: [1, 1] },
        color: { range: [$r('app.color.accent_strong'), $r('app.color.accent')] },
        velocity: { speed: [72, 116], angle: [0, 360] },
        opacity: { range: [0, 0], updater: { type: ParticleUpdater.CURVE, config: [
          { from: 0, to: 0, startMillis: 0, endMillis: 90, curve: Curve.Linear },
          { from: 0, to: 1, startMillis: 90, endMillis: 258, curve: Curve.EaseOut },
          { from: 1, to: 0.52, startMillis: 258, endMillis: 820, curve: Curve.EaseOut },
          { from: 0.52, to: 0, startMillis: 820, endMillis: 920, curve: Curve.EaseIn }
        ] } }
      }, {
        emitter: { particle: { type: ParticleType.POINT, config: { radius: 2.1 }, count: 5, lifetime: 920 },
          emitRate: 48, position: ['50%', '50%'], size: [1, 1] },
        color: { range: [$r('app.color.reward'), $r('app.color.reward')] },
        velocity: { speed: [82, 126], angle: [0, 360] },
        opacity: { range: [0, 0], updater: { type: ParticleUpdater.CURVE, config: [
          { from: 0, to: 0, startMillis: 0, endMillis: 110, curve: Curve.Linear },
          { from: 0, to: 1, startMillis: 110, endMillis: 258, curve: Curve.EaseOut },
          { from: 1, to: 0.52, startMillis: 258, endMillis: 820, curve: Curve.EaseOut },
          { from: 0.52, to: 0, startMillis: 820, endMillis: 920, curve: Curve.EaseIn }
        ] } }
      }]
    }).id('gameplay-rank-up-particles').width(this.stageSize * 1.32).height(this.stageSize * 1.32)
      .position({ x: -this.stageSize * 0.16, y: -this.stageSize * 0.16 })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      ForEach([this.mode()], (mode: number) => {
        Stack({ alignContent: Alignment.Center }) {
          if (mode === 2) {
            RankShockwave({ stageSize: this.stageSize * 0.94, gold: false })
            RankShockwave({ stageSize: this.stageSize * 0.94, gold: true })
            this.sparks()
          }
          Stack() {
            RankRaySet({ stageSize: this.stageSize, gold: false, opening: mode === 2 })
            RankRaySet({ stageSize: this.stageSize, gold: true, opening: mode === 2 })
          }.id('gameplay-rank-up-rays').width(this.stageSize).height(this.stageSize)
          RankRestingSparks({ stageSize: this.stageSize, opening: mode === 2 })
          RankCrestArtwork({ stageSize: this.stageSize, ambient: mode > 0, opening: mode === 2 })
          RankLevelBadge({ rankOrder: this.rankOrder, stageSize: this.badgeSize, opening: mode === 2 })
        }.width(this.stageSize).height(this.stageSize)
      }, (mode: number) => mode.toString())
    }.width(this.stageSize).height(this.stageSize).clip(false)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      .onVisibleAreaChange([0], (_expanding: boolean, ratio: number) => {
        this.inView = ratio > 0;
        if (!this.inView) { this.opening = false; }
      })
  }
}
