import { ClueSpan, clueTextParts, clueTitle, isNarrativeClue } from '../business/GameplayClues';
import { GameplayClue } from '../business/GameplayModels';
import { starwardPageReveal } from './StarwardMotion';
import { narrativeAttentionLabel } from './StarwardNarrativeAttention';
import { STARWARD_RADIUS_CONTROL, STARWARD_RADIUS_ROUND } from './StarwardRadii';

function clueIcon(kind: string): Resource {
  switch (kind) {
    case 'image': return $r('app.media.icon_clue_image');
    case 'video': return $r('app.media.icon_clue_video');
    case 'link': return $r('app.media.icon_clue_link');
    case 'letter': return $r('app.media.icon_clue_letter');
    case 'bless': return $r('app.media.icon_clue_bless');
    default: return $r('app.media.icon_clue_text');
  }
}

/** Granted clues travel with their question card during native paging. */
@ComponentV2
export struct StarwardClueArchive {
  @Require @Param clues: GameplayClue[];
  @Param active: boolean = true;
  @Param reducedMotion: boolean = true;
  @Param openedNarrativeIds: string[] = [];
  @Event opened: (id: string) => void = () => {};

  private isPending(clue: GameplayClue): boolean {
    return isNarrativeClue(clue) && !this.openedNarrativeIds.includes(clue.id);
  }

  private preview(clue: GameplayClue): ClueSpan[] {
    return clueTextParts(clue.content.text, true)[0]?.spans ?? [];
  }

  private cardFill(clue: GameplayClue): ResourceColor {
    if (this.isPending(clue)) { return $r('app.color.accent_soft'); }
    return clue.kind === 'letter' || clue.kind === 'bless' ?
      $r('app.color.accent_faint') : $r('app.color.input');
  }

  @Builder
  private card(clue: GameplayClue, index: number) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Stack() {
          Image(clueIcon(clue.kind)).width(20).height(20).fillColor(this.isPending(clue) ?
            $r('app.color.on_accent') : $r('app.color.accent_text'))
        }.width(38).height(38).borderRadius(STARWARD_RADIUS_ROUND).backgroundColor(this.isPending(clue) ?
          $r('app.color.accent') : $r('app.color.accent_soft')).accessibilityLevel('no-hide-descendants')

        Column({ space: 3 }) {
          if (this.isPending(clue)) {
            Text(narrativeAttentionLabel(clue.kind)).id(this.active ? `gameplay-narrative-status-${clue.id}` : '')
              .width('100%').fontSize(11).fontWeight(600).fontColor($r('app.color.accent_text'))
          }
          Text(clueTitle(clue)).id(this.active ? `gameplay-clue-title-${index}` : '').width('100%')
            .fontSize(15).lineHeight('20.25fp').fontWeight(600).fontColor($r('app.color.strong'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
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
            }.width('100%').fontSize(13).lineHeight('19.5fp').fontColor($r('app.color.muted'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)

        Stack() {
          Image(clue.kind === 'link' ? $r('app.media.icon_arrow_up_right') : $r('app.media.icon_arrow_right'))
            .width(16).height(16).fillColor(this.isPending(clue) ? $r('app.color.on_accent') :
              $r('app.color.accent_text'))
        }.width(32).height(32).borderRadius(STARWARD_RADIUS_ROUND).backgroundColor(this.isPending(clue) ?
          $r('app.color.accent') : $r('app.color.accent_faint')).accessibilityLevel('no-hide-descendants')
      }.width('100%').padding({ top: 12, right: 14, bottom: 12, left: 14 })
    }.id(this.active ? `gameplay-clue-${isNarrativeClue(clue) ? clue.id : index}` : '').focusable(this.active)
      .width('100%').padding(0).backgroundColor(this.cardFill(clue))
      .border({ width: 1, radius: STARWARD_RADIUS_CONTROL, color: this.isPending(clue) ? $r('app.color.accent') :
        clue.kind === 'letter' || clue.kind === 'bless' ? $r('app.color.accent_border') :
          $r('app.color.border_strong') }).clip(true)
      .clickEffect(this.reducedMotion ? null : { level: ClickEffectLevel.LIGHT, scale: 0.99 })
      .accessibilityText(this.isPending(clue) ?
        `${clueTitle(clue)}，${narrativeAttentionLabel(clue.kind)}` : clueTitle(clue))
      .onClick(() => { if (this.active) { this.opened(clue.id); } })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('通关线索').layoutWeight(1).fontSize(13).fontWeight(600).fontColor($r('app.color.muted'))
        Text(this.clues.length.toString()).constraintSize({ minWidth: 24, minHeight: 24 })
          .padding({ left: 8, right: 8 }).borderRadius(STARWARD_RADIUS_ROUND).textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.accent_soft')).fontColor($r('app.color.accent_text'))
          .fontSize(12).fontWeight(600).fontFeature("'tnum' 1").accessibilityText(`已解锁 ${this.clues.length} 件线索`)
      }.id(this.active ? 'gameplay-clue-archive-heading' : '').width('100%').margin({ bottom: 12 })
      Column({ space: 10 }) {
        ForEach(this.clues, (clue: GameplayClue, index: number) => {
          this.card(clue, index)
        }, (clue: GameplayClue) => JSON.stringify(clue))
      }.width('100%')
    }.id(this.active ? 'gameplay-clues-panel' : '').width('100%').margin({ top: 24 }).padding({ top: 18 })
      .border({ width: { top: 1 }, color: $r('app.color.border') })
      .transition(starwardPageReveal(this.reducedMotion || !this.active, 4))
  }
}
