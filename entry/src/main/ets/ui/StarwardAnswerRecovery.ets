import { UIUtils } from '@kit.ArkUI';

@ComponentV2
struct StarwardRecoveryPulse {
  @Param delay: number = 0;
  @Local private expanded: boolean = false;

  build() {
    Circle().width(104).height(104).fill(Color.Transparent)
      .stroke($r('app.color.accent_border')).strokeWidth(1)
      .scale({ x: this.expanded ? 1.4 : 0.85, y: this.expanded ? 1.4 : 0.85 })
      .opacity(this.expanded ? 0 : 0.75).hitTestBehavior(HitTestMode.None)
      .onAppear(() => {
        this.getUIContext().animateTo({ duration: 2400, delay: this.delay, iterations: -1, curve: Curve.EaseOut },
          () => UIUtils.applySync(() => { this.expanded = true; }));
      })
  }
}

@ComponentV2
struct StarwardRecoverySweep {
  @Require @Param panelWidth: number;
  @Require @Param panelHeight: number;
  @Local private swept: boolean = false;

  build() {
    Column() {}
      .width(this.panelWidth).height(this.panelHeight)
      .linearGradient({ angle: 115, colors: [[Color.Transparent, 0.35],
        [$r('app.color.accent'), 0.5], [Color.Transparent, 0.65]] })
      .translate({ x: this.swept ? this.panelWidth : -this.panelWidth })
      .opacity(0.16).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      .onAppear(() => {
        this.getUIContext().animateTo({ duration: 1200, curve: Curve.EaseOut },
          () => UIUtils.applySync(() => { this.swept = true; }));
      })
  }
}

@ComponentV2
struct StarwardRecoverySpinner {
  @Local private angle: number = 0;

  build() {
    Image($r('app.media.icon_reconnect')).width(20).height(20)
      .fillColor($r('app.color.text')).rotate({ angle: this.angle }).accessibilityLevel('no')
      .onAppear(() => {
        this.getUIContext().animateTo({ duration: 1000, iterations: -1, curve: Curve.Linear },
          () => UIUtils.applySync(() => { this.angle = 360; }));
      })
  }
}

/** Centered content for the official answer recovery modal. */
@ComponentV2
export struct StarwardAnswerRecovery {
  @Require @Param pending: boolean;
  @Param displayFont: string = 'serif';
  @Param motionEnabled: boolean = false;
  @Event retry: () => void = () => {};
  @Event stay: () => void = () => {};
  @Local private panelWidth: number = 0;
  @Local private panelHeight: number = 0;
  private maySweep: boolean = false;

  aboutToAppear(): void { this.maySweep = this.motionEnabled; }

  @Monitor('motionEnabled')
  private motionPolicyChanged(): void {
    if (!this.motionEnabled) { this.maySweep = false; }
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
          if (this.motionEnabled && this.maySweep && this.panelWidth > 0 && this.panelHeight > 0) {
            StarwardRecoverySweep({ panelWidth: this.panelWidth, panelHeight: this.panelHeight })
              .position({ x: 0, y: 0 })
          }
          Stack() {
            if (this.motionEnabled) {
              StarwardRecoveryPulse().position({ x: -8, y: -8 })
              StarwardRecoveryPulse({ delay: 1200 }).position({ x: -8, y: -8 })
            }
            Image($r('app.media.icon_broadcast')).width(42).height(42)
              .fillColor($r('app.color.accent_text')).accessibilityLevel('no')
          }.width(88).height(88).borderRadius(44).backgroundColor($r('app.color.accent_soft'))
            .margin({ top: 8, bottom: 28 }).accessibilityLevel('no-hide-descendants')
          Text('旅途信号 · 暂时中断').fontFamily('monospace').fontWeight(FontWeight.Medium)
            .fontSize(11).lineHeight('14fp').letterSpacing('1.8fp').fontColor($r('app.color.accent_text'))
          Text('答案还在，等待回音').fontFamily(this.displayFont).fontWeight(FontWeight.Medium)
            .fontSize(24).lineHeight('31.2fp').fontColor($r('app.color.strong'))
            .textAlign(TextAlign.Center).lineBreakStrategy(LineBreakStrategy.BALANCED)
            .margin({ top: 16, bottom: 16 })
          Text('暂时未能确认提交结果。你的输入仍在，重试会确认同一次提交，不会重复计次。')
            .width('100%').fontSize(15).lineHeight('28.5fp').fontColor($r('app.color.muted'))
            .textAlign(TextAlign.Center)
          Column({ space: 10 }) {
            Button({ type: ButtonType.Capsule }) {
              Row({ space: 8 }) {
                if (this.motionEnabled && this.pending) {
                  StarwardRecoverySpinner()
                } else {
                  Image($r('app.media.icon_reconnect')).width(20).height(20)
                    .fillColor($r('app.color.text')).accessibilityLevel('no')
                }
                Text(this.pending ? '正在重新连接…' : '重新连接')
                  .fontSize(16).fontWeight(600).fontColor($r('app.color.text'))
              }
            }.id('gameplay-answer-retry').width('100%').constraintSize({ minHeight: 46 })
              .accessibilityText(this.pending ? '正在重新连接…' : '重新连接')
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: $r('app.color.answer_recovery_button_border') })
              .enabled(!this.pending)
              .onClick(() => this.retry())
            Button('留在当前页面', { type: ButtonType.Capsule })
              .id('gameplay-answer-retry-stay').width('100%').constraintSize({ minHeight: 46 })
              .fontSize(16).fontWeight(600).fontColor($r('app.color.strong'))
              .backgroundColor(Color.Transparent).enabled(!this.pending).onClick(() => this.stay())
          }.width('100%').margin({ top: 28 })
        }.id('gameplay-answer-retry-dialog').width('100%').padding(24)
          .backgroundColor($r('app.color.raised')).border({ width: 1, color: $r('app.color.accent_border'), radius: 18 })
          .clip(true)
          .onAreaChange((_previous: Area, current: Area) => {
            const width: number = Number(current.width);
            const height: number = Number(current.height);
            if (Number.isFinite(width) && width > 0 && this.panelWidth !== width) { this.panelWidth = width; }
            if (Number.isFinite(height) && height > 0 && this.panelHeight !== height) { this.panelHeight = height; }
          })
      }.width('100%').constraintSize({ maxWidth: 460 }).align(Alignment.Center).scrollBar(BarState.Off)
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 20, bottom: 20 })
  }
}
