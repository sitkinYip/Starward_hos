import { ExtraDisplay } from '../business/models';

@ComponentV2
export struct StarwardQuestMessages {
  @Require @Param items: ExtraDisplay[];
  @Require @Param groupId: string;

  build() {
    Column({ space: 12 }) {
      ForEach(this.items, (item: ExtraDisplay, index: number) => {
        Column({ space: 4 }) {
          Text(item.label).id(`${this.groupId}-label-${index}`).width('100%')
            .fontSize(12.8).lineHeight('21.76fp').wordBreak(WordBreak.BREAK_WORD)
            .fontColor($r('app.color.muted'))
          Text(item.text).id(`${this.groupId}-text-${index}`).width('100%')
            .fontSize(16).lineHeight('27.2fp').wordBreak(WordBreak.BREAK_WORD)
            .fontColor($r('app.color.text'))
        }.width('100%').alignItems(HorizontalAlign.Start)
          .padding({ top: 12, bottom: 12, left: 16, right: 16 })
          .border({ width: { left: 2 }, color: $r('app.color.accent_border') })
          .backgroundColor($r('app.color.surface'))
      }, (item: ExtraDisplay, index: number) => `${index}:${JSON.stringify(item)}`)
    }.id(this.groupId).width('100%').margin({ top: 12, bottom: 24 })
  }
}
