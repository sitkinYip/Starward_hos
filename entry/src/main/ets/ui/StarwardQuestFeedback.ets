import { curves, UIUtils } from '@kit.ArkUI';

@ComponentV2
struct StarwardFeedbackOrbit {
  @Require @Param color: ResourceColor;
  @Local private angle: number = 0;

  build() {
    Circle().width(36).height(36).fill(Color.Transparent).stroke(this.color)
      .strokeWidth(1).strokeDashArray([2, 2]).opacity(0.34)
      .rotate({ angle: this.angle }).hitTestBehavior(HitTestMode.None)
      .onAppear(() => {
        this.getUIContext().animateTo({ duration: 5000, curve: Curve.Linear, iterations: -1 },
          () => UIUtils.applySync(() => { this.angle = 360; }));
      })
  }
}

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
  @Local private ringScale: number = 0.2;
  @Local private ringOpacity: number = 0;
  private timer: number = -1;
  private started: boolean = false;

  aboutToAppear(): void { this.shown = !this.motionEnabled; }

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
    const curve = curves.cubicBezierCurve(0.32, 0.72, 0, 1);
    const impact = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
    // The mobile Web card's child rule wins over the standalone panel animation.
    context.animateTo({ duration: 720, curve }, () => UIUtils.applySync(() => {
      this.shown = true;
    }));
    context.animateTo({ duration: 920, curve: impact }, () => UIUtils.applySync(() => {
      this.ringScale = 18;
    }));
    context.keyframeAnimateTo({ iterations: 1 }, [
      { duration: 221, curve: impact, event: () => UIUtils.applySync(() => { this.ringOpacity = 0.72; }) },
      { duration: 699, curve: impact, event: () => UIUtils.applySync(() => { this.ringOpacity = 0; }) }
    ]);
    if (this.transient) {
      context.animateTo({ duration: 3000, curve: Curve.Linear }, () => UIUtils.applySync(() => {
        this.lifelineScale = 0;
        this.lifelineOpacity = 0.3;
      }));
    }
  }

  @Monitor('motionEnabled')
  motionPolicyChanged(): void {
    if (this.motionEnabled) { return; }
    this.getUIContext().animateTo({ duration: 0 }, () => UIUtils.applySync(() => {
      this.shown = true;
      this.ringScale = 0.2;
      this.ringOpacity = 0;
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

  build() {
    if (!this.expired) {
      Stack({ alignContent: Alignment.TopStart }) {
        Row({ space: 14 }) {
          Stack() {
            Image(this.danger ? $r('app.media.icon_warning') : $r('app.media.icon_check_circle'))
              .width(24).height(24)
              .fillColor(this.danger ? $r('app.color.danger') : $r('app.color.success'))
              .accessibilityLevel('no')
            if (this.motionEnabled) {
              StarwardFeedbackOrbit({ color: this.danger ? $r('app.color.danger') : $r('app.color.success') })
            } else {
              Circle().width(36).height(36).fill(Color.Transparent)
                .stroke(this.danger ? $r('app.color.danger') : $r('app.color.success'))
                .strokeWidth(1).strokeDashArray([2, 2]).opacity(0.34).hitTestBehavior(HitTestMode.None)
            }
          }.width(46).height(46).flexShrink(0).borderRadius(23)
            .backgroundColor(this.danger ? $r('app.color.danger_surface') : $r('app.color.success_surface'))
            .border({ width: 1, color: this.danger ? $r('app.color.danger_border') : $r('app.color.success_border') })
            .accessibilityLevel('no-hide-descendants')
          Column({ space: 4 }) {
            Text(this.danger ? '验证未通过' : '验证通过').id('gameplay-feedback-title')
              .fontFamily('monospace').fontWeight(600).fontSize(10).lineHeight('12fp')
              .letterSpacing('1.6fp')
              .fontColor(this.danger ? $r('app.color.danger_strong') : $r('app.color.success'))
            Text(this.message).id(this.messageId).width('100%')
              .fontSize(13).lineHeight('20.8fp').fontColor($r('app.color.text'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').constraintSize({ minHeight: 74 })
          .padding({ top: 13, bottom: 13, left: 13, right: 15 })
          .alignItems(VerticalAlign.Center)
        if (this.motionEnabled) {
          Circle().width(38).height(38).fill(Color.Transparent)
            .stroke(this.danger ? $r('app.color.danger_strong') : $r('app.color.success')).strokeWidth(1)
            .position({ left: 19, top: '50%' }).translate({ y: -19 })
            .scale({ x: this.ringScale, y: this.ringScale }).opacity(this.ringOpacity)
            .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        }
        if (this.transient) {
          Rect().width('100%').height(2)
            .fill(this.danger ? $r('app.color.danger_strong') : $r('app.color.success'))
            .position({ bottom: 0, left: 0 })
            .scale({ x: this.lifelineScale, y: 1, centerX: 0 }).opacity(this.lifelineOpacity)
            .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        }
      }.id('gameplay-feedback').width('100%').margin({ top: 16 })
        .backgroundColor(this.danger ? $r('app.color.danger_surface') : $r('app.color.success_surface'))
        .border({
          width: { left: 3, top: 1, right: 1, bottom: 1 },
          color: {
            left: this.danger ? $r('app.color.danger') : $r('app.color.success'),
            top: this.danger ? $r('app.color.danger_border') : $r('app.color.success_border'),
            right: this.danger ? $r('app.color.danger_border') : $r('app.color.success_border'),
            bottom: this.danger ? $r('app.color.danger_border') : $r('app.color.success_border')
          }, radius: 10
        }).clip(true).opacity(this.shown ? 1 : 0).translate({ y: this.shown ? 0 : 18 })
        .onAppear(() => this.start())
    }
  }
}
