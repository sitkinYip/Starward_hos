/** Static brand frame. The content owns height; decoration cannot intercept input. */
@ComponentV2
export struct StarwardQuestionFrame {
  @Param frameId: string = '';
  @BuilderParam content: () => void;
  @Local frameWidth: number = 0;
  @Local frameHeight: number = 0;

  @Builder
  decoration() {
    // Match the measured Web border box: CSS corners at12 inside the1px
    // border are13 from the outside; a1px outline at offset-7 paints at6.
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {}
        .id('question-frame-inner')
        .width(this.frameWidth - 12).height(this.frameHeight - 12)
        .border({ width: 1, color: $r('app.color.accent'), radius: 0 }).opacity(0.09)
        .position({ x: 5, y: 5 })
      Column() {}
        .id('question-frame-top-left').width(28).height(28)
        // Web's later border-side shorthand resolves these lines to inherited currentColor.
        .border({ width: { top: 1, left: 1, right: 0, bottom: 0 }, color: $r('app.color.text') })
        .opacity(0.48).position({ top: 12, left: 12 })
      Column() {}
        .id('question-frame-top-right').width(28).height(28)
        .border({ width: { top: 1, right: 1, left: 0, bottom: 0 }, color: $r('app.color.text') })
        .opacity(0.48).position({ top: 12, right: 12 })
      Column() {}
        .id('question-frame-bottom-right').width(28).height(28)
        .border({ width: { bottom: 1, right: 1, left: 0, top: 0 }, color: $r('app.color.text') })
        .opacity(0.48).position({ bottom: 12, right: 12 })
      Column() {}
        .id('question-frame-bottom-left').width(28).height(28)
        .border({ width: { bottom: 1, left: 1, right: 0, top: 0 }, color: $r('app.color.text') })
        .opacity(0.48).position({ bottom: 12, left: 12 })
    }.width(this.frameWidth - 2).height(this.frameHeight - 2).position({ x: 1, y: 1 })
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }

  build() {
    // Absolute decoration in Column is excluded from size measurement, so a
    // disappearing feedback message can also shrink the frame without a loop.
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        this.content()
      }.width('100%')
      if (this.frameWidth > 14 && this.frameHeight > 14) {
        this.decoration()
      }
    }.id(this.frameId).width('100%').alignItems(HorizontalAlign.Start).backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border_strong'), radius: 0 })
      .onAreaChange((_previous: Area, current: Area) => {
        const width: number = Number(current.width);
        const height: number = Number(current.height);
        if (Number.isFinite(width) && width > 0 && width !== this.frameWidth) {
          this.frameWidth = width;
        }
        if (Number.isFinite(height) && height > 0 && height !== this.frameHeight) {
          this.frameHeight = height;
        }
      })
  }
}
