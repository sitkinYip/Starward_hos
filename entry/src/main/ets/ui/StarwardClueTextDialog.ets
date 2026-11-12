import { ClueTextPart, clueTextParts, clueTitle } from '../business/GameplayClues';
import { GameplayClue } from '../business/GameplayModels';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { StarwardClueParagraph } from './StarwardClueParagraph';
import { StarwardQuestionImages } from './StarwardQuestionImages';

/** The reading surface within ArkUI's centered native dialog. */
@ComponentV2
export struct StarwardClueTextDialog {
  @Require @Param clue: GameplayClue;
  @Require @Param ownerKey: string;
  @Require @Param ownerIsCurrent: (key: string) => boolean;
  @Require @Param imageCache: QuestionImageCache;
  @Require @Param panelWidth: number;
  @Require @Param maxHeight: number;
  @Param displayFont: string = 'serif';
  @Param reducedMotion: boolean = true;
  @Event close: () => void = () => {};
  @Event openImage: (partIndex: number) => void = () => {};
  @Event openLink: (href: string) => void = () => {};

  private bodyPadding(): number { return Math.max(28, Math.min(58, (this.panelWidth + 48) * 0.06)); }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Scroll() {
        Column() {
          Text('DECODED FRAGMENT').fontFamily('monospace').fontSize(11).lineHeight('13.2fp')
            .fontWeight(600).letterSpacing('1.76fp').fontColor($r('app.color.accent_muted'))
            .margin({ right: 32, bottom: 14 })
          Text(clueTitle(this.clue)).id('gameplay-clue-text-title').fontFamily(this.displayFont)
            .fontSize(Math.max(27, Math.min(40, (this.panelWidth + 48) * 0.05)))
            .fontWeight(FontWeight.Medium).fontColor($r('app.color.strong'))
          Row().width('38%').height(1).constraintSize({ maxWidth: 180 })
            .linearGradient({ angle: 90, colors: [[$r('app.color.accent_border'), 0],
              [$r('app.color.accent_soft'), 0.64], [Color.Transparent, 1]] })
            .margin({ top: 20 }).accessibilityLevel('no')
          Column() {
            ForEach(clueTextParts(this.clue.content.text), (part: ClueTextPart, index: number) => {
              if (part.image.length > 0) {
                StarwardQuestionImages({ sources: [part.image], ownerKey: this.ownerKey, imageCache: this.imageCache,
                  ownerIsCurrent: this.ownerIsCurrent, groupId: `gameplay-clue-inline-${index}`,
                  imageLabel: '线索图片', maxHeight: Math.min(680, this.maxHeight * 0.6),
                  reducedMotion: this.reducedMotion, opened: () => this.openImage(index) })
                  .margin({ top: 18, bottom: 18 })
              } else {
                StarwardClueParagraph({ part: part, paragraphId: `gameplay-clue-paragraph-${index}`,
                  color: $r('app.color.text'), openLink: (href: string) => this.openLink(href) })
              }
            }, (_part: ClueTextPart, index: number) => index.toString())
          }.id('gameplay-clue-text-content').width('100%').alignItems(HorizontalAlign.Start).margin({ top: 24 })
        }.width('100%').alignItems(HorizontalAlign.Start).padding(this.bodyPadding())
      }.width('100%').constraintSize({ maxHeight: this.maxHeight }).align(Alignment.Top).scrollBar(BarState.Off)
      Button('×', { type: ButtonType.Circle }).id('gameplay-clue-text-close').width(44).height(44).padding(0)
        .fontSize(26).fontColor($r('app.color.strong')).backgroundColor($r('app.color.inset'))
        .border({ width: 1, color: $r('app.color.border_strong') }).margin({ top: 16, right: 16 })
        .accessibilityText('关闭线索').onClick(() => this.close())
    }.id('gameplay-clue-text-dialog').width(this.panelWidth).constraintSize({ maxHeight: this.maxHeight })
      .backgroundColor($r('app.color.raised')).border({ width: 1, color: $r('app.color.border_strong') })
  }
}
