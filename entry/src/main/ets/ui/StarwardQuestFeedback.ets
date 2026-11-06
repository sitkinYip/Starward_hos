/** A single feedback event. Its lifetime affects this card only. */
@ComponentV2
export struct StarwardQuestFeedback {
  @Require @Param message: string;
  @Require @Param messageId: string;
  @Param danger: boolean = false;
  @Param transient: boolean = false;
  @Param reducedMotion: boolean = true;
  @Local private expired: boolean = false;
  @Local private remaining: number = 100;
  private timer: number = -1;

  private startLifetime(): void {
    if (!this.transient || this.timer !== -1 || this.expired) { return; }
    this.timer = setTimeout(() => {
      this.timer = -1;
      this.expired = true;
    }, 3000);
    if (!this.reducedMotion) {
      this.getUIContext().animateTo({ duration: 3000, curve: Curve.Linear }, () => {
        this.remaining = 0;
      });
    }
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
        if (this.transient) {
          Progress({ value: this.remaining, total: 100, type: ProgressType.Linear })
            .width('100%').height(2).style({ strokeWidth: 2, enableSmoothEffect: false })
            .color(this.danger ? $r('app.color.danger') : $r('app.color.success'))
            .backgroundColor(Color.Transparent).position({ bottom: 0, left: 0 })
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
        }).clip(true)
        .onAppear(() => this.startLifetime())
    }
  }
}
