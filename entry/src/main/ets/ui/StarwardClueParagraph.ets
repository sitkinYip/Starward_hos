import { isLegacyInternalLink, LegacyRichSpan } from '../business/LegacyRichContent';
import { externalClueLinkHref } from '../platform/ExternalClueLink';

/** Preserve normal text wrapping and tap only the linked text run. */
@ComponentV2
export struct StarwardClueParagraph {
  @Require @Param spans: LegacyRichSpan[];
  @Require @Param paragraphId: string;
  @Require @Param color: ResourceColor;
  @Param lineHeight: string = '30.4fp';
  @Param active: boolean = true;
  @Param allowInternal: boolean = false;
  @Event openLink: (href: string) => void = () => {};

  build() {
    Text() {
      ForEach(this.spans, (span: LegacyRichSpan) => {
        if (span.highlight) {
          Span(span.text).fontColor($r('app.color.clue_mark_text'))
            .textBackgroundStyle({ color: $r('app.color.clue_mark_surface') })
        } else if ((this.allowInternal && isLegacyInternalLink(span.linkTarget)) ||
          externalClueLinkHref(span.linkTarget).length > 0) {
          Span(span.text).fontColor($r('app.color.accent_text'))
            .decoration({ type: TextDecorationType.Underline, color: $r('app.color.accent_text') })
            .accessibilityText(span.text)
            .onClick(() => { if (this.active) { this.openLink(span.linkTarget); } })
        } else {
          Span(span.text)
        }
      }, (span: LegacyRichSpan, index: number) => `${index}:${span.text}:${span.highlight}:${span.linkTarget}`)
    }.id(this.paragraphId).width('100%').fontSize(16).lineHeight(this.lineHeight)
      .fontColor(this.color).wordBreak(WordBreak.BREAK_WORD)
  }
}
