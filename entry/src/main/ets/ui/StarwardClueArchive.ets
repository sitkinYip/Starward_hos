import { ClueSpan, clueTextParts, clueTitle } from '../business/GameplayClues';
import { GameplayClue } from '../business/GameplayModels';

/** Mobile archive below the completed answer. */
@ComponentV2
export struct StarwardClueArchive {
  @Require @Param clues: GameplayClue[];
  @Param displayFont: string = 'serif';
  @Event opened: (id: string) => void = () => {};

  private number(value: number): string { return value < 10 ? `0${value}` : value.toString(); }

  private preview(clue: GameplayClue): ClueSpan[] {
    if (clue.content.text.length === 0) { return [new ClueSpan('点击查看已解锁内容')]; }
    return clueTextParts(clue.content.text, true)[0]?.spans || [];
  }

  @Builder
  card(clue: GameplayClue, index: number) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 11 }) {
        Column({ space: 7 }) {
          Text(this.number(index + 1)).fontFamily('monospace').fontSize(18).lineHeight('18fp')
            .fontWeight(FontWeight.Medium).letterSpacing('-1.44fp').fontColor($r('app.color.accent_text'))
          Text(clue.kind.toUpperCase()).fontFamily('monospace').fontSize(8).lineHeight('9.6fp')
            .letterSpacing('1.12fp').fontColor($r('app.color.accent_muted'))
        }.width(52).constraintSize({ minHeight: 50 }).justifyContent(FlexAlign.Center)
          .border({ width: { right: 1 }, color: $r('app.color.border') })
          .accessibilityLevel('no-hide-descendants')
        Column({ space: 5 }) {
          Text(clueTitle(clue)).id(`gameplay-clue-title-${index}`).width('100%')
            .fontSize(15).fontWeight(600).letterSpacing('0.15fp').fontColor($r('app.color.strong'))
          if (this.preview(clue).length > 0) {
            Text() {
              ForEach(this.preview(clue), (span: ClueSpan) => {
                if (span.highlight) {
                  Span(span.text).fontColor($r('app.color.clue_mark_text'))
                    .textBackgroundStyle({ color: $r('app.color.clue_mark_surface') })
                } else {
                  Span(span.text)
                }
              }, (span: ClueSpan, segment: number) => `${segment}:${span.highlight}:${span.text}`)
            }.width('100%').fontSize(13).lineHeight('20.8fp').fontColor($r('app.color.muted'))
              .maxLines(2).textOverflow({ overflow: TextOverflow.Clip })
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Stack() {
          Circle().width(24).height(24).fill(Color.Transparent).stroke($r('app.color.accent_soft'))
            .strokeWidth(1).strokeDashArray([2, 2])
          Image($r('app.media.icon_arrow_right')).width(18).height(18).fillColor($r('app.color.accent_text'))
        }.width(34).height(34).borderRadius(17).backgroundColor($r('app.color.accent_faint'))
          .border({ width: 1, color: $r('app.color.accent_border') }).margin({ left: 4 })
          .accessibilityLevel('no-hide-descendants')
      }.width('100%').padding({ top: 14, right: 12, bottom: 15, left: 8 })
    }.id(`gameplay-clue-${index}`).width('100%').padding(0).borderRadius(0)
      .backgroundColor($r('app.color.inset')).border({ width: 1, color: $r('app.color.border_strong') })
      .accessibilityText(clueTitle(clue)).onClick(() => this.opened(clue.id))
  }

  build() {
    Column() {
      Row().width('100%').height(1).linearGradient({ angle: 90,
        colors: [[Color.Transparent, 0], [$r('app.color.accent_border'), 0.22],
          [$r('app.color.accent_soft'), 0.72], [Color.Transparent, 1]] }).accessibilityLevel('no')
      Row({ space: 24 }) {
        Column({ space: 8 }) {
          Text('UNLOCKED ARCHIVE').fontFamily('monospace').fontSize(11).lineHeight('13.2fp')
            .fontWeight(600).letterSpacing('1.76fp').fontColor($r('app.color.accent_muted'))
          Text('通关线索').fontFamily(this.displayFont).fontSize(27).fontWeight(FontWeight.Medium)
            .lineHeight('32.4fp').fontColor($r('app.color.strong'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 8 }) {
          Text(this.number(this.clues.length)).fontFamily('monospace').fontSize(26).lineHeight('23.4fp')
            .fontWeight(FontWeight.Medium).letterSpacing('-2.08fp').fontColor($r('app.color.accent_text'))
          Text('件已解锁').fontFamily('monospace').fontSize(9).lineHeight('10.8fp')
            .letterSpacing('1.08fp').fontColor($r('app.color.subtle'))
        }.constraintSize({ minWidth: 66 }).alignItems(HorizontalAlign.End).padding({ bottom: 4 })
          .accessibilityText(`已解锁 ${this.clues.length} 件线索`)
      }.width('100%').margin({ top: 28, bottom: 20 })
      Column({ space: 11 }) {
        ForEach(this.clues, (clue: GameplayClue, index: number) => {
          this.card(clue, index)
        }, (clue: GameplayClue, index: number) => `${index}:${JSON.stringify(clue)}`)
      }.width('100%')
    }.id('gameplay-clues-panel').width('100%').margin({ top: 34 }).padding({ bottom: 12 })
  }
}
