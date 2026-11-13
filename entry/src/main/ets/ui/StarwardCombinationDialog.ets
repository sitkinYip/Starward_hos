import { UIUtils } from '@kit.ArkUI';
import { ClueTextPart, clueTextParts } from '../business/GameplayClues';
import { GameplayClue } from '../business/GameplayModels';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { StarwardClueParagraph } from './StarwardClueParagraph';
import { clueRevealAnimation, StarwardClueDialogDecoration } from './StarwardClueMotion';
import { StarwardQuestionImages } from './StarwardQuestionImages';

/** Only the reading viewport shrinks when the dialog reaches its height limit. */
@ComponentV2
export struct StarwardCombinationDialog {
  @Require @Param clue: GameplayClue;
  @Require @Param ownerKey: string;
  @Require @Param ownerIsCurrent: (key: string) => boolean;
  @Require @Param imageCache: QuestionImageCache;
  @Require @Param panelWidth: number;
  @Require @Param maxHeight: number;
  @Param displayFont: string = 'serif';
  @Param reducedMotion: boolean = true;
  @Param motionEnabled: boolean = false;
  @Event acknowledge: () => void = () => {};
  @Event openImage: (partIndex: number) => void = () => {};
  @Event openLink: (href: string) => void = () => {};
  @Local private panelHeight: number = 0;
  @Local private revealed: boolean = true;

  aboutToAppear(): void { this.revealed = !this.motionEnabled; }

  private compact(): boolean { return this.panelWidth + 48 <= 620; }
  private bodyPadding(): number { return Math.max(30, Math.min(62, (this.panelWidth + 48) * 0.06)); }
  private footerPadding(): number { return Math.max(20, Math.min(62, (this.panelWidth + 48) * 0.06)); }

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

  @Builder
  readingPanel() {
    Flex({ direction: FlexDirection.Column }) {
      Scroll() {
        Column() {
          Text('COMBINED REVELATION').fontFamily('monospace').fontSize(11).lineHeight('13.2fp')
            .fontWeight(600).letterSpacing('1.76fp').fontColor($r('app.color.accent_muted'))
            .opacity(this.revealed ? 1 : 0).translate({ y: this.revealed ? 0 : 28 })
            .scale({ x: this.revealed ? 1 : 0.98, y: this.revealed ? 1 : 0.98 })
            .animation(clueRevealAnimation(this.motionEnabled, 0))
          Text(this.clue.content.title || '隐藏的本场线索').id('gameplay-combination-title')
            .fontFamily(this.displayFont).fontSize(Math.max(30, Math.min(50, (this.panelWidth + 48) * 0.06)))
            .fontWeight(FontWeight.Medium).fontColor($r('app.color.combination_title')).margin({ top: 14 })
            .opacity(this.revealed ? 1 : 0).translate({ y: this.revealed ? 0 : 28 })
            .scale({ x: this.revealed ? 1 : 0.98, y: this.revealed ? 1 : 0.98 })
            .animation(clueRevealAnimation(this.motionEnabled, 70))
          Column() {
            ForEach(clueTextParts(this.clue.content.text), (part: ClueTextPart, index: number) => {
              if (part.image.length > 0) {
                StarwardQuestionImages({ sources: [part.image], ownerKey: this.ownerKey, imageCache: this.imageCache,
                  ownerIsCurrent: this.ownerIsCurrent, groupId: `gameplay-combination-inline-${index}`,
                  imageLabel: '线索图片', maxHeight: Math.min(660, (this.maxHeight + 48) * 0.58),
                  reducedMotion: this.reducedMotion, opened: () => this.openImage(index) })
                  .margin({ top: 20, bottom: 20 })
              } else {
                StarwardClueParagraph({ part: part, paragraphId: `gameplay-combination-paragraph-${index}`,
                  color: $r('app.color.combination_body'), openLink: (href: string) => this.openLink(href) })
              }
            }, (_part: ClueTextPart, index: number) => index.toString())
          }.id('gameplay-combination-content').width('100%').alignItems(HorizontalAlign.Start).margin({ top: 28 })
            .opacity(this.revealed ? 1 : 0).translate({ y: this.revealed ? 0 : 28 })
            .scale({ x: this.revealed ? 1 : 0.98, y: this.revealed ? 1 : 0.98 })
            .animation(clueRevealAnimation(this.motionEnabled, 130))
        }.width('100%').alignItems(HorizontalAlign.Start)
          .padding({ top: this.bodyPadding() + 16, right: this.bodyPadding(), bottom: 30, left: this.bodyPadding() })
      }.id('gameplay-combination-scroll').width('100%').flexShrink(1)
        .constraintSize({ maxHeight: this.maxHeight })
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
      }.id('gameplay-combination-footer').width('100%').flexShrink(0)
        .padding({ left: this.footerPadding(), right: this.footerPadding(), top: 18, bottom: 18 })
        .backgroundColor($r('app.color.combination_footer'))
        .border({ width: { top: 1 }, color: $r('app.color.combination_footer_border') })
    }.width('100%').height('auto').constraintSize({ maxHeight: this.maxHeight })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.panelHeight > 2) {
        StarwardClueDialogDecoration({ panelWidth: this.panelWidth - 2, panelHeight: this.panelHeight - 2,
          combination: true, motionEnabled: this.motionEnabled })
          .position({ x: 0, y: 0 })
      }
      this.readingPanel()
    }.id('gameplay-combination-dialog').width(this.panelWidth)
      .constraintSize({ maxHeight: this.maxHeight })
      .backgroundColor($r('app.color.combination_surface'))
      .border({ width: 1, color: $r('app.color.combination_border') })
      .onAppear(() => UIUtils.applySync(() => { this.revealed = true; }))
      .onAreaChange((_previous: Area, current: Area) => {
        const height: number = Number(current.height);
        if (Number.isFinite(height) && height > 0 && height !== this.panelHeight) { this.panelHeight = height; }
      })
  }
}
