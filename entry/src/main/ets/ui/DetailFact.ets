@ComponentV2
export struct DetailFact {
  @Param label: string = '';
  @Param value: string = '';
  @Param source: Resource = $r('app.media.icon_puzzle');

  build() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Image(this.source).width(11).height(11).fillColor($r('app.color.subtle'))
          .objectFit(ImageFit.Contain).accessibilityLevel('no')
        Text(this.label).fontSize(11).lineHeight('16fp').fontColor($r('app.color.subtle'))
      }.width('100%')
      Text(this.value).fontSize(13).lineHeight('20.8fp').fontColor($r('app.color.text')).width('100%')
    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
  }
}
