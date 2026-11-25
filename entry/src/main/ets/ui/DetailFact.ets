@ComponentV2
export struct DetailFact {
  @Param label: string = '';
  @Param value: string = '';
  @Param source: Resource | undefined = undefined;

  build() {
    Row({ space: 16 }) {
      Row({ space: 6 }) {
        if (this.source !== undefined) {
          Image(this.source).width(14).height(14).fillColor($r('app.color.muted'))
            .objectFit(ImageFit.Contain).accessibilityLevel('no')
        } else {
          Blank().width(14)
        }
        Text(this.label).fontSize(12).lineHeight('17fp').fontColor($r('app.color.muted'))
      }.constraintSize({ maxWidth: '40%' })
      Text(this.value).fontSize(14).lineHeight('20fp').fontWeight(600)
        .fontFeature("'tnum' 1").fontColor($r('app.color.strong'))
        .layoutWeight(1).textAlign(TextAlign.End)
    }.width('100%').constraintSize({ minHeight: 28 }).alignItems(VerticalAlign.Center)
  }
}
