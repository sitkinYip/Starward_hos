import { StarwardLoadingAtlas } from './StarwardAtlas';

@ComponentV2
export struct StarwardAssignmentRequest {
  @Require @Param loadingId: string;
  @Require @Param loadingLabel: string;
  @Param message: string = '';
  @Param displayFont: string = 'serif';
  @Param motionEnabled: boolean = false;
  @Param retryable: boolean = false;
  @Event retry: () => void = () => {};
  @Event returnHome: () => void = () => {};

  @Builder
  private loading() {
    Column({ space: 14 }) {
      StarwardLoadingAtlas({ diameter: 112, motionEnabled: this.motionEnabled })
      Text(this.loadingLabel).id(this.loadingId)
        .fontFamily(this.displayFont).fontSize(16).lineHeight('24fp').fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
    }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 4 })
  }

  @Builder
  private failure() {
    Column({ space: 10 }) {
      Stack() {
        Image($r('app.media.icon_warning')).width(22).height(22).fillColor($r('app.color.danger'))
      }.width(38).height(38).borderRadius(19).backgroundColor($r('app.color.danger_surface'))
        .accessibilityLevel('no-hide-descendants')
      Text('暂时无法打开旅程').fontFamily(this.displayFont).fontSize(20).lineHeight('28fp')
        .fontWeight(FontWeight.Medium).fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
        .lineBreakStrategy(LineBreakStrategy.BALANCED)
      Text(this.message).id('error-message').fontSize(14).lineHeight('24fp')
        .fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
      Column({ space: 4 }) {
        if (this.retryable) {
          Button('重新尝试', { type: ButtonType.Normal }).id('request-retry').width('100%')
            .constraintSize({ minHeight: 46 }).borderRadius(10).fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
            .onClick(() => this.retry())
        }
        Button('回到首页', { type: ButtonType.Normal }).id('error-return-home').width('100%')
          .constraintSize({ minHeight: 44 }).borderRadius(10).fontSize(14).fontColor($r('app.color.accent_text'))
          .backgroundColor(Color.Transparent).onClick(() => this.returnHome())
      }.width('100%').constraintSize({ maxWidth: 224 }).margin({ top: 6 })
    }.width('100%').constraintSize({ maxWidth: 360 })
      .padding({ left: 20, right: 20, top: 22, bottom: 14 }).borderRadius(16)
      .backgroundColor($r('app.color.surface')).border({ width: 1, color: $r('app.color.border') })
  }

  build() {
    Column() {
      if (this.message.length > 0) {
        this.failure()
      } else {
        this.loading()
      }
    }.id('assignment-request-state').width('100%').alignItems(HorizontalAlign.Center)
  }
}
