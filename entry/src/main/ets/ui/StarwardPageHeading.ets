@ComponentV2
export struct StarwardPageHeading {
  @Require @Param title: string;
  @Param nodeId: string = '';

  build() {
    Text(this.title).id(this.nodeId).fontSize(30).lineHeight('37.5fp')
      .fontWeight(FontWeight.Bold).fontColor($r('app.color.strong'))
      .lineBreakStrategy(LineBreakStrategy.BALANCED).width('100%')
  }
}
