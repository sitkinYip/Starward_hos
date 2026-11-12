import { ClueSpan, ClueTextPart, clueTextParts } from '../business/GameplayClues';
import { GameplayClue } from '../business/GameplayModels';
import { StarwardQuestionImages } from './StarwardQuestionImages';

/** Reading content for the native modal; the footer remains outside its Scroll. */
@ComponentV2
export struct StarwardCombinationDialog {
  @Require @Param clue: GameplayClue;
  @Require @Param ownerKey: string;
  @Require @Param ownerIsCurrent: (key: string) => boolean;
  @Require @Param panelWidth: number;
  @Require @Param maxHeight: number;
  @Param displayFont: string = 'serif';
  @Param reducedMotion: boolean = true;
  @Event acknowledge: () => void = () => {};
  @Event openImage: (partIndex: number) => void = () => {};
  @Local private footerHeight: number = 0;

  private compact(): boolean { return this.panelWidth + 48 <= 620; }
  private bodyPadding(): number { return Math.max(30, Math.min(62, (this.panelWidth + 48) * 0.06)); }
  private footerPadding(): number { return Math.max(20, Math.min(62, (this.panelWidth + 48) * 0.06)); }
  private bodyHeight(): number {
    return Math.max(1, this.maxHeight - (this.footerHeight || (this.compact() ? 126 : 84)));
  }

  @Builder
  paragraph(part: ClueTextPart, index: number) {
    Text() {
      ForEach(part.spans, (span: ClueSpan) => {
        if (span.highlight) {
          Span(span.text).fontColor($r('app.color.clue_mark_text'))
            .textBackgroundStyle({ color: $r('app.color.clue_mark_surface') })
        } else {
          Span(span.text)
        }
      }, (span: ClueSpan, segment: number) => `${segment}:${span.highlight}:${span.text}`)
    }.id(`gameplay-combination-paragraph-${index}`).width('100%').fontSize(16).lineHeight('30.4fp')
      .fontColor($r('app.color.combination_body')).wordBreak(WordBreak.BREAK_WORD)
  }

  @Builder
  description() {
    Text(this.clue.content.description || '该本场线索会保留在当前会话中。')
      .id('gameplay-combination-description').fontSize(13).lineHeight('19.5fp')
      .fontColor($r('app.color.combination_description')).wordBreak(WordBreak.BREAK_WORD)
  }

  @Builder
  ackButton(full: boolean) {
    Button(this.clue.content.buttonText || '我知道了', { type: ButtonType.Capsule })
      .id('gameplay-combination-ack').constraintSize({ minHeight: 46, maxWidth: this.panelWidth - this.footerPadding() * 2 })
      .width(full ? '100%' : undefined).padding({ left: 22, right: 22, top: 8, bottom: 8 })
      .fontSize(16).fontWeight(600).fontColor($r('app.color.on_accent'))
      .backgroundColor($r('app.color.accent')).onClick(() => this.acknowledge())
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Text('COMBINED REVELATION').fontFamily('monospace').fontSize(11).lineHeight('13.2fp')
            .fontWeight(600).letterSpacing('1.76fp').fontColor($r('app.color.accent_muted'))
          Text(this.clue.content.title || '隐藏的本场线索').id('gameplay-combination-title')
            .fontFamily(this.displayFont).fontSize(Math.max(30, Math.min(50, (this.panelWidth + 48) * 0.06)))
            .fontWeight(FontWeight.Medium).fontColor($r('app.color.combination_title')).margin({ top: 14 })
          Column() {
            ForEach(clueTextParts(this.clue.content.text), (part: ClueTextPart, index: number) => {
              if (part.image.length > 0) {
                StarwardQuestionImages({ sources: [part.image], ownerKey: this.ownerKey,
                  ownerIsCurrent: this.ownerIsCurrent, groupId: `gameplay-combination-inline-${index}`,
                  imageLabel: '线索图片', maxHeight: Math.min(660, (this.maxHeight + 48) * 0.58),
                  reducedMotion: this.reducedMotion, opened: () => this.openImage(index) })
                  .margin({ top: 20, bottom: 20 })
              } else {
                this.paragraph(part, index)
              }
            }, (part: ClueTextPart, index: number) => `${index}:${JSON.stringify(part)}`)
          }.id('gameplay-combination-content').width('100%').alignItems(HorizontalAlign.Start).margin({ top: 28 })
        }.width('100%').alignItems(HorizontalAlign.Start)
          .padding({ top: this.bodyPadding() + 16, right: this.bodyPadding(), bottom: 30, left: this.bodyPadding() })
      }.id('gameplay-combination-scroll').width('100%').constraintSize({ maxHeight: this.bodyHeight() })
        .align(Alignment.Top).scrollBar(BarState.Off)
      Column() {
        if (this.compact()) {
          Column({ space: 20 }) {
            this.description()
            this.ackButton(true)
          }.width('100%').alignItems(HorizontalAlign.Start)
        } else {
          Row({ space: 20 }) {
            Column() {
              this.description()
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            this.ackButton(false)
          }.width('100%').alignItems(VerticalAlign.Center)
        }
      }.id('gameplay-combination-footer').width('100%')
        .padding({ left: this.footerPadding(), right: this.footerPadding(), top: 18, bottom: 18 })
        .backgroundColor($r('app.color.combination_footer'))
        .border({ width: { top: 1 }, color: $r('app.color.combination_footer_border') })
        .onAreaChange((_previous: Area, current: Area) => {
          const height: number = Number(current.height);
          if (Number.isFinite(height) && height > 0 && height !== this.footerHeight) { this.footerHeight = height; }
        })
    }.id('gameplay-combination-dialog').width(this.panelWidth).constraintSize({ maxHeight: this.maxHeight })
      .backgroundColor($r('app.color.combination_surface'))
      .border({ width: 1, color: $r('app.color.combination_border') })
  }
}
