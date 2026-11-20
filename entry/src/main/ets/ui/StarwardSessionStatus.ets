import { StarwardLoadingAtlas } from './StarwardAtlas';

@ComponentV2
export struct StarwardSessionStatus {
  @Param restoring: boolean = true;
  @Param message: string = '';
  @Param displayFont: string = 'serif';
  @Param viewport: number = 640;
  @Param safeBottom: number = 0;
  @Param motionEnabled: boolean = false;
  @Event retry: () => void = () => {};
  @Event useLogin: () => void = () => {};

  @Builder
  private divider() {
    Row({ space: 14 }) {
      Divider().layoutWeight(1).color($r('app.color.accent_border'))
      Image($r('app.media.icon_star_four')).width(12).height(12).fillColor($r('app.color.accent_muted'))
      Divider().layoutWeight(1).color($r('app.color.accent_border'))
    }.width('60%').constraintSize({ maxWidth: 240 }).accessibilityLevel('no-hide-descendants')
  }

  @Builder
  private recoveryActions() {
    Column({ space: 8 }) {
      Button('重新尝试', { type: ButtonType.Normal })
        .id(this.restoring ? 'session-restore-retry' : 'session-signout-retry')
        .width('100%').constraintSize({ minHeight: 48 }).borderRadius(10)
        .fontSize(14).fontWeight(600).fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
        .onClick(() => this.retry())
      if (this.restoring) {
        Button('重新登录', { type: ButtonType.Normal }).id('session-use-login')
          .width('100%').constraintSize({ minHeight: 44 })
          .fontSize(14).fontColor($r('app.color.accent_text')).backgroundColor(Color.Transparent)
          .onClick(() => this.useLogin())
      }
    }.width('100%').constraintSize({ maxWidth: 280 }).margin({ top: 4 })
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        if (this.restoring && this.message.length === 0) {
          StarwardLoadingAtlas({ diameter: Math.max(112, Math.min(240, this.viewport * 0.32)),
            motionEnabled: this.motionEnabled })
            .margin({ bottom: 6 })
          Text('星图正在显现').fontSize(10).letterSpacing(2.4).fontColor($r('app.color.accent_muted'))
        }
        Text(this.restoring ? (this.message.length === 0 ? '拾起你的冒险足迹' : '暂时无法恢复登录') :
          (this.message.length === 0 ? '正在退出登录…' : '暂时无法退出登录'))
          .fontFamily(this.displayFont).fontSize(24).lineHeight('34.8fp').fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.strong')).textAlign(TextAlign.Center).lineBreakStrategy(LineBreakStrategy.BALANCED)
        if (this.message.length > 0) {
          Text(this.message).fontSize(14).lineHeight('23.8fp').fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
          this.recoveryActions()
        } else if (this.restoring) {
          Row({ space: 10 }) {
            Circle().width(5).height(5).fill($r('app.color.accent')).accessibilityLevel('no')
            Text('正在读取冒险者资料…').fontSize(13).fontColor($r('app.color.muted'))
          }
          this.divider()
          Text('每一段走过的路，都有星光记得。').fontSize(12).lineHeight('21.6fp')
            .fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
        }
      }.id(this.restoring ? (this.message.length === 0 ? 'session-restoring' : 'session-restore-error') :
        (this.message.length === 0 ? 'session-signout' : 'session-signout-error'))
        .width('100%').constraintSize({ minHeight: this.viewport, maxWidth: 440 }).justifyContent(FlexAlign.Center)
        .padding({ top: 24, bottom: 24 + this.safeBottom, left: 20, right: 20 })
    }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top)
  }
}
