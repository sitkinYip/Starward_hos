import { curves, UIUtils } from '@kit.ArkUI';
import { ClueSpan, clueTextParts, clueTitle } from '../business/GameplayClues';
import { GameplayClue } from '../business/GameplayModels';

/** Mobile archive below the completed answer. */
@ComponentV2
export struct StarwardClueArchive {
  @Require @Param clues: GameplayClue[];
  @Param displayFont: string = 'serif';
  @Param motionEnabled: boolean = false;
  @Param reducedMotion: boolean = true;
  @Event opened: (id: string) => void = () => {};
  @Local private revealed: boolean = true;
  @Local private ringAngle: number = 0;
  @Local private cornerTurned: boolean = false;
  @Local private headingWidth: number = 0;
  @Local private inView: boolean = false;
  private mounted: boolean = false;

  aboutToAppear(): void { this.revealed = !this.motionEnabled; }
  aboutToDisappear(): void { this.mounted = false; }

  @Monitor('motionEnabled', 'inView')
  private animateOrbits(): void {
    if (!this.mounted) { return; }
    const enabled: boolean = this.motionEnabled && this.inView;
    const ui = this.getUIContext();
    const orbit = curves.cubicBezierCurve(0.45, 0.02, 0.55, 0.98);
    ui.animateTo({ duration: enabled ? 8000 : 0, iterations: enabled ? -1 : 1, curve: orbit },
      () => UIUtils.applySync(() => { this.ringAngle = enabled ? 360 : 0; }));
    ui.animateTo({ duration: enabled ? 24000 : 0, iterations: enabled ? -1 : 1, curve: orbit },
      () => UIUtils.applySync(() => { this.cornerTurned = enabled; }));
  }

  private revealAnimation(duration: number, delay: number): AnimateParam {
    return { duration: this.motionEnabled ? duration : 0, delay: this.motionEnabled ? delay : 0,
      curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) };
  }

  private number(value: number): string { return value < 10 ? `0${value}` : value.toString(); }

  private preview(clue: GameplayClue): ClueSpan[] {
    if (clue.content.text.length === 0) { return [new ClueSpan('点击查看已解锁内容')]; }
    return clueTextParts(clue.content.text, true)[0]?.spans || [];
  }

  private atmosphereDiameter(): number { return Math.min(360, this.headingWidth * 0.82); }

  @Builder
  atmosphere() {
    Stack() {
      Circle().width('100%').height('100%').fill(Color.Transparent).stroke('#47CAAB5B').strokeWidth(1)
      Circle().width('74%').height('74%').fill(Color.Transparent).stroke('#47CAAB5B').strokeWidth(1)
        .strokeDashArray([3, 3])
      Circle().width('36%').height('36%').fill(Color.Transparent).stroke('#47CAAB5B').strokeWidth(1)
      Circle().width('54%').height('54%').fill(Color.Transparent).stroke('#47CAAB5B').strokeWidth(1)
        .strokeDashArray([1, 2])
      Column() {}.width('92%').height('6%').border({ width: 1, color: '#47CAAB5B' })
      Column() {}.width('6%').height('92%').border({ width: 1, color: '#47CAAB5B' })
    }.id('gameplay-clue-archive-orbit').width(this.atmosphereDiameter()).height(this.atmosphereDiameter())
      .position({ x: this.headingWidth + 90 - this.atmosphereDiameter(), y: -70 })
      .rotate({ angle: this.cornerTurned ? 351 : -9 })
      .scale({ x: this.cornerTurned ? 1.06 : 1, y: this.cornerTurned ? 0.52 : 0.48 }).opacity(0.36)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
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
          Circle().id(`gameplay-clue-action-ring-${index}`).width(24).height(24)
            .fill(Color.Transparent).stroke($r('app.color.accent_soft'))
            .strokeWidth(1).strokeDashArray([2, 2]).rotate({ angle: this.ringAngle })
          Image(clue.kind === 'link' ? $r('app.media.icon_arrow_up_right') : $r('app.media.icon_arrow_right'))
            .width(18).height(18).fillColor($r('app.color.accent_text'))
        }.width(34).height(34).borderRadius(17).backgroundColor($r('app.color.accent_faint'))
          .border({ width: 1, color: $r('app.color.accent_border') }).margin({ left: 4 })
          .accessibilityLevel('no-hide-descendants')
      }.width('100%').padding({ top: 14, right: 12, bottom: 15, left: 8 })
        .opacity(this.revealed ? 1 : 0).translate({ x: this.revealed ? 0 : -30, y: this.revealed ? 0 : 18 })
        .scale({ x: this.revealed ? 1 : 0.97, y: this.revealed ? 1 : 0.97, centerX: 0 })
        .animation(this.revealAnimation(700, Math.min(280, index * 70)))
    }.id(`gameplay-clue-${index}`).width('100%').padding(0).borderRadius(0).clip(true)
      .backgroundColor($r('app.color.inset')).border({ width: 1, color: $r('app.color.border_strong') })
      .radialGradient(clue.kind === 'link' ? { center: ['0%', '50%'], radius: '34%',
        colors: [[$r('app.color.accent_faint'), 0], [Color.Transparent, 1]] } : undefined)
      .clickEffect(clue.kind === 'link' && !this.reducedMotion ? { level: ClickEffectLevel.LIGHT, scale: 0.99 } : null)
      .accessibilityText(clueTitle(clue)).onClick(() => this.opened(clue.id))
  }

  build() {
    Column() {
      Row().width('100%').height(1).linearGradient({ angle: 90,
        colors: [[Color.Transparent, 0], [$r('app.color.accent_border'), 0.22],
          [$r('app.color.accent_soft'), 0.72], [Color.Transparent, 1]] }).accessibilityLevel('no')
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.headingWidth > 0) {
          Stack({ alignContent: Alignment.TopStart }) {
            this.atmosphere()
          }.width(0).height(0).clip(false).position({ x: 0, y: 0 })
            .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
        }
        Row({ space: 24 }) {
          Column({ space: 8 }) {
            Text('UNLOCKED ARCHIVE').fontFamily('monospace').fontSize(11).lineHeight('13.2fp')
              .fontWeight(600).letterSpacing('1.76fp').fontColor($r('app.color.accent_muted'))
            Text('通关线索').fontFamily(this.displayFont).fontSize(27).fontWeight(FontWeight.Medium)
              .lineHeight('32.4fp').fontColor($r('app.color.strong'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            .opacity(this.revealed ? 1 : 0).translate({ y: this.revealed ? 0 : 20 })
            .animation(this.revealAnimation(720, 0))
          Column({ space: 8 }) {
            Text(this.number(this.clues.length)).fontFamily('monospace').fontSize(26).lineHeight('23.4fp')
              .fontWeight(FontWeight.Medium).letterSpacing('-2.08fp').fontColor($r('app.color.accent_text'))
            Text('件已解锁').fontFamily('monospace').fontSize(9).lineHeight('10.8fp')
              .letterSpacing('1.08fp').fontColor($r('app.color.subtle'))
          }.constraintSize({ minWidth: 66 }).alignItems(HorizontalAlign.End).padding({ bottom: 4 })
            .accessibilityText(`已解锁 ${this.clues.length} 件线索`)
            .opacity(this.revealed ? 1 : 0).translate({ y: this.revealed ? 0 : 20 })
            .animation(this.revealAnimation(720, 90))
        }.width('100%')
      }.id('gameplay-clue-archive-heading').width('100%').margin({ top: 28, bottom: 20 })
        .hitTestBehavior(HitTestMode.None)
        .onAreaChange((_previous: Area, current: Area) => {
          const width: number = Number(current.width);
          if (Number.isFinite(width) && width > 0 && width !== this.headingWidth) { this.headingWidth = width; }
        })
      Column({ space: 11 }) {
        ForEach(this.clues, (clue: GameplayClue, index: number) => {
          this.card(clue, index)
        }, (clue: GameplayClue, index: number) => `${index}:${JSON.stringify(clue)}`)
      }.width('100%')
    }.id('gameplay-clues-panel').width('100%').margin({ top: 34 }).padding({ bottom: 12 })
      .onAppear(() => {
        this.mounted = true;
        UIUtils.applySync(() => { this.revealed = true; });
        this.animateOrbits();
      })
      .onVisibleAreaChange([0], (_expanding: boolean, ratio: number) => { this.inView = ratio > 0; })
  }
}
