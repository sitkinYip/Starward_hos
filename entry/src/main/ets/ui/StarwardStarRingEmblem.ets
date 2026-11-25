import { curves, PathShape, UIUtils } from '@kit.ArkUI';

const VIEW_BOX = 280;
const STAR = 'M 140 50 Q 145 128 202 140 Q 145 152 140 230 Q 135 152 78 140 Q 135 128 140 50 Z';
const STAR_GLINT = 'M 140 94 Q 143 134 170 140 Q 143 146 140 186 Q 137 146 110 140 Q 137 134 140 94 Z';

@ComponentV2
struct StarwardStarRingArt {
  @Require @Param diameter: number;
  @Require @Param motionEnabled: boolean;
  @Require @Param slowOrbit: boolean;
  @Local private outerAngle: number = 0;
  @Local private innerAngle: number = 0;
  @Local private coreBright: boolean = false;
  @Local private auraBright: boolean = false;
  @Local private tiltLifted: boolean = false;

  private unit(value: number): number { return value * this.diameter / VIEW_BOX; }

  private pathPixels(value: number): number { return this.getUIContext().vp2px(this.unit(value)); }

  private starPath(commands: string): string {
    return commands.replace(/\d+/g, (value: string): string => this.pathPixels(Number(value)).toFixed(3));
  }

  private ringBand(front: boolean): string {
    const half: number = front ? 4.25 : 2.5;
    const direction: number = front ? -1 : 1;
    const outerStart: number = this.pathPixels(140 - direction * (108 + half));
    const outerEnd: number = this.pathPixels(140 + direction * (108 + half));
    const innerStart: number = this.pathPixels(140 + direction * (108 - half));
    const innerEnd: number = this.pathPixels(140 - direction * (108 - half));
    const mid: number = this.pathPixels(140);
    const cap: number = this.pathPixels(half);
    return `M ${outerStart} ${mid} A ${this.pathPixels(108 + half)} ${this.pathPixels(29 + half)} 0 0 1 ` +
      `${outerEnd} ${mid} A ${cap} ${cap} 0 0 1 ${innerStart} ${mid} ` +
      `A ${this.pathPixels(108 - half)} ${this.pathPixels(29 - half)} 0 0 0 ${innerEnd} ${mid} ` +
      `A ${cap} ${cap} 0 0 1 ${outerStart} ${mid} Z`;
  }

  private tilt(): number { return this.tiltLifted ? -10.5 : -14; }

  private animate(context: UIContext, transition: AnimateParam, update: () => void): void {
    context.animateTo(transition, () => {
      try { UIUtils.applySync(update); } catch { /* Keep the visible artwork during a lifecycle change. */ }
    });
  }

  private startMotion(): void {
    if (!this.motionEnabled) { return; }
    const context: UIContext = this.getUIContext();
    this.animate(context, { duration: this.slowOrbit ? 5400 : 3800, curve: Curve.Linear, iterations: -1 },
      () => { this.outerAngle = 360; });
    this.animate(context, { duration: this.slowOrbit ? 22000 : 16000, curve: Curve.Linear, iterations: -1 },
      () => { this.innerAngle = -360; });
    const easing = curves.cubicBezierCurve(0.2, 0, 0, 1);
    this.animate(context, { duration: 1600, curve: easing, iterations: -1, playMode: PlayMode.Alternate },
      () => { this.coreBright = true; });
    this.animate(context, { duration: 2000, curve: easing, iterations: -1, playMode: PlayMode.Alternate },
      () => { this.auraBright = true; });
    this.animate(context, { duration: 2600, curve: easing, iterations: -1, playMode: PlayMode.Alternate },
      () => { this.tiltLifted = true; });
  }

  @Builder
  private outerOrbit() {
    Stack({ alignContent: Alignment.Center }) {
      Circle().width(this.unit(224)).height(this.unit(224)).fill(Color.Transparent)
        .stroke($r('app.color.accent')).strokeWidth(this.unit(2.4)).strokeLineCap(LineCapStyle.Round)
        .strokeDashArray([this.unit(118), this.unit(590)]).rotate({ angle: -86 }).opacity(0.74)
      Circle().width(this.unit(19)).height(this.unit(19)).fill($r('app.color.accent')).opacity(0.24)
        .position({ x: this.unit(130.5), y: this.unit(18.5) })
      Circle().width(this.unit(8.4)).height(this.unit(8.4)).fill($r('app.color.accent_strong'))
        .position({ x: this.unit(135.8), y: this.unit(23.8) })
    }.width(this.diameter).height(this.diameter).rotate({ angle: this.outerAngle })
  }

  @Builder
  private innerOrbit() {
    Stack({ alignContent: Alignment.Center }) {
      Circle().width(this.unit(168)).height(this.unit(168)).fill(Color.Transparent)
        .stroke($r('app.color.accent_border')).strokeWidth(this.unit(1))
        .strokeDashArray([this.unit(4), this.unit(8)]).opacity(0.42)
      Circle().width(this.unit(4.8)).height(this.unit(4.8)).fill($r('app.color.accent_strong'))
        .position({ x: this.unit(221.6), y: this.unit(137.6) })
      Circle().width(this.unit(3.6)).height(this.unit(3.6)).fill($r('app.color.accent_strong')).opacity(0.58)
        .position({ x: this.unit(54.2), y: this.unit(138.2) })
    }.width(this.diameter).height(this.diameter).rotate({ angle: this.innerAngle })
  }

  @Builder
  private slantedArc(front: boolean) {
    Column().width(this.diameter).height(this.diameter).linearGradient({
      direction: GradientDirection.Right,
      colors: front ? [[$r('app.color.accent_faint'), 0], [$r('app.color.accent_strong'), 0.28],
        [$r('app.color.accent'), 0.74], [$r('app.color.accent_soft'), 1]] :
        [[$r('app.color.accent_faint'), 0], [$r('app.color.accent_soft'), 0.5], [$r('app.color.accent_border'), 1]]
    }).clipShape(new PathShape({ commands: this.ringBand(front) }))
      .rotate({ angle: this.tilt() })
      .scale({ x: this.tiltLifted ? 1.025 : 1, y: this.tiltLifted ? 1.025 : 1 })
  }

  @Builder
  private starCore() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width(this.diameter).height(this.diameter)
        .radialGradient({ center: ['50%', '46%'], radius: '58%',
          colors: [[$r('app.color.star_core'), 0], [$r('app.color.star_mid'), 0.48], [$r('app.color.star_edge'), 1]] })
        .clipShape(new PathShape({ commands: this.starPath(STAR) }))
      Path({ width: this.diameter, height: this.diameter }).commands(this.starPath(STAR))
        .fill(Color.Transparent).stroke($r('app.color.accent_border')).strokeWidth(this.unit(1))
      Path({ width: this.diameter, height: this.diameter }).commands(this.starPath(STAR_GLINT))
        .fill($r('app.color.glass_highlight')).opacity(0.65)
    }.width(this.diameter).height(this.diameter).opacity(this.motionEnabled && !this.coreBright ? 0.9 : 1)
      .scale({ x: this.motionEnabled ? (this.coreBright ? 1.04 : 0.96) : 1,
        y: this.motionEnabled ? (this.coreBright ? 1.04 : 0.96) : 1 })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width(this.diameter * 1.28).height(this.diameter * 1.28)
        .radialGradient({ center: ['50%', '50%'], radius: '50%',
          colors: [[$r('app.color.glow_accent_soft'), 0], [$r('app.color.accent_faint'), 0.46],
            [Color.Transparent, 0.72]] })
        .opacity(this.motionEnabled ? (this.auraBright ? 0.96 : 0.56) : 1)
        .scale({ x: this.motionEnabled ? (this.auraBright ? 1.08 : 0.92) : 1,
          y: this.motionEnabled ? (this.auraBright ? 1.08 : 0.92) : 1 })
      Circle().width(this.unit(224)).height(this.unit(224)).fill(Color.Transparent)
        .stroke($r('app.color.border_strong')).strokeWidth(this.unit(1)).opacity(0.72)
      this.outerOrbit()
      this.innerOrbit()
      this.slantedArc(false)
      this.starCore()
      this.slantedArc(true)
      Path({ width: this.diameter, height: this.diameter }).commands(
        `M ${this.pathPixels(241)} ${this.pathPixels(146)} ` +
        `A ${this.pathPixels(104)} ${this.pathPixels(26)} 0 0 1 ${this.pathPixels(56)} ${this.pathPixels(151)}`)
        .fill(Color.Transparent).stroke($r('app.color.glass_highlight')).strokeWidth(this.unit(1.5))
        .strokeLineCap(LineCapStyle.Round).opacity(0.75).rotate({ angle: this.tilt() })
        .scale({ x: this.tiltLifted ? 1.025 : 1, y: this.tiltLifted ? 1.025 : 1 })
    }.width(this.diameter).height(this.diameter).clip(false).onAppear(() => this.startMotion())
  }
}

/** Shared 1:1 brand artwork. The owner provides motion permission from StarwardMotion and its lifecycle. */
@ComponentV2
export struct StarwardStarRingEmblem {
  @Param diameter: number = 210;
  @Param motionEnabled: boolean = false;
  @Param slowOrbit: boolean = false;
  @Local private inView: boolean = false;

  private animationMode(): number { return this.motionEnabled && this.inView ? (this.slowOrbit ? 2 : 1) : 0; }

  build() {
    Stack() {
      // Replacing the animated subtree also removes the native repeating transforms.
      ForEach([this.animationMode()], (mode: number) => {
        StarwardStarRingArt({ diameter: this.diameter, motionEnabled: mode !== 0, slowOrbit: mode === 2 })
      }, (mode: number) => mode.toString())
    }.width(this.diameter).height(this.diameter).clip(false)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      .onVisibleAreaChange([0], (_expanding: boolean, ratio: number) => { this.inView = ratio > 0; })
  }
}
