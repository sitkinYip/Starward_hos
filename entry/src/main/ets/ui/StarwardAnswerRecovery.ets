/** Centered content for the official answer recovery modal. */
@ComponentV2
export struct StarwardAnswerRecovery {
  @Require @Param pending: boolean;
  @Param displayFont: string = 'serif';
  @Event retry: () => void = () => {};
  @Event stay: () => void = () => {};

  build() {
    Stack() {
      Scroll() {
        Column() {
          Stack() {
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
                Image($r('app.media.icon_reconnect')).width(20).height(20)
                  .fillColor($r('app.color.text')).accessibilityLevel('no')
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
      }.width('100%').constraintSize({ maxWidth: 460 }).align(Alignment.Center).scrollBar(BarState.Off)
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 20, bottom: 20 })
  }
}
