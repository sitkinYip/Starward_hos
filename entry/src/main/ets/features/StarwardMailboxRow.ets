import { LengthMetrics, UIUtils } from '@kit.ArkUI';
import { starwardListReveal } from '../ui/StarwardMotion';

const LETTER_DATE = new Intl.DateTimeFormat('zh-CN', {
  year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false
});

/** Shared card appearance. Each inbox owns loading, navigation and receipt writes. */
@ComponentV2
export struct StarwardMailboxRow {
  @Require @Param nodeId: string;
  @Require @Param title: string;
  @Require @Param icon: Resource;
  @Require @Param sentAt: string;
  @Param summary: string = '';
  @Param source: string = '';
  @Param unread: boolean = false;
  @Param reading: boolean = false;
  @Param actionId: string = '';
  @Param motionEnabled: boolean = false;
  @Param revealDelay: number = 0;
  @Event open: () => void = () => {};
  @Event markRead: () => void = () => {};
  @Local private revealed: boolean = false;

  private dateLabel(): string {
    const date: Date = new Date(this.sentAt);
    return Number.isNaN(date.getTime()) ? '时间待确认' : LETTER_DATE.format(date);
  }

  build() {
    Stack({ alignContent: Alignment.End }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 14 }) {
          Stack() {
            Image(this.icon).width(20).height(20).objectFit(ImageFit.Contain)
              .fillColor($r('app.color.accent_text')).accessibilityLevel('no')
          }.width(40).height(40).flexShrink(0).borderRadius(16).backgroundColor($r('app.color.accent_soft'))
          Column({ space: 4 }) {
            Text(this.title).fontSize(17).fontWeight(FontWeight.Medium).lineHeight('23.8fp')
              .fontColor($r('app.color.strong')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              .wordBreak(WordBreak.BREAK_WORD).width('100%')
            if (this.summary.length > 0) {
              Text(this.summary).fontSize(13).lineHeight('20.15fp').fontColor($r('app.color.muted'))
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).wordBreak(WordBreak.BREAK_WORD).width('100%')
            }
            Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(3) } }) {
              if (this.source.length > 0 && this.source !== this.title) {
                Text(this.source).fontSize(11).lineHeight('16.5fp').fontColor($r('app.color.muted'))
              }
              Text(this.dateLabel()).fontSize(11).lineHeight('16.5fp').fontColor($r('app.color.muted'))
                .fontFeature("'tnum' 1")
            }.width('100%')
          }.layoutWeight(1).constraintSize({ minWidth: 0 }).alignItems(HorizontalAlign.Start)
          if (this.unread) {
            Circle().width(8).height(8).fill($r('app.color.accent')).accessibilityText('未读')
          } else {
            Image($r('app.media.icon_arrow_right')).width(16).height(16).objectFit(ImageFit.Contain)
              .fillColor($r('app.color.muted')).accessibilityLevel('no')
          }
        }.width('100%').alignItems(VerticalAlign.Center)
          .padding({ top: 14, bottom: 14, left: 16, right: this.unread ? 52 : 16 })
      }.id(this.nodeId).width('100%').constraintSize({ minHeight: 76 }).padding(0).borderRadius(24)
        .backgroundColor(Color.Transparent).onClick(() => this.open())
      if (this.unread && this.actionId.length > 0) {
        Button({ type: ButtonType.Normal }) {
          Image($r('app.media.icon_dots_three')).width(22).height(22).objectFit(ImageFit.Contain)
            .fillColor($r('app.color.subtle')).accessibilityLevel('no')
        }.id(this.actionId).width(40).height(44).padding(0).margin({ right: 6 })
          .borderRadius(10).backgroundColor(Color.Transparent).enabled(!this.reading).accessibilityText('来信操作')
          .bindMenu([{ value: '标为已读', action: () => this.markRead() }], { placement: Placement.BottomRight })
      }
    }.width('100%').backgroundColor(this.unread ? $r('app.color.glass_card_active_top') : $r('app.color.glass_card_top'))
      .border({ width: 1, radius: 24, color: this.unread ? $r('app.color.accent_border') : $r('app.color.border') })
      .clip(true).opacity(!this.motionEnabled || this.revealed ? 1 : 0)
      .translate({ y: !this.motionEnabled || this.revealed ? 0 : 14 })
      .animation(starwardListReveal(this.motionEnabled, this.revealDelay))
      .onAppear(() => {
        try { UIUtils.applySync(() => { this.revealed = true; }); } catch { this.revealed = true; }
      })
  }
}
