import { CommonModifier, curves, LengthMetrics, UIUtils } from '@kit.ArkUI';
import { GameNotification } from '../business/GameNotification';
import { journeyNotificationPreview } from '../business/JourneyNotificationContent';
import { StarLetterEntry } from '../business/StarLetters';
import { ErrorNotice } from '../ui/ErrorMessages';
import { StarwardJourneyNotificationDialog } from '../ui/StarwardJourneyNotificationDialog';
import { StarwardRefresh } from '../ui/StarwardRefresh';
import { JourneyNotificationsViewModel } from './JourneyNotificationsViewModel';
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
struct JourneyLetterRow {
  @Require @Param note: GameNotification;
  @Require @Param displayFont: string;
  @Param reading: boolean = false;
  @Event open: () => void = () => {};
  @Event markRead: () => void = () => {};

  private unread(): boolean { return this.note.readAt.length === 0; }

  build() {
    Stack({ alignContent: Alignment.End }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          Stack() {
            Image(this.unread() ? $r('app.media.icon_envelope') : $r('app.media.icon_envelope_open'))
              .width(21).height(21).objectFit(ImageFit.Contain).fillColor($r('app.color.accent_text'))
              .accessibilityLevel('no')
          }.width(36).height(36).borderRadius(11).backgroundColor($r('app.color.accent_soft'))
          Column({ space: 4 }) {
            Text(this.note.title || this.note.popupTitle || '一封新来信')
              .fontFamily(this.displayFont).fontSize(18).fontWeight(FontWeight.Medium).lineHeight('26fp')
              .fontColor($r('app.color.strong')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              .wordBreak(WordBreak.BREAK_WORD).width('100%')
            Text(journeyNotificationPreview(this.note.content)).fontSize(13).lineHeight('20.8fp')
              .fontColor($r('app.color.muted')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              .wordBreak(WordBreak.BREAK_WORD).width('100%')
            Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(3) } }) {
              Text(this.unread() ? '一封新来信' : '已收下').fontSize(11).lineHeight('16.5fp')
                .fontColor($r('app.color.muted'))
              Text(formatLetterDate(this.note.sentAt)).fontSize(11).lineHeight('16.5fp')
                .fontColor($r('app.color.muted'))
            }.width('100%')
          }.layoutWeight(1).constraintSize({ minWidth: 0 }).alignItems(HorizontalAlign.Start)
          if (this.unread()) {
            Circle().width(6).height(6).fill($r('app.color.accent')).accessibilityText('未读')
          } else {
            Image($r('app.media.icon_arrow_right')).width(16).height(16).objectFit(ImageFit.Contain)
              .fillColor($r('app.color.muted')).accessibilityLevel('no')
          }
        }.width('100%').alignItems(VerticalAlign.Center)
          .padding({ top: 12, bottom: 12, left: 14, right: this.unread() ? 52 : 14 })
      }.id(`journey-notification-${this.note.id}`).width('100%').constraintSize({ minHeight: 70 }).padding(0)
        .borderRadius(0).backgroundColor(this.unread() ? $r('app.color.accent_faint') : $r('app.color.surface'))
        .onClick(() => this.open())
      if (this.unread()) {
        Button({ type: ButtonType.Normal }) {
          Image($r('app.media.icon_dots_three')).width(24).height(24).objectFit(ImageFit.Contain)
            .fillColor($r('app.color.subtle')).accessibilityLevel('no')
        }.id(`journey-notification-actions-${this.note.id}`).width(40).height(44).padding(0).margin({ right: 6 })
          .borderRadius(8).backgroundColor(Color.Transparent).enabled(!this.reading).accessibilityText('来信操作')
          .bindMenu([{ value: '标为已读', action: () => this.markRead() }], { placement: Placement.BottomRight })
      }
    }.width('100%')
  }
}

@ComponentV2
struct JourneyNotificationFailure {
  @Require @Param message: string;
  @Require @Param nodeId: string;
  @Param retryable: boolean = true;
  @Event retry: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Text(this.message).fontSize(14).lineHeight('23.8fp').fontColor($r('app.color.danger')).width('100%')
      Button('重新尝试', { type: ButtonType.Normal }).id(this.nodeId + '-retry').constraintSize({ minHeight: 40 })
        .fontSize(13).padding({ left: 14, right: 14 }).borderRadius(10).fontColor($r('app.color.text'))
        .backgroundColor($r('app.color.surface')).enabled(this.retryable).onClick(() => this.retry())
    }.id(this.nodeId).width('100%').alignItems(HorizontalAlign.Start).padding(16)
      .backgroundColor($r('app.color.danger_surface'))
      .border({ width: 1, color: $r('app.color.danger_border'), radius: 10 })
  }
}

@ComponentV2
export struct StarLettersPage {
  @Require @Param model: StarLettersViewModel;
  @Require @Param journey: JourneyNotificationsViewModel;
  @Require @Param playerId: string;
  @Require @Param displayFont: string;
  @Param bottomClearance: number = 112;
  @Param reducedMotion: boolean = true;
  @Param active: boolean = true;
  @Event openLetter: (entry: StarLetterEntry) => void = () => {};
  @Event returnHome: () => void = () => {};
  @Event openInternalLink: (href: string) => boolean = () => false;
  @Local private revealed: boolean = false;
  @Local private category: number = 0;
  private readonly scroller: Scroller = new Scroller();
  private readonly journeyScroller: ListScroller = new ListScroller();
  private readonly tabBar: CommonModifier = new CommonModifier();

  aboutToAppear(): void {
    this.tabBar.align(Alignment.Start);
  }

  private closeJourneyNote(id: string): void {
    if (id === this.journey.activeNotificationId) { this.journey.close(); }
  }

  private async acknowledgeJourneyNote(id: string): Promise<void> {
    const current: GameNotification | null = this.journey.current;
    if (id !== current?.id) { return; }
    if (current.readAt.length > 0 || await this.journey.markRead(id)) { this.closeJourneyNote(id); }
  }

  @Builder
  private heading() {
    Column() {
      Text('旅途来信').fontFamily('monospace').fontSize(10).lineHeight('12fp').fontWeight(600)
        .letterSpacing(1.4).fontColor($r('app.color.accent_muted')).width('100%')
      Text('旅途中，有人来信。').fontFamily(this.displayFont).fontSize(28).lineHeight('40.6fp')
        .letterSpacing('0.42fp').fontWeight(FontWeight.Medium).fontColor($r('app.color.strong'))
        .lineBreakStrategy(LineBreakStrategy.BALANCED).width('100%').margin({ top: 6, bottom: 6 })
      Text('下一条线索，也许就在这里。' + (this.journey.unreadCount > 0 ? `你有 ${this.journey.unreadCount} 封新来信。` : ''))
        .fontSize(14).lineHeight('26.6fp')
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

  @Builder
  private journeyEmpty() {
    Column({ space: 16 }) {
      Image($r('app.media.icon_compass_thin')).width(64).height(64)
        .objectFit(ImageFit.Contain).fillColor($r('app.color.accent_muted')).accessibilityLevel('no')
      Text('此刻，信箱里只有星光。').fontFamily(this.displayFont).fontSize(21).lineHeight('31.5fp')
        .fontWeight(FontWeight.Medium).fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
      Text('暂时没有消息。新的来信会自动送到，不必守在这里等。').fontSize(13).lineHeight('24.7fp')
        .fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
    }.id('journey-notifications-empty').width('100%').constraintSize({ minHeight: 280 })
      .padding({ top: 32, bottom: 32, left: 20, right: 20 }).justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.accent_faint')).borderRadius(18)
  }

  @Builder
  private swipeAccept(id: string) {
    Button(this.journey.readingId === id ? '正在收下…' : '收下', { type: ButtonType.Normal })
      .id(`journey-notification-swipe-accept-${id}`).width(88).height('100%').padding(0).borderRadius(0)
      .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.on_accent'))
      .backgroundColor($r('app.color.accent')).enabled(this.journey.readingId.length === 0)
      .onClick(() => { void this.journey.markRead(id); })
  }

  @Builder
  private journeyScroll() {
    List({ space: 10, scroller: this.journeyScroller }) {
      if (this.journey.loading && this.journey.entries.length === 0) {
        ListItem() {
          Column({ space: 16 }) {
            StarLettersSkeleton({ animated: this.active && !this.reducedMotion })
            StarLettersSkeleton({ animated: this.active && !this.reducedMotion })
          }.id('journey-notifications-loading').width('100%').accessibilityText('正在整理旅途来信…')
        }
      }
      if (this.journey.error.length > 0) {
        ListItem() {
          JourneyNotificationFailure({ message: this.journey.error, nodeId: 'journey-notifications-error',
            retryable: !this.journey.loading, retry: () => { void this.journey.refresh(); } })
        }
      }
      ForEach(this.journey.entries, (note: GameNotification) => {
        ListItem() {
          JourneyLetterRow({ note: note, displayFont: this.displayFont, reading: this.journey.readingId.length > 0,
            open: () => { this.journeyScroller.closeAllSwipeActions(); this.journey.open(note.id); },
            markRead: () => { void this.journey.markRead(note.id); } })
        }.width('100%').border({ width: 1, color: $r('app.color.border'), radius: 14 }).clip(true)
          .swipeAction({ end: note.readAt.length === 0 ? () => this.swipeAccept(note.id) : undefined,
            edgeEffect: SwipeEdgeEffect.None })
        if (this.journey.readErrorId === note.id && this.journey.activeNotificationId !== note.id) {
          ListItem() {
            JourneyNotificationFailure({ message: this.journey.readErrorMessage, nodeId: `journey-notification-error-${note.id}`,
              retryable: this.journey.readingId.length === 0, retry: () => { void this.journey.markRead(note.id); } })
          }
        }
      }, (note: GameNotification) => `${note.id}:${note.readAt}`)
      if (!this.journey.loading && this.journey.error.length === 0 && this.journey.entries.length === 0) {
        ListItem() { this.journeyEmpty() }
      }
      ListItem() { Column() {}.height(this.bottomClearance) }
    }.id('journey-notifications-scroll').width('100%').height('100%').scrollBar(BarState.Off)
      .contentStartOffset(20).padding({ left: 6, right: 6 }).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  build() {
    Column() {
      this.heading()
      Tabs({ barPosition: BarPosition.Start, index: this.category, barModifier: this.tabBar }) {
        TabContent() {
          StarwardRefresh({ refreshEnabled: this.active && !this.journey.loading,
            request: async () => { await this.journey.refresh(); }, content: () => { this.journeyScroll() } })
        }.tabBar(SubTabBarStyle.of(this.journey.unreadCount > 0 ? `旅途来信 · ${this.journey.unreadCount}` : '旅途来信')
          .id('journey-notifications-tab').indicator({ color: $r('app.color.accent'), height: 2 })
          .labelStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted'),
            font: { size: 15, weight: FontWeight.Medium, family: this.displayFont } }))
        TabContent() {
          StarwardRefresh({ refreshEnabled: this.active && !this.model.loading,
            request: async () => { await this.model.refresh(); }, content: () => { this.scrollContent() } })
        }.tabBar(SubTabBarStyle.of('星海信笺').id('star-letters-tab')
          .indicator({ color: $r('app.color.accent'), height: 2 })
          .labelStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted'),
            font: { size: 15, weight: FontWeight.Medium, family: this.displayFont } }))
      }.width('100%').layoutWeight(1).barMode(BarMode.Scrollable).barHeight(54)
        .divider({ strokeWidth: 1, color: $r('app.color.border') }).scrollable(false)
        .onChange((index: number) => { this.category = index; })
      StarwardJourneyNotificationDialog({ note: this.journey.current, playerId: this.playerId, active: this.active,
        displayFont: this.displayFont, reducedMotion: this.reducedMotion,
        pending: this.journey.activeNotificationId.length > 0 && this.journey.readingId.length > 0,
        error: this.journey.readErrorId === this.journey.activeNotificationId ? this.journey.readErrorMessage : '',
        acknowledgeLabel: (this.journey.current?.readAt.length ?? 0) > 0 ? '关闭信件' :
          this.journey.current?.buttonText || '收下这封信', close: (id: string) => this.closeJourneyNote(id),
        acknowledge: (id: string) => { void this.acknowledgeJourneyNote(id); },
        openInternalLink: (href: string) => this.openInternalLink(href) })
    }.id('star-letters-page').width('100%').height('100%').padding({ left: 20, right: 20, top: 16 })
      .opacity(!this.active || this.reducedMotion || this.revealed ? 1 : 0)
      .translate({ y: !this.active || this.reducedMotion || this.revealed ? 0 : 14 })
      .animation(letterReveal(this.active && !this.reducedMotion))
      .onAppear(() => UIUtils.applySync(() => { this.revealed = true; }))
  }
}
