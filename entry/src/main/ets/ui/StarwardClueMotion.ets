import { curves, UIUtils } from '@kit.ArkUI';

export function clueRevealAnimation(enabled: boolean, delay: number): AnimateParam {
  return { duration: enabled ? 760 : 0, delay: enabled ? delay : 0,
    curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) };
}

@ComponentV2
export struct StarwardMediaFrame {
  @Require @Param stageWidth: number;
  @Require @Param stageHeight: number;
  @Param reducedMotion: boolean = true;
  @Local private revealed: boolean = true;

  aboutToAppear(): void { this.revealed = this.reducedMotion; }

  build() {
    Column() {}
      .id('starward-media-frame')
      .width(Math.max(0, this.stageWidth - 14)).height(Math.max(0, this.stageHeight - 14))
      .border({ width: 1, color: '#1fffecb8' })
      .opacity(this.revealed ? 1 : 0).scale({ x: this.revealed ? 1 : 0.86, y: this.revealed ? 1 : 0.86 })
      .animation({ duration: this.reducedMotion ? 0 : 880, delay: this.reducedMotion ? 0 : 120,
        curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) })
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      .onAppear(() => UIUtils.applySync(() => { this.revealed = true; }))
  }
}

@ComponentV2
export struct StarwardMediaAmbient {
  @Require @Param diameter: number;
  @Param motionEnabled: boolean = false;
  @Local private angle: number = 0;
  private mounted: boolean = false;

  @Monitor('motionEnabled')
  private animateOrbit(): void {
    if (!this.mounted) { return; }
    this.getUIContext().animateTo({
      duration: this.motionEnabled ? 26000 : 0,
      iterations: this.motionEnabled ? -1 : 1,
      curve: curves.cubicBezierCurve(0.45, 0.02, 0.55, 0.98)
    }, () => UIUtils.applySync(() => { this.angle = this.motionEnabled ? 360 : 0; }));
  }

  aboutToDisappear(): void { this.mounted = false; }

  build() {
    Stack() {
      Stack() {
        Circle().width(this.diameter * 0.86).height(this.diameter * 0.86)
          .fill(Color.Transparent).stroke('#29E0C06B').strokeWidth(1)
        Circle().width(this.diameter * 0.52).height(this.diameter * 0.52)
          .fill(Color.Transparent).stroke('#29E0C06B').strokeWidth(1).strokeDashArray([3, 4])
        Circle().width(this.diameter * 0.18).height(this.diameter * 0.18)
          .fill(Color.Transparent).stroke('#29E0C06B').strokeWidth(1)
        Column() {}.width(this.diameter * 0.76).height(this.diameter * 0.76)
          .border({ width: 1, color: '#29E0C06B' }).rotate({ angle: 45 })
      }.width(this.diameter).height(this.diameter).rotate({ angle: this.angle })
    }.id('starward-media-orbit').width(this.diameter).height(this.diameter).scale({ x: 1, y: 0.62 })
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      .onAppear(() => { this.mounted = true; this.animateOrbit(); })
  }
}

/** Decorative geometry follows the measured panel without taking part in its layout. */
@ComponentV2
export struct StarwardClueDialogDecoration {
  @Require @Param panelWidth: number;
  @Require @Param panelHeight: number;
  @Param combination: boolean = false;
  @Param motionEnabled: boolean = false;
  @Local private charged: boolean = false;
  @Local private angle: number = 0;
  private mounted: boolean = false;

  @Monitor('motionEnabled')
  private motionChanged(): void {
    if (!this.mounted) { return; }
    const ui = this.getUIContext();
    if (!this.motionEnabled) {
      ui.animateTo({ duration: 0 }, () => UIUtils.applySync(() => {
        this.charged = false;
        this.angle = 0;
      }));
      return;
    }
    ui.animateTo({ duration: 2800, iterations: -1, playMode: PlayMode.Alternate,
      curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) }, () => UIUtils.applySync(() => {
      this.charged = true;
    }));
    ui.animateTo({ duration: this.combination ? 20000 : 22000, iterations: -1,
      curve: curves.cubicBezierCurve(0.45, 0.02, 0.55, 0.98) }, () => UIUtils.applySync(() => {
      this.angle = 360;
    }));
  }

  aboutToDisappear(): void { this.mounted = false; }

  private diameter(): number { return this.combination ? Math.min(720, this.panelWidth * 1.5) : 390; }
  private ringColor(): ResourceColor { return this.combination ? '#6CB9A2' : '#DAB76A'; }

  @Builder
  ring(fraction: number, dashed: boolean) {
    Circle().width(this.diameter() * fraction).height(this.diameter() * fraction)
      .fill(Color.Transparent).stroke(this.ringColor()).strokeWidth(1).strokeDashArray(dashed ? [2, 3] : [])
  }

  @Builder
  orbit() {
    Stack() {
      this.ring(this.combination ? 0.9 : 1, false)
      this.ring(this.combination ? 0.56 : 0.68, this.combination)
      this.ring(this.combination ? 0.24 : 0.52, !this.combination)
      if (this.combination) {
        Column() {}.width(this.diameter() * 0.06).height(this.diameter() * 0.72)
          .border({ width: 1, color: this.ringColor() }).rotate({ angle: 38 })
        Column() {}.width(this.diameter() * 0.72).height(this.diameter() * 0.06)
          .border({ width: 1, color: this.ringColor() }).rotate({ angle: 38 })
      } else {
        Column() {}.width(this.diameter() * 0.38).height(this.diameter() * 0.38)
          .border({ width: 1, color: this.ringColor() }).rotate({ angle: 45 })
        Column() {}.width(this.diameter() * 0.84).height(this.diameter() * 0.08)
          .border({ width: 1, color: this.ringColor() })
        Column() {}.width(this.diameter() * 0.08).height(this.diameter() * 0.84)
          .border({ width: 1, color: this.ringColor() })
      }
    }.id('gameplay-clue-dialog-orbit').width(this.diameter()).height(this.diameter())
      .position({ x: this.combination ? (this.panelWidth - this.diameter()) / 2 : this.panelWidth - 260,
        y: this.combination ? (this.panelHeight - this.diameter()) / 2 : -170 })
      .opacity(this.combination ? 0.09 : 0.1).rotate({ angle: this.angle })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.orbit()
      Column() {}.width(Math.max(0, this.panelWidth - 14)).height(Math.max(0, this.panelHeight - 14))
        .position({ x: 7, y: 7 }).border({ width: 1, color: $r('app.color.accent_faint') })
      Column() {}.id('gameplay-clue-dialog-edge').width(this.panelWidth * 0.7).height(1)
        .linearGradient({ direction: GradientDirection.Right,
          colors: [[Color.Transparent, 0], ['#B7F4D789', 0.5], [Color.Transparent, 1]] })
        .position({ x: this.panelWidth * 0.15, y: 0 })
        .opacity(this.charged ? 1 : 0.26).scale({ x: this.charged ? 1 : 0.38, y: 1 })
    }.width(this.panelWidth).height(this.panelHeight).clip(true)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      .onAppear(() => { this.mounted = true; this.motionChanged(); })
  }
}
