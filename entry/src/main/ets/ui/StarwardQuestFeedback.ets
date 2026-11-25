import { curves, LengthMetrics, UIUtils } from '@kit.ArkUI';

/** A single feedback event. Its lifetime affects this card only. */
@ComponentV2
export struct StarwardQuestFeedback {
  @Require @Param message: string;
  @Require @Param messageId: string;
  @Param danger: boolean = false;
  @Param transient: boolean = false;
  @Param motionEnabled: boolean = false;
  @Local private expired: boolean = false;
  @Local private lifelineScale: number = 1;
  @Local private lifelineOpacity: number = 1;
  @Local private shown: boolean = true;
  private timer: number = -1;
  private started: boolean = false;

  aboutToAppear(): void { this.shown = !this.motionEnabled; }

  private updateVisual(update: () => void): void {
    try { UIUtils.applySync(update); } catch { update(); }
  }

  private start(): void {
    if (this.started) { return; }
    this.started = true;
    if (this.transient) {
      this.timer = setTimeout(() => {
        this.timer = -1;
        this.expired = true;
      }, 3000);
    }
    if (!this.motionEnabled) { return; }
    const context = this.getUIContext();
    const spring = curves.cubicBezierCurve(0.22, 0.90, 0.24, 1);
    context.animateTo({ duration: this.danger ? 320 : 360, curve: spring }, () => this.updateVisual(() => {
      this.shown = true;
    }));
    if (this.transient) {
      context.animateTo({ duration: 3000, curve: Curve.Linear }, () => this.updateVisual(() => {
        this.lifelineScale = 0;
        this.lifelineOpacity = 0.3;
      }));
    }
  }

  @Monitor('motionEnabled')
  motionPolicyChanged(): void {
    if (this.motionEnabled) { return; }
    this.getUIContext().animateTo({ duration: 0 }, () => this.updateVisual(() => {
      this.shown = true;
      this.lifelineScale = 1;
      this.lifelineOpacity = 1;
    }));
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
  }

  private toneColor(): ResourceColor {
    return this.danger ? $r('app.color.danger_strong') : $r('app.color.success');
  }

  build() {
    if (!this.expired) {
      Stack({ alignContent: Alignment.TopStart }) {
        Row({ space: 10 }) {
          Stack() {
            Image(this.danger ? $r('app.media.icon_warning') : $r('app.media.icon_check_circle'))
              .width(18).height(18).fillColor(this.toneColor())
              .accessibilityLevel('no')
          }.width(24).height(24).flexShrink(0).accessibilityLevel('no-hide-descendants')
          Flex({
            direction: FlexDirection.Row, wrap: FlexWrap.Wrap, alignItems: ItemAlign.Baseline,
            space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(4) }
          }) {
            Text(this.danger ? '验证未通过' : '验证通过').id('gameplay-feedback-title')
              .fontWeight(600).fontSize(12).lineHeight('15.6fp').fontColor(this.toneColor())
            Text(this.message).id(this.messageId).constraintSize({ maxWidth: '100%' })
              .fontSize(13).lineHeight('19.5fp').fontColor($r('app.color.text'))
          }.height('auto').layoutWeight(1)
        }.width('100%').constraintSize({ minHeight: 44 })
          .padding({ top: 10, bottom: 10, left: 14, right: 14 })
          .alignItems(VerticalAlign.Center)
        if (this.transient) {
          Rect().width('100%').height(2)
            .fill(this.toneColor())
            .position({ bottom: 0, left: 0 })
            .scale({ x: this.lifelineScale, y: 1, centerX: 0 }).opacity(this.lifelineOpacity)
            .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        }
      }.id('gameplay-feedback').width('100%')
        .backgroundColor(this.danger ? $r('app.color.danger_surface') : $r('app.color.success_surface'))
        .border({ width: 1, color: this.danger ? $r('app.color.danger_border') : $r('app.color.success_border'),
          radius: 16 }).clip(true)
        .opacity(this.shown ? 1 : 0).translate({ y: this.shown ? 0 : 12 })
        .scale({ x: this.shown ? 1 : 0.985, y: this.shown ? 1 : 0.985 })
        .onAppear(() => this.start())
    }
  }
}
