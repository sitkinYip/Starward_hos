import { curves } from '@kit.ArkUI';

@ComponentV2
export struct StarwardAnswerGuide {
  @Param reducedMotion: boolean = true;
  @Event dismiss: () => void = () => {};
  @Event locate: () => void = () => {};
  @Event measured: (height: number) => void = () => {};

  private entrance(): TransitionEffect {
    if (this.reducedMotion) { return TransitionEffect.IDENTITY; }
    return TransitionEffect.asymmetric(
      TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: 18 }))
        .animation({ duration: 620, curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) }),
      TransitionEffect.IDENTITY);
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Text('01').width(38).height(38).textAlign(TextAlign.Center)
          .fontFamily('monospace').fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent_text')).border({ width: 1, color: $r('app.color.accent_border') })
          .accessibilityLevel('no')
        Column({ space: 4 }) {
          Text('答案在题目下方').fontSize(14).fontWeight(600).fontColor($r('app.color.strong'))
          Text('向下阅读题目，在卡片底部填写或选择答案；完成后解锁下一题。')
            .fontSize(12).lineHeight('18.6fp').fontColor($r('app.color.muted'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Center).hitTestBehavior(HitTestMode.None)
      Row({ space: 6 }) {
        Button('知道了', { type: ButtonType.Capsule }).id('gameplay-answer-guide-dismiss')
          .constraintSize({ minHeight: 44 }).padding({ left: 14, right: 14 })
          .fontSize(14).fontWeight(600).fontColor($r('app.color.text'))
          .backgroundColor(Color.Transparent)
          .focusOnTouch(false).onClick(() => this.dismiss())
        Button('定位答题区', { type: ButtonType.Capsule }).id('gameplay-answer-guide-locate')
          .constraintSize({ minHeight: 44 }).padding({ left: 14, right: 14 })
          .fontSize(14).fontWeight(600).fontColor($r('app.color.on_accent'))
          .backgroundColor($r('app.color.accent')).focusOnTouch(false).onClick(() => this.locate())
      }.width('100%').justifyContent(FlexAlign.End).hitTestBehavior(HitTestMode.None)
    }.id('gameplay-answer-guide').width('100%').constraintSize({ maxWidth: 620 })
      .padding(14).backgroundColor($r('app.color.raised')).border({ width: 1, color: $r('app.color.accent_border') })
      .shadow({ radius: 40, color: $r('app.color.choice_shadow'), offsetY: 16 })
      .hitTestBehavior(HitTestMode.None).transition(this.entrance())
      .onAreaChange((_previous: Area, current: Area) => this.measured(Number(current.height)))
  }
}
