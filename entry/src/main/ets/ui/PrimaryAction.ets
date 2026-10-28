@ComponentV2
export struct PrimaryAction {
  @Param label: string = '';
  @Param actionEnabled: boolean = true;
  @Param arrow: boolean = false;
  @Event action: () => void = () => {};

  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 16 }) {
        Text(this.label).fontSize(16).fontWeight(600).letterSpacing(0.96)
        if (this.arrow) {
          Image($r('app.media.icon_arrow_right')).width(20).height(20).fillColor($r('app.color.on_accent'))
            .objectFit(ImageFit.Contain).accessibilityLevel('no')
        }
      }.justifyContent(FlexAlign.Center).width('100%')
    }.id('primary-action').width('100%').constraintSize({ minHeight: 52 })
      .height(52).padding({ left: 16, right: 16 }).borderRadius(10)
      .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
      .enabled(this.actionEnabled).onClick(() => this.action())
  }
}
