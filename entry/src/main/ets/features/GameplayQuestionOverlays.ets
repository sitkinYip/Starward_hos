import { STARWARD_RADIUS_PANEL } from '../ui/StarwardRadii';
import { STARWARD_SHEET_HEADER_MIN_HEIGHT, StarwardSheetHeader } from '../ui/StarwardSheet';

@ComponentV2
export struct GameplayChoicePopup {
  @Require @Param status: string;
  @Require @Param maxHeight: number;
  @Param usesSystemMaterial: boolean = false;
  @BuilderParam content: () => void;
  @Event close: () => void = () => {};

  build() {
    Column() {
      StarwardSheetHeader({ title: this.status, compact: true, closeId: 'gameplay-sheet-close',
        closeLabel: '收起选项', close: () => this.close() })
      Scroll() {
        Column() {
          this.content()
        }.width('100%').padding({ top: 12, right: 14, bottom: 14, left: 14 })
      }.id('gameplay-choice-scroll').width('100%').height(LayoutPolicy.wrapContent).align(Alignment.Top)
        .constraintSize({ maxHeight: Math.max(60, this.maxHeight - STARWARD_SHEET_HEADER_MIN_HEIGHT) })
        .scrollBar(BarState.Auto)
    }.id('gameplay-choice-sheet').width('100%')
      .backgroundColor(this.usesSystemMaterial ? Color.Transparent : $r('app.color.gameplay_overlay_tint'))
      .border({ width: this.usesSystemMaterial ? 0 : 1, color: $r('app.color.border_strong'),
        radius: STARWARD_RADIUS_PANEL }).clip(true)
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
      StarwardSheetHeader({ title: '查看提示', titleId: 'gameplay-hint-title', closeId: 'gameplay-sheet-close',
        closeLabel: '关闭查看提示', leftInset: this.leftInset, rightInset: this.rightInset, close: () => this.close() })
      Scroll() {
        Column({ space: 12 }) {
          this.content()
        }.width('100%').alignItems(HorizontalAlign.Start)
          .padding({ top: 12, bottom: 20, left: 16 + this.leftInset, right: 16 + this.rightInset })
      }.id('gameplay-hint-scroll').width('100%').height(LayoutPolicy.wrapContent).align(Alignment.Top)
        .constraintSize({ maxHeight: Math.max(72, this.maxHeight - STARWARD_SHEET_HEADER_MIN_HEIGHT) })
        .scrollBar(BarState.Auto)
    }.id('gameplay-hint-sheet').width('100%')
      .alignItems(HorizontalAlign.Center)
  }
}
