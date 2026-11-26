import { STARWARD_RADIUS_ROUND } from './StarwardRadii';

/** Reactive error presentation: @Param keeps empty-to-error and retry updates observable. */
@ComponentV2
export struct InlineError {
  @Param message: string = '';
  @Param fieldId: string = 'validation-message';

  build() {
    if (this.message.length > 0) {
      Text(this.message).id(this.fieldId).fontSize(13).lineHeight('22.1fp')
        .fontColor($r('app.color.danger_strong')).width('100%').accessibilityText(this.message)
    }
  }
}

@ComponentV2
export struct ErrorNotice {
  @Param message: string = '';
  @Param retryable: boolean = false;
  @Param topMargin: number = 0;
  @Param showReturn: boolean = false;
  @Param returnLabel: string = '回到首页';
  @Event retry: () => void = () => {};
  @Event returnHome: () => void = () => {};

  build() {
    if (this.message.length > 0) {
      Column({ space: 4 }) {
        Text(this.message).id('error-message').fontSize(14).lineHeight('23.8fp')
          .fontColor($r('app.color.danger_strong')).width('100%').accessibilityText(this.message)
        if (this.retryable || this.showReturn) {
          Row({ space: 8 }) {
            if (this.retryable) {
              Button('重新尝试', { type: ButtonType.Normal }).id('request-retry').constraintSize({ minHeight: 44 })
                .borderRadius(STARWARD_RADIUS_ROUND)
                .fontSize(14).fontWeight(FontWeight.Medium).padding({ left: 10, right: 10 })
                .fontColor($r('app.color.accent_text')).backgroundColor(Color.Transparent).onClick(() => this.retry())
            }
            if (this.showReturn) {
              Button(this.returnLabel, { type: ButtonType.Normal }).id('error-return-home')
                .constraintSize({ minHeight: 44 }).borderRadius(STARWARD_RADIUS_ROUND)
                .fontSize(14).padding({ left: 10, right: 10 })
                .fontColor($r('app.color.muted')).backgroundColor(Color.Transparent).onClick(() => this.returnHome())
            }
          }.width('100%')
        }
      }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: this.topMargin })
    }
  }
}
