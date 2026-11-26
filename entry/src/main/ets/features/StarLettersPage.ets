import { curves, SegmentButtonV2Items, UIUtils } from '@kit.ArkUI';
import { GameNotification } from '../business/GameNotification';
import { journeyNotificationPreview } from '../business/JourneyNotificationContent';
import { StarLetterEntry } from '../business/StarLetters';
import { ErrorNotice } from '../ui/ErrorMessages';
import { StarwardErrorToast } from '../ui/StarwardErrorToast';
import { StarwardJourneyNotificationDialog } from '../ui/StarwardJourneyNotificationDialog';
import { starwardListReveal } from '../ui/StarwardMotion';
import { StarwardPageHeading } from '../ui/StarwardPageHeading';
import { StarwardRefresh } from '../ui/StarwardRefresh';
import { StarwardCapsuleSegment, StarwardPaneTabs } from '../ui/StarwardTabs';
import { STARWARD_RADIUS_CONTROL, STARWARD_RADIUS_PANEL, STARWARD_RADIUS_ROUND } from '../ui/StarwardRadii';
import { JourneyNotificationsViewModel } from './JourneyNotificationsViewModel';
import { StarLettersReadError, StarLettersViewModel } from './StarLettersViewModel';
import { StarwardMailboxRow } from './StarwardMailboxRow';

@ComponentV2
struct StarLettersSkeleton {
  @Param animated: boolean = false;
  @Local private pulsed: boolean = false;

  build() {
    Row({ space: 16 }) {
      Column().width(70).height(110).borderRadius(STARWARD_RADIUS_CONTROL).backgroundColor($r('app.color.accent_soft'))
      Column({ space: 16 }) {
        Column().width('100%').height(47).borderRadius(STARWARD_RADIUS_CONTROL)
          .backgroundColor($r('app.color.accent_soft'))
        Column().width('65%').height(47).borderRadius(STARWARD_RADIUS_CONTROL)
          .backgroundColor($r('app.color.accent_soft'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').constraintSize({ minHeight: 160 }).padding(24).alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.glass_card_top'))
      .border({ width: 1, color: $r('app.color.border'), radius: STARWARD_RADIUS_PANEL })
      .opacity(this.animated ? (this.pulsed ? 0.85 : 0.4) : 1).accessibilityLevel('no-hide-descendants')
      .onAppear(() => {
        if (this.animated) {
          this.getUIContext().animateTo({ duration: 1000, iterations: -1, playMode: PlayMode.Alternate,
            curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) }, () => {
            try { UIUtils.applySync(() => { this.pulsed = true; }); } catch { this.pulsed = true; }
          });
        }
      })
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
      Text(this.message).fontSize(14).lineHeight('23.8fp').fontColor($r('app.color.danger_strong')).width('100%')
      Button('重新尝试', { type: ButtonType.Normal }).id(this.nodeId + '-retry').constraintSize({ minHeight: 40 })
        .fontSize(13).padding({ left: 14, right: 14 }).borderRadius(STARWARD_RADIUS_ROUND).fontColor($r('app.color.text'))
        .backgroundColor($r('app.color.surface')).enabled(this.retryable).onClick(() => this.retry())
    }.id(this.nodeId).width('100%').alignItems(HorizontalAlign.Start).padding(16)
      .backgroundColor($r('app.color.danger_surface'))
      .border({ width: 1, color: $r('app.color.danger_border'), radius: STARWARD_RADIUS_CONTROL })
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
  @Param category: number = 0;
  @Event categoryChanged: (index: number) => void = () => {};
  @Event openLetter: (entry: StarLetterEntry) => void = () => {};
  @Event openInternalLink: (href: string) => boolean = () => false;
  @Local private revealed: boolean = false;
  private readonly scroller: Scroller = new Scroller();
  private readonly journeyScroller: ListScroller = new ListScroller();
  private readonly refreshToast: StarwardErrorToast = new StarwardErrorToast();
  private readonly sections: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '旅途来信', accessibilityText: '旅途来信' }, { text: '星海信笺', accessibilityText: '星海信笺' }
  ]);
  private refreshRevision: number = 0;
  private inboxReadingRevision: number = 0;

  aboutToAppear(): void { this.updateUnreadTab(); }

  aboutToDisappear(): void { this.clearRefreshToast(); this.inboxReadingRevision++; }

  @Monitor('active', 'category', 'playerId')
  refreshScopeChanged(): void { this.clearRefreshToast(); this.inboxReadingRevision++; }

  @Monitor('journey.entries')
  private updateUnreadTab(): void {
    const unread: number = this.journey.unreadCount;
    this.sections[0].text = unread > 0 ? `旅途来信 · ${unread}` : '旅途来信';
    this.sections[0].accessibilityText = unread > 0 ? `旅途来信，${unread} 封未读` : '旅途来信';
  }

  private isFinale(entry: StarLetterEntry): boolean {
    return entry.title === '旅途终章' && entry.sessionTitle.length > 0 && entry.description === entry.sessionTitle;
  }

  private archiveSummary(entry: StarLetterEntry): string {
    const summary: string = entry.description.trim();
    return summary === entry.title.trim() || summary === entry.sessionTitle.trim() ? '' : summary;
  }

  private clearRefreshToast(): void {
    this.refreshRevision++;
    this.refreshToast.dismiss();
  }

  private async refreshArchive(): Promise<void> {
    if (!this.active || this.category !== 1) { return; }
    this.clearRefreshToast();
    const revision: number = this.refreshRevision;
    const message: string = await this.model.refresh();
    if (message.length > 0 && revision === this.refreshRevision && this.active && this.category === 1) {
      this.refreshToast.show(this.getUIContext(), message, this.bottomClearance);
    }
  }

  private closeJourneyNote(id: string): void {
    if (id === this.journey.activeNotificationId) {
      this.inboxReadingRevision++;
      this.journey.close();
    }
  }

  private openJourneyNote(id: string): void {
    if (!this.active || this.category !== 0) { return; }
    this.inboxReadingRevision++;
    try { this.journeyScroller.closeAllSwipeActions(); } catch { /* The list may be finishing a native relayout. */ }
    this.journey.open(id);
  }

  private async acknowledgeJourneyNote(id: string): Promise<void> {
    const current: GameNotification | null = this.journey.current;
    if (id !== current?.id || !this.active || this.category !== 0) { return; }
    const revision: number = this.inboxReadingRevision;
    const acknowledged: boolean = current.readAt.length > 0 || await this.journey.markRead(id);
    if (acknowledged && revision === this.inboxReadingRevision) { this.closeJourneyNote(id); }
  }

  private async clearUnread(): Promise<void> {
    if (!this.active || this.journey.clearingUnread || this.journey.readingId.length > 0) { return; }
    const owner: string = this.playerId;
    this.clearRefreshToast();
    const revision: number = this.refreshRevision;
    const completed: boolean = await this.journey.markAllRead();
    if (!completed && this.active && owner === this.playerId && revision === this.refreshRevision) {
      this.refreshToast.show(this.getUIContext(), '部分来信未能标为已读，请重试。', this.bottomClearance);
    }
  }

  @Builder
  private heading() {
    StarwardPageHeading({ title: '来信', nodeId: 'star-letters-heading', unreadCount: this.journey.unreadCount,
      clearingUnread: this.journey.clearingUnread, clearUnread: () => { void this.clearUnread(); } }).margin({ bottom: 16 })
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
      .backgroundColor($r('app.color.glass_card_top'))
      .border({ width: 1, radius: STARWARD_RADIUS_PANEL, color: $r('app.color.border') })
  }

  @Builder
  private scrollContent() {
    Scroll(this.scroller) {
      Column({ space: 10 }) {
        if (this.model.loading && !this.model.archiveReady && this.model.entries.length === 0) {
          this.loading()
        }
        if (this.model.error.length > 0) {
          Column() {
            ErrorNotice({ message: this.model.error, retryable: !this.model.loading, topMargin: 0,
              retry: () => { void this.refreshArchive(); } })
          }.id('star-letters-error').width('100%')
        }
        if (this.model.entries.length > 0) {
          Column({ space: 12 }) {
            ForEach(this.model.entries, (entry: StarLetterEntry, index: number) => {
              StarwardMailboxRow({ nodeId: `star-letter-${entry.id}`, sentAt: entry.sentAt,
                title: this.isFinale(entry) ? entry.sessionTitle : entry.title,
                source: this.isFinale(entry) ? entry.title : entry.sessionTitle, summary: this.archiveSummary(entry),
                icon: $r('app.media.icon_sparkle'), motionEnabled: this.active && !this.reducedMotion,
                revealDelay: Math.min(120, index * 70), open: () => this.openLetter(entry) })
            }, (entry: StarLetterEntry) => JSON.stringify(entry))
          }.width('100%')
        } else if (this.model.archiveReady && this.model.error.length === 0) {
          this.empty()
        }
        ForEach(this.model.detailErrors, (issue: StarLettersReadError) => {
          Column() {
            ErrorNotice({ message: issue.message, retryable: !this.model.loading, topMargin: 0,
              retry: () => { void this.model.retryAssignment(issue.assignmentId); } })
          }.id(`star-letters-detail-error-${issue.assignmentId}`).width('100%')
        }, (issue: StarLettersReadError) => JSON.stringify(issue))
      }.width('100%').padding({ top: 2, bottom: this.bottomClearance, left: 6, right: 6 })
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
      .backgroundColor($r('app.color.glass_card_top'))
      .border({ width: 1, radius: STARWARD_RADIUS_PANEL, color: $r('app.color.border') })
  }

  @Builder
  private swipeAccept(id: string) {
    Button(this.journey.readingId === id ? '正在收下…' : '收下', { type: ButtonType.Normal })
      .id(`journey-notification-swipe-accept-${id}`).width(88).height('100%').padding(0).borderRadius(0)
      .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.on_accent'))
      .backgroundColor($r('app.color.accent')).enabled(this.journey.readingId.length === 0 && !this.journey.clearingUnread)
      .onClick(() => { void this.journey.markRead(id); })
  }

  @Builder
  private journeyScroll() {
    List({ space: 12, scroller: this.journeyScroller }) {
      if (this.journey.loading && this.journey.entries.length === 0) {
        ListItem() {
          Column({ space: 16 }) {
            if (this.active && !this.reducedMotion) {
              StarLettersSkeleton({ animated: true })
              StarLettersSkeleton({ animated: true })
            } else {
              StarLettersSkeleton()
              StarLettersSkeleton()
            }
          }.id('journey-notifications-loading').width('100%').accessibilityText('正在整理旅途来信…')
        }
      }
      if (this.journey.error.length > 0) {
        ListItem() {
          JourneyNotificationFailure({ message: this.journey.error, nodeId: 'journey-notifications-error',
            retryable: !this.journey.loading, retry: () => { void this.journey.refresh(); } })
        }
      }
      ForEach(this.journey.entries, (note: GameNotification, index: number) => {
        ListItem() {
          StarwardMailboxRow({ nodeId: `journey-notification-${note.id}`, sentAt: note.sentAt,
            title: note.title || note.popupTitle || '一封新来信', summary: journeyNotificationPreview(note.content),
            source: note.readAt.length === 0 ? '一封新来信' : '已收下',
            icon: note.readAt.length === 0 ? $r('app.media.icon_envelope') : $r('app.media.icon_envelope_open'),
            unread: note.readAt.length === 0, reading: this.journey.readingId.length > 0 || this.journey.clearingUnread,
            actionId: `journey-notification-actions-${note.id}`, motionEnabled: this.active && !this.reducedMotion,
            revealDelay: Math.min(120, index * 70), open: () => this.openJourneyNote(note.id),
            markRead: () => { void this.journey.markRead(note.id); } })
        }.width('100%').borderRadius(STARWARD_RADIUS_PANEL).clip(true)
          .swipeAction({ end: note.readAt.length === 0 ? () => this.swipeAccept(note.id) : undefined,
            edgeEffect: SwipeEdgeEffect.None })
        if (this.journey.readErrorId === note.id && this.journey.activeNotificationId !== note.id) {
          ListItem() {
            JourneyNotificationFailure({ message: this.journey.readErrorMessage, nodeId: `journey-notification-error-${note.id}`,
              retryable: this.journey.readingId.length === 0 && !this.journey.clearingUnread,
              retry: () => { void this.journey.markRead(note.id); } })
          }
        }
      }, (note: GameNotification) => JSON.stringify(note))
      if (!this.journey.loading && this.journey.error.length === 0 && this.journey.entries.length === 0) {
        ListItem() { this.journeyEmpty() }
      }
      ListItem() { Column() {}.height(this.bottomClearance) }
    }.id('journey-notifications-scroll').width('100%').height('100%').scrollBar(BarState.Off)
      .contentStartOffset(2).padding({ left: 6, right: 6 }).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  @Builder
  private journeyPane() {
    StarwardRefresh({ refreshEnabled: this.active && this.category === 0 && !this.journey.loading,
      request: async () => { await this.journey.refresh(); }, content: () => { this.journeyScroll() } })
  }

  @Builder
  private archivePane() {
    StarwardRefresh({ refreshEnabled: this.active && this.category === 1 && !this.model.loading,
      request: async () => { await this.refreshArchive(); }, content: () => { this.scrollContent() } })
  }

  build() {
    Column() {
      this.heading()
      StarwardCapsuleSegment({ items: this.sections, selectedIndex: this.category, reducedMotion: this.reducedMotion,
        nodeId: 'mailbox-segment', selectionChanged: (index: number) => this.categoryChanged(index) }).margin({ bottom: 18 })
      StarwardPaneTabs({ selectedIndex: this.category, reducedMotion: this.reducedMotion, nodeId: 'mailbox-panes',
        selectionChanged: (index: number) => this.categoryChanged(index),
        first: () => { this.journeyPane() }, second: () => { this.archivePane() }
      }).layoutWeight(1)
      StarwardJourneyNotificationDialog({ note: this.journey.current, playerId: this.playerId,
        active: this.active && this.category === 0,
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
      .animation(starwardListReveal(this.active && !this.reducedMotion))
      .onAppear(() => {
        try { UIUtils.applySync(() => { this.revealed = true; }); } catch { this.revealed = true; }
      })
  }
}
