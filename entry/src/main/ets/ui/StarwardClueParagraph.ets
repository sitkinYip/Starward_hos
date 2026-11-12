import { ClueSpan, ClueTextPart } from '../business/GameplayClues';
import { externalClueLinkHref } from '../platform/ExternalClueLink';

/** Preserve normal text wrapping and tap only the linked text run. */
@ComponentV2
export struct StarwardClueParagraph {
  @Require @Param part: ClueTextPart;
  @Require @Param paragraphId: string;
  @Require @Param color: ResourceColor;
  @Event openLink: (href: string) => void = () => {};

  build() {
    Text() {
      ForEach(this.part.spans, (span: ClueSpan) => {
        if (span.highlight) {
          Span(span.text).fontColor($r('app.color.clue_mark_text'))
            .textBackgroundStyle({ color: $r('app.color.clue_mark_surface') })
        } else if (span.linkTarget.length > 0 && externalClueLinkHref(span.linkTarget).length > 0) {
          Span(span.text).fontColor($r('app.color.accent_text'))
            .decoration({ type: TextDecorationType.Underline, color: $r('app.color.accent_text') })
            .accessibilityText(span.text)
            .onClick(() => this.openLink(span.linkTarget))
        } else {
          Span(span.text)
        }
      }, (_span: ClueSpan, index: number) => index.toString())
    }.id(this.paragraphId).width('100%').fontSize(16).lineHeight('30.4fp')
      .fontColor(this.color).wordBreak(WordBreak.BREAK_WORD)
  }
}
