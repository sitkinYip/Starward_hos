import { UIUtils } from '@kit.ArkUI';
import { clueTitle } from '../business/GameplayClues';
import { GameplayClue } from '../business/GameplayModels';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { StarwardRichContent } from './StarwardRichContent';
import { StarwardVideoViewerState } from './StarwardVideoViewer';
import { clueRevealAnimation, StarwardClueDialogDecoration } from './StarwardClueMotion';

/** The reading surface within ArkUI's centered native dialog. */
@ComponentV2
export struct StarwardClueTextDialog {
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
  @Event close: () => void = () => {};
  @Event openImage: (partIndex: number) => void = () => {};
  @Event openVideo: (partIndex: number) => void = () => {};
  @Event playVideo: (partIndex: number) => void = () => {};
  @Event openLink: (href: string) => void = () => {};
  @Local private panelHeight: number = 0;
  @Local private revealed: boolean = true;

  aboutToAppear(): void { this.revealed = !this.motionEnabled; }

  private bodyPadding(): number { return Math.max(24, Math.min(44, (this.panelWidth + 40) * 0.05)); }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.panelHeight > 2) {
        StarwardClueDialogDecoration({ panelWidth: this.panelWidth - 2, panelHeight: this.panelHeight - 2,
          motionEnabled: this.motionEnabled })
          .position({ x: 0, y: 0 })
      }
      Scroll() {
        Column() {
          Text(clueTitle(this.clue)).id('gameplay-clue-text-title')
            .fontSize(Math.max(22, Math.min(30, (this.panelWidth + 40) * 0.045)))
            .fontWeight(FontWeight.Bold).fontColor($r('app.color.strong')).margin({ right: 36 })
            .opacity(this.revealed ? 1 : 0).translate({ y: this.revealed ? 0 : 28 })
            .scale({ x: this.revealed ? 1 : 0.98, y: this.revealed ? 1 : 0.98 })
            .animation(clueRevealAnimation(this.motionEnabled, 70))
          Row().width('38%').height(1).constraintSize({ maxWidth: 180 })
            .linearGradient({ angle: 90, colors: [[$r('app.color.accent_border'), 0],
              [$r('app.color.accent_soft'), 0.64], [Color.Transparent, 1]] })
            .margin({ top: 20 }).accessibilityLevel('no')
            .opacity(this.revealed ? 1 : 0).translate({ y: this.revealed ? 0 : 28 })
            .scale({ x: this.revealed ? 1 : 0.98, y: this.revealed ? 1 : 0.98 })
            .animation(clueRevealAnimation(this.motionEnabled, 130))
          Column() {
            StarwardRichContent({ content: this.clue.content.text, nodeId: 'gameplay-clue',
              ownerKey: this.ownerKey, ownerIsCurrent: this.ownerIsCurrent, imageCache: this.imageCache,
              inlineVideo: this.inlineVideo, inlineVideoSlot: this.inlineVideoSlot,
              color: $r('app.color.text'), clueBody: true, textSize: 15, lineHeight: '27.75fp',
              maxMediaHeight: Math.min(640, (this.maxHeight + 40) * 0.58),
              mediaMargin: 16, reducedMotion: this.reducedMotion,
              openImage: (index: number) => this.openImage(index),
              openVideo: (index: number) => this.openVideo(index), playVideo: (index: number) => this.playVideo(index),
              openLink: (href: string) => this.openLink(href) })
          }.id('gameplay-clue-text-content').width('100%').alignItems(HorizontalAlign.Start).margin({ top: 18 })
            .opacity(this.revealed ? 1 : 0).translate({ y: this.revealed ? 0 : 28 })
            .scale({ x: this.revealed ? 1 : 0.98, y: this.revealed ? 1 : 0.98 })
            .animation(clueRevealAnimation(this.motionEnabled, 190))
        }.width('100%').alignItems(HorizontalAlign.Start).padding(this.bodyPadding())
      }.width('100%').constraintSize({ maxHeight: this.maxHeight }).align(Alignment.Top).scrollBar(BarState.Off)
      Button('×', { type: ButtonType.Circle }).id('gameplay-clue-text-close').width(44).height(44).padding(0)
        .fontSize(22).fontColor($r('app.color.strong')).backgroundColor($r('app.color.inset'))
        .border({ width: 1, color: $r('app.color.border_strong') }).margin({ top: 14, right: 14 })
        .accessibilityText('关闭线索').onClick(() => this.close())
    }.id('gameplay-clue-text-dialog').width(this.panelWidth).constraintSize({ maxHeight: this.maxHeight })
      .backgroundColor($r('app.color.raised')).border({ width: 1, radius: 24,
        color: $r('app.color.border_strong') }).borderRadius(24).clip(true)
      .onAppear(() => UIUtils.applySync(() => { this.revealed = true; }))
      .onAreaChange((_previous: Area, current: Area) => {
        const height: number = Number(current.height);
        if (Number.isFinite(height) && height > 0 && height !== this.panelHeight) { this.panelHeight = height; }
      })
  }
}
