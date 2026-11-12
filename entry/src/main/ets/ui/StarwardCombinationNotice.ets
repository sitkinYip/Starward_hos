/** Branded content for the native combination completion modal. */
@ComponentV2
export struct StarwardCombinationNotice {
  @Require @Param completedCount: number;
  @Require @Param hasResults: boolean;
  @Require @Param panelWidth: number;
  @Require @Param maxHeight: number;
  @Require @Param viewportWidth: number;
  @Param displayFont: string = 'serif';
  @Event acknowledge: () => void = () => {};

  private compact(): boolean { return this.viewportWidth <= 620; }
  private wideInset(): number { return Math.max(38, Math.min(78, this.viewportWidth * 0.08)); }
  private titleSize(): number {
    const width: number = this.viewportWidth;
    return this.compact() ? Math.max(32, Math.min(46, width * 0.11)) : Math.max(34, Math.min(62, width * 0.07));
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: this.compact() ? 15 : 18 }) {
          Text(`${this.completedCount}`).id('gameplay-combination-notice-count')
            .width(82).height(82).fontSize(34).fontFamily('serif').textAlign(TextAlign.Center)
            .fontColor($r('app.color.completion_sigil_text'))
            .radialGradient({ center: ['50%', '50%'], radius: 41,
              colors: [[$r('app.color.completion_sigil_center'), 0], [$r('app.color.completion_sigil_edge'), 0.7]] })
            .border({ width: 1, radius: 41, color: $r('app.color.completion_sigil_border') })
            .accessibilityLevel('no')
          Text('QUEST SET COMPLETE').id('gameplay-combination-notice-eyebrow')
            .fontFamily('monospace').fontWeight(600).fontSize(12).lineHeight('14.4fp').letterSpacing('1.68fp')
            .fontColor($r('app.color.accent_muted')).textAlign(TextAlign.Center).accessibilityLevel('no')
          Text('组合谜题全部破解').id('gameplay-combination-notice-title').width('100%')
            .fontFamily(this.displayFont).fontWeight(FontWeight.Medium).fontSize(this.titleSize())
            .lineHeight(`${this.titleSize() * 1.08}fp`).letterSpacing(`${-0.035 * this.titleSize()}fp`)
            .fontColor($r('app.color.strong')).textAlign(TextAlign.Center).lineBreakStrategy(LineBreakStrategy.BALANCED)
          Text(`你已完成本次组合中的 ${this.completedCount} 道谜题。`).id('gameplay-combination-notice-detail')
            .constraintSize({ maxWidth: 500 }).fontSize(16).lineHeight('28.8fp').textAlign(TextAlign.Center)
            .fontColor($r('app.color.muted')).margin({ bottom: 8 })
          Button(this.hasResults ? '查看组合结果' : '知晓了', { type: ButtonType.Capsule })
            .id('gameplay-combination-notice-ack').constraintSize({ minHeight: 46, maxWidth: '100%' })
            .padding({ left: 20, right: 20, top: 8, bottom: 8 }).fontSize(16).fontWeight(600)
            .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
            .defaultFocus(true).onClick(() => this.acknowledge())
        }.width('100%').alignItems(HorizontalAlign.Center)
          // The outer and inner frames account for 8 vp of the content inset.
          .padding({ top: this.compact() ? 54 : this.wideInset() + 11,
            left: this.compact() ? 16 : this.wideInset() - 8, right: this.compact() ? 16 : this.wideInset() - 8,
            bottom: this.compact() ? 32 : this.wideInset() - 8 })
      }.width('100%').constraintSize({ maxHeight: this.maxHeight - 16 }).align(Alignment.Top)
        .scrollBar(BarState.Off).border({ width: 1, color: $r('app.color.completion_frame_inner') })
    }.id('gameplay-combination-notice').width(this.panelWidth).padding(7)
      .backgroundColor($r('app.color.completion_surface'))
      .border({ width: 1, color: $r('app.color.completion_frame_outer') })
  }
}
