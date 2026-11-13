import { curves, UIUtils, window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppEnvironment } from '../platform/AppEnvironment';

class AtmosphereMote {
  readonly x: number;
  readonly y: number;
  readonly delay: number;

  constructor(x: number, y: number, delay: number) {
    this.x = x;
    this.y = y;
    this.delay = delay;
  }
}

const MOTES: AtmosphereMote[] = [
  new AtmosphereMote(0.08, 0.14, -1000), new AtmosphereMote(0.19, 0.31, -5000),
  new AtmosphereMote(0.11, 0.72, -3000), new AtmosphereMote(0.28, 0.84, -7000),
  new AtmosphereMote(0.37, 0.22, -2000), new AtmosphereMote(0.43, 0.58, -6000),
  new AtmosphereMote(0.51, 0.90, -4000), new AtmosphereMote(0.59, 0.11, -7500)
];

@ComponentV2
struct StarwardAtmosphereMote {
  @Require @Param delay: number;
  @Local private drifted: boolean = false;
  @Local private light: number = 0;

  private start(): void {
    const ui: UIContext = this.getUIContext();
    const curve = curves.cubicBezierCurve(0.22, 0.78, 0.18, 1);
    ui.animateTo({ duration: 8000, delay: this.delay, iterations: -1, curve }, () =>
      UIUtils.applySync(() => { this.drifted = true; }));
    ui.keyframeAnimateTo({ delay: this.delay, iterations: -1 }, [
      { duration: 3040, curve, event: () => UIUtils.applySync(() => { this.light = 0.62; }) },
      { duration: 2720, curve, event: () => UIUtils.applySync(() => { this.light = 0.16; }) },
      { duration: 2240, curve, event: () => UIUtils.applySync(() => { this.light = 0; }) }
    ]);
  }

  build() {
    Circle().width(4).height(4).fill($r('app.color.accent'))
      .shadow({ radius: this.getUIContext().vp2px(10), color: $r('app.color.quest_atmosphere_strong') })
      .translate({ x: this.drifted ? 18 : 0, y: this.drifted ? -42 : 18 })
      .scale({ x: this.drifted ? 1.1 : 0.4, y: this.drifted ? 1.1 : 0.4 })
      .opacity(this.light).onAppear(() => this.start())
  }
}

/** One viewport scene. The static branch has no repeating animation or particles. */
@ComponentV2
struct StarwardAtmosphereScene {
  @Require @Param reduced: boolean;
  @Env(ReadonlyEnvKey.WINDOW_SIZE) windowSize: window.SizeInVP;
  @Local private auroraMoved: boolean = false;
  @Local private riftMoved: boolean = false;
  @Local private orbitMoved: boolean = false;
  @Local private sigilTurned: boolean = false;
  @Local private raysMoved: boolean = false;

  private record(state: string): void {
    if (AppEnvironment.endpoint.length > 0 && AppEnvironment.probeTls) {
      hilog.info(0x0000, 'StarwardQuestAtmosphere', '%{public}s', JSON.stringify({
        state, reduced: this.reduced, particles: state === 'running' ? MOTES.length : 0
      }));
    }
  }

  aboutToDisappear(): void { this.record('stopped'); }

  private start(): void {
    this.record(this.reduced ? 'static' : 'running');
    if (this.reduced) { return; }
    const ui: UIContext = this.getUIContext();
    const ease = curves.cubicBezierCurve(0.32, 0.72, 0, 1);
    const drift = curves.cubicBezierCurve(0.45, 0.02, 0.55, 0.98);
    ui.animateTo({ duration: 12000, iterations: -1, playMode: PlayMode.Alternate, curve: ease }, () =>
      UIUtils.applySync(() => { this.auroraMoved = true; }));
    ui.animateTo({ duration: 9000, iterations: -1, playMode: PlayMode.Alternate, curve: ease }, () =>
      UIUtils.applySync(() => { this.riftMoved = true; }));
    ui.animateTo({ duration: 24000, iterations: -1, playMode: PlayMode.Alternate, curve: drift }, () =>
      UIUtils.applySync(() => { this.orbitMoved = true; }));
    ui.animateTo({ duration: 32000, iterations: -1, curve: drift }, () =>
      UIUtils.applySync(() => { this.sigilTurned = true; }));
    ui.animateTo({ duration: 26000, iterations: -1, playMode: PlayMode.Alternate, curve: drift }, () =>
      UIUtils.applySync(() => { this.raysMoved = true; }));
  }

  @Builder
  aurora(width: number) {
    Column().width(width).height(width)
      .radialGradient({ center: ['50%', '52%'], radius: width * 0.5,
        colors: [[$r('app.color.quest_atmosphere_soft'), 0], [$r('app.color.quest_atmosphere_faint'), 0.34],
          [$r('app.color.quest_atmosphere_clear'), 0.69]] })
      .scale({ x: this.auroraMoved ? 1.08 : 1, y: this.auroraMoved ? 0.745 : 0.69 })
      .rotate({ angle: this.auroraMoved ? 5 : -4 }).opacity(this.auroraMoved ? 0.72 : 0.9)
      .position({ x: (this.windowSize.width - width) / 2, y: -this.windowSize.height * 0.34 - width * 0.155 })
      .translate({ y: this.auroraMoved ? this.windowSize.height * 0.03 : 0 })
  }

  @Builder
  rift(width: number, height: number) {
    Stack() {
      Column().width('100%').height('100%')
        .radialGradient({ center: ['50%', '3%'], radius: Math.hypot(width, height) * 0.5,
          colors: [[$r('app.color.quest_atmosphere_strong'), 0], [$r('app.color.quest_atmosphere_soft'), 0.18],
            [$r('app.color.quest_atmosphere_clear'), 0.56]] })
      Column().width('100%').height('100%')
        .sweepGradient({ center: ['50%', '0%'], start: 0, end: 360, rotation: 205,
          colors: [[$r('app.color.quest_atmosphere_clear'), 0], [$r('app.color.quest_atmosphere_clear'), 0.34],
            [$r('app.color.quest_atmosphere_faint'), 0.42], [$r('app.color.quest_atmosphere_clear'), 0.52]] })
    }.width(width).height(height).position({ x: (this.windowSize.width - width) / 2,
      y: -this.windowSize.height * 0.14 })
      .translate({ y: this.windowSize.height * (this.riftMoved ? 0.04 : -0.02) })
      .scale({ x: this.riftMoved ? 0.94 : 0.76, y: 1 })
      .rotate({ angle: this.riftMoved ? 3 : -2 }).opacity(this.riftMoved ? 0.9 : 0.46)
  }

  @Builder
  halo(width: number) {
    Circle().width(width).height(width).fill(Color.Transparent)
      .stroke($r('app.color.quest_atmosphere_halo')).strokeWidth(1)
      .shadow({ radius: this.getUIContext().vp2px(90), color: $r('app.color.quest_atmosphere_faint') })
      .scale({ x: this.orbitMoved ? 1.04 : 1, y: this.orbitMoved ? 0.42 : 0.38 })
      .rotate({ angle: this.orbitMoved ? -10 : 8 }).opacity(this.orbitMoved ? 0.55 : 0.77)
      .position({ x: (this.windowSize.width - width) / 2, y: this.windowSize.height * 0.10 })
      .translate({ y: this.orbitMoved ? this.windowSize.height * 0.03 : 0 })
  }

  @Builder
  sigil(width: number) {
    Stack() {
      Stack() {
        Circle().width(width).height(width).fill(Color.Transparent)
          .stroke($r('app.color.quest_atmosphere_sigil')).strokeWidth(1)
        Circle().width(width * 0.7).height(width * 0.7).fill(Color.Transparent)
          .stroke($r('app.color.quest_atmosphere_sigil')).strokeWidth(1).strokeDashArray([4, 3])
        Circle().width(width * 0.38).height(width * 0.38).fill(Color.Transparent)
          .stroke($r('app.color.quest_atmosphere_sigil')).strokeWidth(1)
        Rect().width(width * 0.14).height(width * 0.8).fill(Color.Transparent)
          .stroke($r('app.color.quest_atmosphere_sigil')).strokeWidth(1).rotate({ angle: 45 })
        Rect().width(width * 0.8).height(width * 0.14).fill(Color.Transparent)
          .stroke($r('app.color.quest_atmosphere_sigil')).strokeWidth(1).rotate({ angle: 45 })
      }.width(width).height(width).rotate({ angle: this.sigilTurned ? 352 : -8 })
    }.width(width).height(width).opacity(0.54).scale({ x: 1, y: 0.42 })
      .position({ x: (this.windowSize.width - width) / 2, y: this.windowSize.height * 0.06 })
      .translate({ y: this.sigilTurned ? this.windowSize.height * 0.015 : 0 })
  }

  @Builder
  rays(width: number, height: number) {
    Stack() {
      Column().width('100%').height('100%')
        .sweepGradient({ center: ['50%', '20%'], start: 0, end: 19, rotation: 8, repeating: true,
          colors: [[$r('app.color.quest_atmosphere_clear'), 0], [$r('app.color.quest_atmosphere_clear'), 7 / 19],
            [$r('app.color.quest_atmosphere_halo'), 8 / 19], [$r('app.color.quest_atmosphere_clear'), 9 / 19],
            [$r('app.color.quest_atmosphere_clear'), 1]] })
      Column().width('100%').height('100%').radialGradient({ center: ['50%', '20%'],
        radius: Math.hypot(width, height) * 0.5, colors: [[Color.Black, 0], [Color.Transparent, 0.58]] })
        .blendMode(BlendMode.DST_IN)
    }.width(width).height(height).blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
      .position({ x: -this.windowSize.width * 0.2, y: -this.windowSize.height * 0.3 })
      .opacity(this.raysMoved ? 0.22 : 0.08).rotate({ angle: this.raysMoved ? 7 : -4 })
      .scale({ x: this.raysMoved ? 1.08 : 0.96, y: this.raysMoved ? 1.08 : 0.96 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.aurora(Math.min(1120, this.windowSize.width * 1.1))
      this.rift(Math.min(980, this.windowSize.width * 0.96), this.windowSize.height * 0.72)
      this.halo(Math.min(920, this.windowSize.width * 0.88))
      this.sigil(Math.min(760, this.windowSize.width * (this.windowSize.width <= 620 ? 1.25 : 0.78)))
      this.rays(this.windowSize.width * 1.4, this.windowSize.height * 1.6)
      if (!this.reduced) {
        ForEach(MOTES, (mote: AtmosphereMote) => {
          StarwardAtmosphereMote({ delay: mote.delay })
            .position({ x: this.windowSize.width * mote.x, y: this.windowSize.height * mote.y })
        }, (mote: AtmosphereMote) => mote.delay.toString())
      }
      Column().width('100%').height('100%')
        .linearGradient({ direction: GradientDirection.Bottom,
          colors: [[Color.Transparent, 0], [Color.Transparent, Math.min(1, 8 / this.windowSize.height)],
            [Color.Black, Math.min(1, 180 / this.windowSize.height)], [Color.Black, 1]] })
        .blendMode(BlendMode.DST_IN)
    }.width(this.windowSize.width).height(this.windowSize.height)
      .blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
      .onAppear(() => this.start())
  }
}

@ComponentV2
export struct StarwardQuestAtmosphere {
  @Param reducedMotion: boolean = true;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.reducedMotion) {
        StarwardAtmosphereScene({ reduced: true })
      } else {
        StarwardAtmosphereScene({ reduced: false })
      }
    }.id('gameplay-quest-atmosphere').width('100%').height('100%').clip(true)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }
}
