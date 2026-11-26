import { LegacyRichBlock, legacyRichBlocks } from '../business/LegacyRichContent';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { StarwardClueParagraph } from './StarwardClueParagraph';
import { StarwardQuestionImages } from './StarwardQuestionImages';
import { StarwardVideoPoster } from './StarwardVideoPoster';
import { StarwardInlineVideo, StarwardVideoViewerState } from './StarwardVideoViewer';
import { STARWARD_RADIUS_CONTROL, STARWARD_RADIUS_ROUND } from './StarwardRadii';

/** Inline text runs and ordered media share the containers already used by the quest. */
@ComponentV2
export struct StarwardRichContent {
  @Require @Param content: string;
  @Require @Param nodeId: string;
  @Require @Param ownerKey: string;
  @Require @Param ownerIsCurrent: (key: string) => boolean;
  @Require @Param imageCache: QuestionImageCache;
  @Require @Param color: ResourceColor;
  @Require @Param inlineVideo: StarwardVideoViewerState;
  @Param inlineVideoSlot: string = '';
  @Param active: boolean = true;
  @Param interactive: boolean = true;
  @Param showMedia: boolean = true;
  @Param reserveImageSpace: boolean = false;
  @Param clueBody: boolean = false;
  @Param textSize: number = 16;
  @Param textWeight: number = 400;
  @Param lineHeight: string = '30.4fp';
  @Param imageLabel: string = '';
  @Param videoPlayLabel: string = '';
  @Param availableWidth: number = 0;
  @Param maxMediaHeight: number = 420;
  @Param mediaMargin: number = 0;
  @Param reducedMotion: boolean = true;
  @Event openImage: (partIndex: number) => void = () => {};
  @Event openVideo: (partIndex: number) => void = () => {};
  @Event playVideo: (partIndex: number) => void = () => {};
  @Event openLink: (href: string) => void = () => {};
  @Local private posterHeights: Map<number, number> = new Map();

  @Computed
  get blocks(): LegacyRichBlock[] {
    return legacyRichBlocks(this.content, this.clueBody ? 'clueBody' : 'content');
  }

  private paragraphId(index: number): string {
    return this.clueBody ? `${this.nodeId}-paragraph-${index}` :
      index === 0 ? this.nodeId : `${this.nodeId}-part-${index}`;
  }

  private playingAt(index: number): boolean {
    return this.active && this.inlineVideo.visible && this.inlineVideoSlot === `${this.nodeId}-video-${index}`;
  }

  @Builder
  video(block: LegacyRichBlock, index: number) {
    Column() {
      Stack() {
        StarwardVideoPoster({ source: block.poster, ownerKey: this.ownerKey, ownerIsCurrent: this.ownerIsCurrent,
          imageCache: this.imageCache, active: this.active, nodeId: `${this.nodeId}-video-${index}-inline`,
          playLabel: this.videoPlayLabel || (this.clueBody ? '播放线索视频' : '播放题目视频'),
          maxHeight: this.maxMediaHeight, playable: this.active && this.interactive && !this.playingAt(index),
          play: () => this.playVideo(index) })
          .opacity(this.playingAt(index) ? 0 : 1)
          .accessibilityLevel(this.playingAt(index) ? 'no-hide-descendants' : 'auto')
          .onAreaChange((_previous: Area, current: Area) => {
            const height: number = Number(current.height);
            if (Number.isFinite(height) && height > 0 && height !== this.posterHeights.get(index)) {
              this.posterHeights.set(index, height);
            }
          })
        if (this.playingAt(index)) {
          Column() {
            StarwardInlineVideo({ model: this.inlineVideo, sessionId: this.inlineVideo.sessionId,
              nodeId: `${this.nodeId}-video-${index}-inline`, reducedMotion: this.reducedMotion })
          }.width('100%').height(this.posterHeights.get(index) ?? 182).position({ x: 0, y: 0 })
        }
      }.width('100%').borderRadius(STARWARD_RADIUS_CONTROL).clip(true)
      Button('展开视频', { type: ButtonType.Normal }).id(`${this.nodeId}-video-${index}-open`)
        .constraintSize({ minHeight: 44 }).padding({ left: 14, right: 14 })
        .fontSize(13).fontColor($r('app.color.accent_text')).backgroundColor(Color.Transparent)
        .border({ width: 1, color: $r('app.color.border_strong'), radius: STARWARD_RADIUS_ROUND })
        .enabled(this.active && this.interactive).onClick(() => {
          if (this.active && this.interactive && this.ownerIsCurrent(this.ownerKey)) { this.openVideo(index); }
        })
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: this.mediaMargin, bottom: this.mediaMargin })
  }

  build() {
    Column() {
      ForEach(this.blocks, (block: LegacyRichBlock, index: number) => {
        if (block.kind === 'text') {
          if (block.spans.length === 1 && !block.spans[0].highlight && block.spans[0].linkTarget.length === 0) {
            Text(block.spans[0].text).id(this.paragraphId(index)).width('100%')
              .fontSize(this.textSize).fontWeight(this.textWeight).lineHeight(this.lineHeight).fontColor(this.color)
          } else {
            StarwardClueParagraph({ spans: block.spans, paragraphId: this.paragraphId(index), color: this.color,
              textSize: this.clueBody ? 16 : this.textSize, textWeight: this.textWeight, lineHeight: this.lineHeight,
              active: this.active && this.interactive, allowInternal: !this.clueBody,
              openLink: (href: string) => this.openLink(href) })
          }
        } else if (this.showMedia && block.kind === 'image') {
          StarwardQuestionImages({ sources: [block.url], ownerKey: this.ownerKey, imageCache: this.imageCache,
            ownerIsCurrent: this.ownerIsCurrent, active: this.active, availableWidth: this.availableWidth,
            groupId: `${this.nodeId}-${this.clueBody ? 'inline' : 'image'}-${index}`,
            imageLabel: this.imageLabel || (this.clueBody ? '线索图片' : '题目图片'), maxHeight: this.maxMediaHeight,
            reducedMotion: this.reducedMotion, reserveLoadingSpace: this.reserveImageSpace,
            opened: () => { if (this.active && this.interactive) { this.openImage(index); } } })
            .margin({ top: this.mediaMargin, bottom: this.mediaMargin })
        } else if (this.showMedia && block.kind === 'video') {
          this.video(block, index)
        }
      }, (block: LegacyRichBlock, index: number) => `${index}:${JSON.stringify(block)}`)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
