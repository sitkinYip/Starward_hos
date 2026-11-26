import { curves, UIUtils } from '@kit.ArkUI';
import { StarwardAnswerResultOverlay } from './StarwardAnswerResultOverlay';
import { starwardCountUp } from './StarwardMotion';

// Motion Prompt #003 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#003
// Motion Prompt #007 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#007
const CORE_PATH = 'M60 6 C64 42 78 56 114 60 C78 64 64 78 60 114 C56 78 42 64 6 60 C42 56 56 42 60 6 Z';
const RAY_ANGLES: number[] = [0, 36, 72, 108, 144, 180, 216, 252, 288, 324];
const XP_DURATION_MS: number = 680;

@ComponentV2
struct StarwardBurstStage {
  @Param reducedMotion: boolean = true;
  @Local private coreScale: number = 0.78;
  @Local private innerScale: number = 0.72;
  @Local private outerScale: number = 0.68;
  @Local private outerOpacity: number = 0;
  @Local private rayDistance: number = 35;
  @Local private rayOpacity: number = 0;

  private animate(): void {
    if (this.reducedMotion) { return; }
    const context = this.getUIContext();
    const impact = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
    context.keyframeAnimateTo({ iterations: 1 }, [
      { duration: 120, curve: Curve.EaseIn, event: () => UIUtils.applySync(() => { this.coreScale = 0.65; }) },
      { duration: 170, curve: impact, event: () => UIUtils.applySync(() => { this.coreScale = 1.18; }) },
      { duration: 530, curve: curves.springMotion(0.34, 0.78),
        event: () => UIUtils.applySync(() => { this.coreScale = 1; }) }
    ]);
    context.animateTo({ duration: 720, delay: 80, curve: impact },
      () => UIUtils.applySync(() => { this.innerScale = 1; }));
    context.keyframeAnimateTo({ delay: 180, iterations: 1 }, [
      { duration: 105, curve: impact, event: () => UIUtils.applySync(() => {
        this.outerScale = 0.9;
        this.outerOpacity = 0.86;
        this.rayOpacity = 0.94;
      }) },
      { duration: 515, curve: impact, event: () => UIUtils.applySync(() => {
        this.outerScale = 1.15;
        this.outerOpacity = 0.3;
        this.rayDistance = 96;
        this.rayOpacity = 0;
      }) }
    ]);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width(208).height(144)
        .radialGradient({ center: ['50%', '50%'], radius: '50%',
          colors: [[$r('app.color.glow_accent'), 0], [$r('app.color.burst_glow_stage_clear'), 1]] })
      Ellipse().width(210).height(68).fill(Color.Transparent).stroke($r('app.color.accent')).strokeWidth(2)
        .rotate({ angle: -14 }).opacity(this.reducedMotion ? 0.38 : this.outerOpacity)
        .scale({ x: this.reducedMotion ? 1 : this.outerScale, y: this.reducedMotion ? 1 : this.outerScale })
      Ellipse().width(152).height(50).fill(Color.Transparent).stroke($r('app.color.accent_strong')).strokeWidth(1)
        .rotate({ angle: -14 }).opacity(0.78)
        .scale({ x: this.reducedMotion ? 1 : this.innerScale, y: this.reducedMotion ? 1 : this.innerScale })
      if (!this.reducedMotion) {
        ForEach(RAY_ANGLES, (angle: number) => {
          Stack() {
            Column().width(24).height(3).borderRadius(2)
              .linearGradient({ direction: GradientDirection.Right,
                colors: [[Color.Transparent, 0], [$r('app.color.accent_strong'), 1]] })
              .translate({ x: this.rayDistance }).opacity(this.rayOpacity)
          }.width(220).height(180).rotate({ angle: angle })
        }, (angle: number) => angle.toString())
        Particle({ particles: [{
          emitter: {
            particle: { type: ParticleType.POINT, config: { radius: 2 }, count: 12, lifetime: 650 },
            emitRate: 70, shape: ParticleEmitterShape.CIRCLE, position: ['49%', '49%'], size: [4, 4]
          },
          color: { range: [$r('app.color.accent'), $r('app.color.accent_strong')] },
          opacity: { range: [0.65, 1], updater: { type: ParticleUpdater.CURVE,
            config: [{ from: 0.9, to: 0, startMillis: 80, endMillis: 650, curve: Curve.EaseOut }] } },
          velocity: { speed: [72, 154], angle: [0, 360] }
        }] }).width(220).height(180)
      }
      Shape() {
        Path().commands(CORE_PATH).fill($r('app.color.star_mid'))
          .stroke($r('app.color.star_edge')).strokeWidth(1)
      }.width(112).height(112).viewPort({ x: 0, y: 0, width: '120px', height: '120px' })
        .scale({ x: this.reducedMotion ? 1 : this.coreScale, y: this.reducedMotion ? 1 : this.coreScale })
    }.id('gameplay-burst-stage').width(220).height(180)
      .onAppear(() => this.animate()).hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }
}

/** Presentational feedback. The owner decides when it appears, closes or advances. */
@ComponentV2
export struct StarwardStarBurstOverlay {
  @Require @Param title: string;
  @Require @Param xpDelta: number;
  @Require @Param actionLabel: string;
  @Require @Param autoAdvance: boolean;
  @Param reducedMotion: boolean = true;
  @Event proceed: () => void = () => {};
  @Event dismiss: () => void = () => {};
  @Local private displayedXp: number = 0;
  @Local private xpScale: number = 1;
  private active: boolean = false;

  aboutToAppear(): void {
    this.displayedXp = this.reducedMotion ? this.xpDelta : 0;
  }

  aboutToDisappear(): void { this.active = false; }

  @Monitor('reducedMotion')
  private settleWithoutMotion(): void {
    if (this.reducedMotion) {
      this.displayedXp = this.xpDelta;
      this.xpScale = 1;
    }
  }

  private countUp(): void {
    this.active = true;
    if (this.reducedMotion || this.xpDelta <= 0) { return; }
    const context = this.getUIContext();
    starwardCountUp(context, this.xpDelta, XP_DURATION_MS, () => this.active && !this.reducedMotion,
      (value: number, settled: boolean): void => {
        this.displayedXp = value;
        if (!settled) { return; }
        context.keyframeAnimateTo({ iterations: 1 }, [
          { duration: 120, curve: Curve.EaseOut, event: () => UIUtils.applySync(() => { this.xpScale = 1.1; }) },
          { duration: 300, curve: curves.springMotion(0.34, 0.78),
            event: () => UIUtils.applySync(() => { this.xpScale = 1; }) }
        ]);
      });
  }

  @Builder
  private resultContent() {
    Column({ space: 18 }) {
      StarwardBurstStage({ reducedMotion: this.reducedMotion })
      Column({ space: 8 }) {
        Text(this.title).id('gameplay-burst-title').fontSize(28).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
        if (this.xpDelta > 0) {
          Text('+' + this.displayedXp.toString() + ' EXP').id('gameplay-burst-xp')
            .fontSize(16).fontWeight(600).fontColor($r('app.color.accent_text')).fontFeature("'tnum' 1")
            .accessibilityText('获得 ' + this.xpDelta.toString() + ' 经验值')
            .scale({ x: this.reducedMotion ? 1 : this.xpScale, y: this.reducedMotion ? 1 : this.xpScale })
        }
      }.padding({ top: 12, bottom: 12, left: 28, right: 28 })
        .radialGradient({ center: ['50%', '50%'], radius: '58%',
          colors: [[$r('app.color.burst_glow_card'), 0], [$r('app.color.burst_glow_card_clear'), 1]] })
      if (this.autoAdvance) {
        Text('正在跳转下一题').id('gameplay-burst-auto-next').constraintSize({ minHeight: 48 })
          .fontSize(16).fontWeight(600).fontColor($r('app.color.accent_text')).textAlign(TextAlign.Center)
      } else {
        Button(this.actionLabel, { type: ButtonType.Capsule })
          .id('gameplay-burst-action').constraintSize({ minHeight: 48, minWidth: 132 })
          .padding({ left: 20, right: 20 }).fontSize(16).fontWeight(600)
          .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
          .linearGradient({ direction: GradientDirection.Bottom,
            colors: [[$r('app.color.accent_strong'), 0], [$r('app.color.accent'), 1]] })
          .shadow({ radius: 16, offsetY: 6, color: $r('app.color.glow_accent_soft') })
          .defaultFocus(true).onClick(() => this.proceed())
      }
    }.padding({ left: 22, right: 22 }).width('100%').constraintSize({ maxWidth: 384 })
  }

  build() {
    StarwardAnswerResultOverlay({ nodeId: 'gameplay-star-burst', backdropId: 'gameplay-burst-backdrop',
      reducedMotion: this.reducedMotion, dismissible: !this.autoAdvance, dismiss: () => this.dismiss(),
      content: () => { this.resultContent() } })
      .onAppear(() => this.countUp())
  }
}
