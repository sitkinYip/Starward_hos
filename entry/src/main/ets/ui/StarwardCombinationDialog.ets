import { UIUtils } from '@kit.ArkUI';
import { GameplayClue } from '../business/GameplayModels';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { StarwardRichContent } from './StarwardRichContent';
import { StarwardVideoViewerState } from './StarwardVideoViewer';
import { clueRevealAnimation, StarwardClueDialogDecoration } from './StarwardClueMotion';

/** Only the reading viewport shrinks when the dialog reaches its height limit. */
@ComponentV2
export struct StarwardCombinationDialog {
  @Require @Param clue: GameplayClue;
  @Require @Param ownerKey: string;
  @Require @Param ownerIsCurrent: (key: string) => boolean;
  @Require @Param imageCache: QuestionImageCache;
  @Require @Param inlineVideo: StarwardVideoViewerState;
  @Param inlineVideoSlot: string = '';
  @Require @Param panelWidth: number;
  @Require @Param maxHeight: number;
  @Param reducedMotion: boolean = true;
  @Param motionEnabled: boolean = false;
  @Event acknowledge: () => void = () => {};
  @Event openImage: (partIndex: number) => void = () => {};
  @Event openVideo: (partIndex: number) => void = () => {};
  @Event playVideo: (partIndex: number) => void = () => {};
  @Event openLink: (href: string) => void = () => {};
  @Local private panelHeight: number = 0;
  @Local private revealed: boolean = true;

  aboutToAppear(): void { this.revealed = !this.motionEnabled; }

  private compact(): boolean { return this.panelWidth + 40 <= 620; }
  private bodyPadding(): number { return Math.max(24, Math.min(44, (this.panelWidth + 40) * 0.05)); }
  private footerPadding(): number { return Math.max(20, Math.min(44, (this.panelWidth + 40) * 0.05)); }

  @Builder
  description() {
    Text(this.clue.content.description || '该本场线索会保留在当前会话中。')
      .id('gameplay-combination-description').fontSize(13).lineHeight('19.5fp')
      .fontColor($r('app.color.muted')).wordBreak(WordBreak.BREAK_WORD)
  }

  @Builder
  ackButton(full: boolean) {
    Button(this.clue.content.buttonText || '我知道了', { type: ButtonType.Capsule })
      .id('gameplay-combination-ack').constraintSize({ minHeight: 46, maxWidth: this.panelWidth - this.footerPadding() * 2 })
      .width(full ? '100%' : undefined).padding({ left: 24, right: 24, top: 8, bottom: 8 })
      .fontSize(16).fontWeight(600).fontColor($r('app.color.on_accent'))
      .backgroundColor($r('app.color.accent')).onClick(() => this.acknowledge())
  }

  @Builder
  readingPanel() {
    Flex({ direction: FlexDirection.Column }) {
      Scroll() {
        Column() {
          Text(this.clue.content.title || '隐藏的本场线索').id('gameplay-combination-title')
            .fontSize(Math.max(24, Math.min(34, (this.panelWidth + 40) * 0.05)))
            .fontWeight(FontWeight.Bold).fontColor($r('app.color.strong'))
            .opacity(this.revealed ? 1 : 0).translate({ y: this.revealed ? 0 : 28 })
            .scale({ x: this.revealed ? 1 : 0.98, y: this.revealed ? 1 : 0.98 })
            .animation(clueRevealAnimation(this.motionEnabled, 70))
          Column() {
            StarwardRichContent({ content: this.clue.content.text, nodeId: 'gameplay-combination',
              ownerKey: this.ownerKey, ownerIsCurrent: this.ownerIsCurrent, imageCache: this.imageCache,
              inlineVideo: this.inlineVideo, inlineVideoSlot: this.inlineVideoSlot,
              color: $r('app.color.text'), clueBody: true, textSize: 15, lineHeight: '27.75fp',
              maxMediaHeight: Math.min(640, (this.maxHeight + 40) * 0.58),
              mediaMargin: 16, reducedMotion: this.reducedMotion,
              openImage: (index: number) => this.openImage(index),
              openVideo: (index: number) => this.openVideo(index), playVideo: (index: number) => this.playVideo(index),
              openLink: (href: string) => this.openLink(href) })
          }.id('gameplay-combination-content').width('100%').alignItems(HorizontalAlign.Start).margin({ top: 18 })
            .opacity(this.revealed ? 1 : 0).translate({ y: this.revealed ? 0 : 28 })
            .scale({ x: this.revealed ? 1 : 0.98, y: this.revealed ? 1 : 0.98 })
            .animation(clueRevealAnimation(this.motionEnabled, 130))
        }.width('100%').alignItems(HorizontalAlign.Start)
          .padding(this.bodyPadding())
      }.id('gameplay-combination-scroll').width('100%').flexShrink(1)
        .constraintSize({ maxHeight: this.maxHeight })
        .align(Alignment.Top).scrollBar(BarState.Off)
      Column() {
        if (this.compact()) {
          Column({ space: 16 }) {
            this.description()
            this.ackButton(true)
          }.width('100%').alignItems(HorizontalAlign.Start)
        } else {
          Row({ space: 16 }) {
            Column() {
              this.description()
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            this.ackButton(false)
          }.width('100%').alignItems(VerticalAlign.Center)
        }
      }.id('gameplay-combination-footer').width('100%').flexShrink(0)
        .padding({ left: this.footerPadding(), right: this.footerPadding(), top: 16, bottom: 16 })
        .backgroundColor($r('app.color.glass_floating'))
        .border({ width: { top: 1 }, color: $r('app.color.border') })
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
      .backgroundColor($r('app.color.raised'))
      .border({ width: 1, radius: 24, color: $r('app.color.border_strong') }).borderRadius(24).clip(true)
      .onAppear(() => UIUtils.applySync(() => { this.revealed = true; }))
      .onAreaChange((_previous: Area, current: Area) => {
        const height: number = Number(current.height);
        if (Number.isFinite(height) && height > 0 && height !== this.panelHeight) { this.panelHeight = height; }
      })
  }
}
