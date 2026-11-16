import { CommonModifier, curves, LengthMetrics, UIUtils } from '@kit.ArkUI';
import { StarLetterEntry } from '../business/StarLetters';
import { ErrorNotice } from '../ui/ErrorMessages';
import { StarwardRefresh } from '../ui/StarwardRefresh';
import { StarLettersReadError, StarLettersViewModel } from './StarLettersViewModel';

const letterDate = new Intl.DateTimeFormat('zh-CN', {
  year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false
});

function formatLetterDate(value: string): string {
  const date: Date = new Date(value);
  return Number.isNaN(date.getTime()) ? '时间待确认' : letterDate.format(date);
}

function letterReveal(motionEnabled: boolean, delay: number = 0): AnimateParam {
  return { duration: motionEnabled ? 640 : 0, delay: motionEnabled ? delay : 0,
    curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) };
}

@ComponentV2
struct StarLetterRow {
  @Require @Param entry: StarLetterEntry;
  @Require @Param displayFont: string;
  @Param motionEnabled: boolean = false;
  @Param revealDelay: number = 0;
  @Event openLetter: (entry: StarLetterEntry) => void = () => {};
  @Local private revealed: boolean = false;

  private isFinale(): boolean {
    return this.entry.title === '旅途终章' && this.entry.sessionTitle.length > 0 &&
      this.entry.description === this.entry.sessionTitle;
  }

  private hasDistinctSummary(): boolean {
    const summary: string = this.entry.description.trim();
    return summary.length > 0 && summary !== this.entry.sessionTitle.trim() && summary !== this.entry.title.trim();
  }

  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Stack() {
          Image($r('app.media.icon_sparkle')).width(21).height(21)
            .objectFit(ImageFit.Contain).fillColor($r('app.color.accent_text')).accessibilityLevel('no')
        }.width(36).height(36).borderRadius(11).backgroundColor($r('app.color.accent_soft'))
        Column({ space: 4 }) {
          Text(this.isFinale() ? this.entry.sessionTitle : this.entry.title)
            .fontFamily(this.displayFont).fontSize(18).fontWeight(FontWeight.Medium).lineHeight('26fp')
            .fontColor($r('app.color.strong')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          if (this.hasDistinctSummary()) {
            Text(this.entry.description).fontSize(13).lineHeight('19.5fp').fontColor($r('app.color.muted'))
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          }
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(3) } }) {
            Text(this.isFinale() ? this.entry.title : this.entry.sessionTitle)
              .fontSize(11).lineHeight('16.5fp').fontColor($r('app.color.muted'))
            Text(formatLetterDate(this.entry.sentAt)).fontSize(11).lineHeight('16.5fp').fontColor($r('app.color.muted'))
          }.width('100%')
        }.layoutWeight(1).constraintSize({ minWidth: 0 }).alignItems(HorizontalAlign.Start)
        Image($r('app.media.icon_arrow_right')).width(16).height(16)
          .objectFit(ImageFit.Contain).fillColor($r('app.color.muted')).accessibilityLevel('no')
      }.width('100%').alignItems(VerticalAlign.Center).padding({ top: 12, bottom: 12, left: 14, right: 14 })
    }.id(`star-letter-${this.entry.id}`).width('100%').constraintSize({ minHeight: 72 }).padding(0)
      .borderRadius(14).borderWidth(1).borderColor($r('app.color.border')).backgroundColor($r('app.color.surface'))
      .opacity(!this.motionEnabled || this.revealed ? 1 : 0)
      .translate({ y: !this.motionEnabled || this.revealed ? 0 : 14 })
      .animation(letterReveal(this.motionEnabled, this.revealDelay))
      .onAppear(() => UIUtils.applySync(() => { this.revealed = true; }))
      .onClick(() => this.openLetter(this.entry))
  }
}

@ComponentV2
struct StarLettersSkeleton {
  @Param animated: boolean = false;
  @Local private pulsed: boolean = false;

  build() {
    Row({ space: 16 }) {
      Column().width(70).height(110).borderRadius(10).backgroundColor($r('app.color.accent_soft'))
      Column({ space: 16 }) {
        Column().width('100%').height(47).borderRadius(10).backgroundColor($r('app.color.accent_soft'))
        Column().width('65%').height(47).borderRadius(10).backgroundColor($r('app.color.accent_soft'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').constraintSize({ minHeight: 160 }).padding(24).alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.surface')).border({ width: 1, color: $r('app.color.border'), radius: 18 })
      .opacity(this.animated ? (this.pulsed ? 0.85 : 0.4) : 1).accessibilityLevel('no-hide-descendants')
      .onAppear(() => {
        if (this.animated) {
          this.getUIContext().animateTo({ duration: 1000, iterations: -1, playMode: PlayMode.Alternate,
            curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) },
            () => UIUtils.applySync(() => { this.pulsed = true; }));
        }
      })
  }
}

@ComponentV2
export struct StarLettersPage {
  @Require @Param model: StarLettersViewModel;
  @Require @Param displayFont: string;
  @Param bottomClearance: number = 112;
  @Param reducedMotion: boolean = true;
  @Param active: boolean = true;
  @Event openLetter: (entry: StarLetterEntry) => void = () => {};
  @Event returnHome: () => void = () => {};
  @Local private revealed: boolean = false;
  private readonly scroller: Scroller = new Scroller();
  private readonly tabBar: CommonModifier = new CommonModifier();

  aboutToAppear(): void {
    this.tabBar.align(Alignment.Start);
  }

  @Builder
  private heading() {
    Column() {
      Text('旅途来信').fontFamily('monospace').fontSize(10).lineHeight('12fp').fontWeight(600)
        .letterSpacing(1.4).fontColor($r('app.color.accent_muted')).width('100%')
      Text('旅途中，有人来信。').fontFamily(this.displayFont).fontSize(28).lineHeight('40.6fp')
        .letterSpacing('0.42fp').fontWeight(FontWeight.Medium).fontColor($r('app.color.strong'))
        .lineBreakStrategy(LineBreakStrategy.BALANCED).width('100%').margin({ top: 6, bottom: 6 })
      Text('下一条线索，也许就在这里。').fontSize(14).lineHeight('26.6fp')
        .fontColor($r('app.color.muted')).width('100%')
    }.id('star-letters-heading').width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 16 })
  }

  @Builder
  private loading() {
    Column({ space: 16 }) {
      if (this.active && !this.reducedMotion) {
        StarLettersSkeleton({ animated: true })
        StarLettersSkeleton({ animated: true })
      } else {
        StarLettersSkeleton()
        StarLettersSkeleton()
      }
    }.id('star-letters-loading').width('100%').accessibilityText('正在收集旅途中的信笺…')
  }

  @Builder
  private empty() {
    Column({ space: 16 }) {
      Image($r('app.media.icon_compass_thin')).width(64).height(64)
        .objectFit(ImageFit.Contain).fillColor($r('app.color.accent_muted')).accessibilityLevel('no')
      Text('还没有抵达的星海信笺').fontFamily(this.displayFont).fontSize(21).lineHeight('31.5fp')
        .fontWeight(FontWeight.Medium).fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
      Text('在场次中获得的信件与祝福，会珍藏在这里。').fontSize(13).lineHeight('24.7fp')
        .fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
    }.id('star-letters-empty').width('100%').constraintSize({ minHeight: 280 })
      .padding({ top: 32, bottom: 32, left: 20, right: 20 }).justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.accent_faint')).borderRadius(18)
  }

  @Builder
  private scrollContent() {
    Scroll(this.scroller) {
      Column() {
        if (this.model.loading && this.model.entries.length === 0) {
          this.loading()
        }
        if (this.model.error.length > 0) {
          Column() {
            ErrorNotice({ message: this.model.error, retryable: !this.model.loading, topMargin: 0,
              retry: () => { void this.model.refresh(); }, returnHome: () => this.returnHome() })
          }.id('star-letters-error').width('100%')
        }
        ForEach(this.model.detailErrors, (issue: StarLettersReadError) => {
          Column() {
            ErrorNotice({ message: issue.message, retryable: !this.model.loading, topMargin: 0,
              retry: () => { void this.model.retryAssignment(issue.assignmentId); }, returnHome: () => this.returnHome() })
          }.id(`star-letters-detail-error-${issue.assignmentId}`).width('100%')
        }, (issue: StarLettersReadError) => JSON.stringify(issue))
        if (this.model.entries.length > 0) {
          Column({ space: 10 }) {
            ForEach(this.model.entries, (entry: StarLetterEntry, index: number) => {
              StarLetterRow({ entry: entry, displayFont: this.displayFont, motionEnabled: this.active && !this.reducedMotion,
                revealDelay: index === 0 ? 0 : (index === 1 ? 70 : 120), openLetter: (letter: StarLetterEntry) => this.openLetter(letter) })
            }, (entry: StarLetterEntry) => JSON.stringify(entry))
          }.width('100%')
        } else if (!this.model.loading && this.model.error.length === 0 && this.model.detailErrors.length === 0) {
          this.empty()
        }
      }.width('100%').padding({ top: 20, bottom: this.bottomClearance, left: 6, right: 6 })
    }.id('star-letters-scroll').width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  build() {
    Column() {
      this.heading()
      Tabs({ barPosition: BarPosition.Start, index: 0, barModifier: this.tabBar }) {
        TabContent() {
          StarwardRefresh({ refreshEnabled: this.active && !this.model.loading,
            request: async () => { await this.model.refresh(); }, content: () => { this.scrollContent() } })
        }.tabBar(SubTabBarStyle.of('星海信笺').id('star-letters-tab')
          .indicator({ color: $r('app.color.accent'), height: 2 })
          .labelStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted'),
            font: { size: 15, weight: FontWeight.Medium, family: this.displayFont } }))
      }.width('100%').layoutWeight(1).barMode(BarMode.Scrollable).barHeight(54)
        .divider({ strokeWidth: 1, color: $r('app.color.border') }).scrollable(false)
    }.id('star-letters-page').width('100%').height('100%').padding({ left: 20, right: 20, top: 16 })
      .opacity(!this.active || this.reducedMotion || this.revealed ? 1 : 0)
      .translate({ y: !this.active || this.reducedMotion || this.revealed ? 0 : 14 })
      .animation(letterReveal(this.active && !this.reducedMotion))
      .onAppear(() => UIUtils.applySync(() => { this.revealed = true; }))
  }
}
