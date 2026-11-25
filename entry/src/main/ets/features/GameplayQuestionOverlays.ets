@ComponentV2
struct GameplayOverlayClose {
  @Param compact: boolean = false;
  @Require @Param label: string;
  @Event close: () => void = () => {};

  build() {
    Button({ type: this.compact ? ButtonType.Circle : ButtonType.Normal }) {
      Image($r('app.media.icon_close_bold')).width(this.compact ? 15 : 24).height(this.compact ? 15 : 24)
        .fillColor($r('app.color.muted')).accessibilityLevel('no')
    }.id('gameplay-sheet-close').width(this.compact ? 30 : 44).height(this.compact ? 30 : 44).padding(0)
      .borderRadius(this.compact ? 15 : 16)
      .backgroundColor(this.compact ? $r('app.color.input') : $r('app.color.surface_hover'))
      .borderWidth(this.compact ? 1 : 0).borderColor($r('app.color.border'))
      .responseRegion({ x: this.compact ? -7 : 0, y: this.compact ? -7 : 0, width: 44, height: 44 })
      .accessibilityText(this.label).onClick(() => this.close())
  }
}

@ComponentV2
export struct GameplayChoicePopup {
  @Require @Param status: string;
  @Require @Param maxHeight: number;
  @BuilderParam content: () => void;
  @Event close: () => void = () => {};

  build() {
    Column() {
      Row({ space: 12 }) {
        Text(this.status).layoutWeight(1).fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.muted'))
        GameplayOverlayClose({ compact: true, label: '收起选项', close: () => this.close() })
      }.width('100%').padding({ top: 12, right: 14, bottom: 10, left: 18 })
        .borderWidth({ bottom: 1 }).borderColor($r('app.color.border'))
      Scroll() {
        Column() {
          this.content()
        }.width('100%').padding({ top: 12, right: 14, bottom: 14, left: 14 })
      }.id('gameplay-choice-scroll').width('100%').height(LayoutPolicy.wrapContent).align(Alignment.Top)
        .constraintSize({ maxHeight: Math.max(60, this.maxHeight - 53) }).scrollBar(BarState.Auto)
    }.id('gameplay-choice-sheet').width('100%').backgroundColor($r('app.color.gameplay_overlay_tint'))
      .border({ width: 1, color: $r('app.color.border_strong'), radius: 24 }).clip(true)
  }
}

@ComponentV2
export struct GameplayHintSheet {
  @Require @Param maxHeight: number;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
  @BuilderParam content: () => void;
  @Event close: () => void = () => {};

  build() {
    Column() {
      Row() {}.width(36).height(3).borderRadius(1.5).margin({ bottom: 14 })
        .backgroundColor($r('app.color.accent_border'))
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      Row({ space: 12 }) {
        Text('查看提示').layoutWeight(1).fontSize(30).fontWeight(FontWeight.Medium)
          .lineHeight('42fp').margin({ top: 10 }).fontColor($r('app.color.strong'))
        GameplayOverlayClose({ label: '关闭查看提示', close: () => this.close() })
      }.width('100%').alignItems(VerticalAlign.Top).padding({ bottom: 12 })
        .constraintSize({ minHeight: 65 })
        .borderWidth({ bottom: 1 }).borderColor($r('app.color.border_strong'))
      Scroll() {
        Column({ space: 12 }) {
          this.content()
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 12 })
      }.id('gameplay-hint-scroll').width('100%').height(LayoutPolicy.wrapContent).align(Alignment.Top)
        .constraintSize({ maxHeight: Math.max(72, this.maxHeight - 117) }).scrollBar(BarState.Auto)
    }.id('gameplay-hint-sheet').width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 15, bottom: 20, left: 16 + this.leftInset, right: 16 + this.rightInset })
  }
}
