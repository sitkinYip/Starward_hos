/** Inline disclosure scoped to one question content block. */
@ComponentV2
export struct StarwardQuestHint {
  @Require @Param text: string;
  @Require @Param contentIndex: number;
  @Param reducedMotion: boolean = true;
  @Local private expanded: boolean = false;

  build() {
    Column() {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 8 }) {
          Text('▸').width(12).fontSize(16).lineHeight('23fp')
            .textAlign(TextAlign.Center).fontColor($r('app.color.accent_text'))
            .accessibilityLevel('no')
            .rotate({ angle: this.expanded ? 90 : 0 })
            .animation({ duration: this.reducedMotion ? 0 : 180, curve: Curve.EaseOut })
          Text('查看提示').fontSize(16).lineHeight('23fp').fontColor($r('app.color.accent_text'))
        }.width('100%').justifyContent(FlexAlign.Start)
      }
        .id(`question-hint-${this.contentIndex}`)
        .accessibilityText('查看提示')
        .accessibilityDescription(this.expanded ? '已展开' : '已折叠')
        .width('100%').constraintSize({ minHeight: 44 })
        .padding(0).borderRadius(0).backgroundColor(Color.Transparent)
        .onClick(() => { this.expanded = !this.expanded; })
      if (this.expanded) {
        Text(this.text).id(`question-hint-content-${this.contentIndex}`).width('100%')
          .fontSize(16).lineHeight('27.2fp').fontColor($r('app.color.muted')).margin({ top: 12 })
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 14 })
      .border({ width: { left: 2, top: 0, right: 0, bottom: 0 }, color: $r('app.color.accent_border') })
  }
}
