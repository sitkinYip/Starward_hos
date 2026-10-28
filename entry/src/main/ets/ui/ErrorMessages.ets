/** Reactive error presentation: @Param keeps empty-to-error and retry updates observable. */
@ComponentV2
export struct InlineError {
  @Param message: string = '';
  @Param fieldId: string = 'validation-message';

  build() {
    if (this.message.length > 0) {
      Text(this.message).id(this.fieldId).fontSize(13).lineHeight('22.1fp')
        .fontColor($r('app.color.danger')).width('100%').accessibilityText(this.message)
    }
  }
}

@ComponentV2
export struct ErrorNotice {
  @Param message: string = '';
  @Param retryable: boolean = false;
  @Event retry: () => void = () => {};
  @Event returnHome: () => void = () => {};

  build() {
    if (this.message.length > 0) {
      Row({ space: 12 }) {
        Image($r('app.media.icon_warning')).width(22).height(22).fillColor($r('app.color.danger'))
          .margin({ top: 2 }).accessibilityLevel('no')
        Column({ space: 12 }) {
          Text(this.message).id('error-message').fontSize(14).lineHeight('23.8fp')
            .fontColor($r('app.color.danger')).width('100%').accessibilityText(`错误：${this.message}`)
          Row({ space: 8 }) {
            if (this.retryable) {
              Button('重试', { type: ButtonType.Normal }).id('request-retry').height(40)
                .fontSize(13).padding({ left: 14, right: 14 }).borderRadius(10)
                .fontColor($r('app.color.text')).backgroundColor($r('app.color.surface'))
                .border({ width: 1, color: $r('app.color.border_strong') }).onClick(() => this.retry())
            }
            Button({ type: ButtonType.Normal }) {
              Row({ space: 8 }) {
                Image($r('app.media.icon_house')).width(18).height(18).fillColor($r('app.color.on_accent'))
                  .objectFit(ImageFit.Contain).accessibilityLevel('no')
                Text('回到首页').fontSize(13).fontWeight(600)
              }
            }.id('error-return-home').height(40).padding({ left: 14, right: 14 }).borderRadius(10)
              .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
              .onClick(() => this.returnHome())
          }.width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Top).padding(16).margin({ top: 16, bottom: 16 })
        .backgroundColor($r('app.color.danger_surface'))
        .border({ width: 1, color: $r('app.color.danger_border'), radius: 10 })
    }
  }
}
