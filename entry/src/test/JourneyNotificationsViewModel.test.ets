import { describe, expect, it } from '@ohos/hypium';
import { GameNotification } from '../main/ets/business/GameNotification';
import { ReadCancellation } from '../main/ets/business/ReadCancellation';
import { GameFailure } from '../main/ets/business/models';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { JourneyNotificationsViewModel } from '../main/ets/features/JourneyNotificationsViewModel';

const SENT_AT: string = '2026-11-16T00:00:00Z';
const READ_AT: string = '2026-11-16T00:01:00Z';

function note(id: string, readAt: string = ''): GameNotification {
  return new GameNotification(id, `来信 ${id}`, '测试正文', '', '', SENT_AT, readAt, '');
}

class NotificationRepository extends MockGameRepository {
  entries: GameNotification[] = [];
  readIds: string[] = [];
  writeError: GameFailure | null = null;
  delayedRead: ((result: GameNotification[]) => void) | null = null;
  lastCancellation: ReadCancellation | undefined;
  holdNextRead: boolean = false;
  delayedWrite: ((readAt: string) => void) | null = null;
  holdNextWrite: boolean = false;
  notificationReads: number = 0;

  async notifications(cancellation?: ReadCancellation): Promise<GameNotification[]> {
    this.notificationReads++;
    this.lastCancellation = cancellation;
    if (this.holdNextRead) {
      this.holdNextRead = false;
      return new Promise<GameNotification[]>((resolve) => { this.delayedRead = resolve; });
    }
    return this.entries;
  }

  async readNotification(id: string): Promise<string> {
    this.readIds.push(id);
    if (this.writeError !== null) { throw this.writeError; }
    if (this.holdNextWrite) {
      this.holdNextWrite = false;
      return new Promise<string>((resolve) => { this.delayedWrite = resolve; });
    }
    return READ_AT;
  }
}

class BatchNotificationRepository extends NotificationRepository {
  requested: string[] = [];
  resolveBatch: ((receipts: Map<string, string>) => void) | null = null;
  missingRoute: boolean = false;

  async readNotifications(ids: string[]): Promise<Map<string, string>> {
    this.requested = ids;
    if (this.missingRoute) { throw new GameFailure('NOT_FOUND', '旧服务', 404); }
    return new Promise<Map<string, string>>((resolve) => { this.resolveBatch = resolve; });
  }
}

export default function journeyNotificationsViewModelTests(): void {
  describe('JourneyNotificationsViewModel', () => {
    it('clearsSnapshotInOneBatchAndRejectsAnOverlappingStaleHomeFeed', 0, async () => {
      const repository: BatchNotificationRepository = new BatchNotificationRepository();
      repository.entries = [note('first'), note('second'), note('history', READ_AT)];
      const model: JourneyNotificationsViewModel = new JourneyNotificationsViewModel(repository, () => {});
      model.bindOwner('owner');
      model.setHomeFeedActive(true);
      await model.refresh();
      const write: Promise<boolean> = model.markAllRead();
      const inFlightFeed: number = model.feedRevision();
      expect(model.clearingUnread).assertTrue();
      expect(await model.markRead('first')).assertFalse();
      expect(repository.requested.join(',')).assertEqual('first,second');
      const receipts: Map<string, string> = new Map();
      receipts.set('first', READ_AT);
      receipts.set('second', READ_AT);
      repository.resolveBatch?.(receipts);
      expect(await write).assertTrue();
      model.acceptHomeEntries(repository.entries, inFlightFeed);
      expect(model.unreadCount).assertEqual(0);
      model.acceptHomeEntries([note('arrived-after'), note('first', READ_AT), note('second', READ_AT)], model.feedRevision());
      expect(model.unreadEntries[0].id).assertEqual('arrived-after');
      expect(repository.readIds.length).assertEqual(0);
    });

    it('fallsBackToExistingReceiptsWhenBatchRouteIsUnavailable', 0, async () => {
      const repository: BatchNotificationRepository = new BatchNotificationRepository();
      repository.entries = [note('first'), note('second')];
      repository.missingRoute = true;
      const model: JourneyNotificationsViewModel = new JourneyNotificationsViewModel(repository, () => {});
      model.bindOwner('owner');
      await model.refresh();
      expect(await model.markAllRead()).assertTrue();
      expect(repository.readIds.join(',')).assertEqual('first,second');
      expect(model.unreadCount).assertEqual(0);
    });

    it('opensAndClosesManualReadingWithoutWritingThenUsesServerReceipt', 0, async () => {
      const repository = new NotificationRepository();
      repository.entries = [note('newer'), note('older'), note('already-read', READ_AT)];
      const model = new JourneyNotificationsViewModel(repository, () => {});
      model.bindOwner('owner');
      await model.refresh();
      expect(model.oldestUnread?.id).assertEqual('older');
      model.open('newer');
      expect(model.current?.id).assertEqual('newer');
      model.close();
      expect(model.current).assertNull();
      expect(model.unreadCount).assertEqual(2);
      expect(model.unreadEntries.map((item: GameNotification) => item.id).join(',')).assertEqual('newer,older');
      expect(repository.readIds.length).assertEqual(0);
      repository.writeError = new GameFailure('REQUEST_FAILED', '暂时无法收下');
      expect(await model.markRead('older')).assertFalse();
      expect(model.readErrorId).assertEqual('older');
      expect(model.unreadCount).assertEqual(2);
      repository.writeError = null;
      expect(await model.markRead('older')).assertTrue();
      expect(model.entries[1].readAt).assertEqual(READ_AT);
      expect(model.oldestUnread?.id).assertEqual('newer');
      expect(await model.markRead('already-read')).assertTrue();
      expect(repository.readIds.length).assertEqual(2);
    });

    it('cancelsOlderListBeforeAcknowledgingAndDiscardsItsResult', 0, async () => {
      const repository = new NotificationRepository();
      repository.entries = [note('one')];
      const model = new JourneyNotificationsViewModel(repository, () => {});
      model.bindOwner('owner');
      await model.refresh();
      repository.holdNextRead = true;
      const refresh = model.refresh();
      expect(await model.markRead('one')).assertTrue();
      expect(repository.lastCancellation?.cancelled).assertTrue();
      repository.delayedRead?.([note('one')]);
      await refresh;
      expect(model.unreadCount).assertEqual(0);
    });

    it('ignoresAnOldAccountWriteReceiptAndAvoidsConcurrentDuplicates', 0, async () => {
      const repository = new NotificationRepository();
      repository.entries = [note('shared')];
      const model = new JourneyNotificationsViewModel(repository, () => {});
      model.bindOwner('first');
      await model.refresh();
      repository.holdNextWrite = true;
      const write = model.markRead('shared');
      expect(await model.markRead('shared')).assertFalse();
      model.bindOwner('second');
      await model.refresh();
      repository.delayedWrite?.(READ_AT);
      expect(await write).assertFalse();
      expect(model.unreadCount).assertEqual(1);
      expect(repository.readIds.length).assertEqual(1);
    });

    it('routeReadingRequiresAcknowledgementAndKeepsFullInboxHistory', 0, async () => {
      const repository = new NotificationRepository();
      repository.entries = [note('next'), note('first'), note('archived', READ_AT)];
      const model = new JourneyNotificationsViewModel(repository, () => {});
      model.bindOwner('owner');
      await model.refresh();
      await model.closeRouteNote('assignment', 'next', false);
      expect(repository.readIds.length).assertEqual(0);
      expect(model.oldestUnread?.id).assertEqual('first');

      model.openRouteArchive('assignment', 'first');
      expect(model.archivedOnRoute('assignment')?.id).assertEqual('first');
      expect(repository.readIds.length).assertEqual(0);
      await model.closeRouteNote('assignment', 'first', false);
      expect(model.archivedOnRoute('assignment')).assertNull();
      expect(model.unreadCount).assertEqual(2);
      model.openRouteArchive('assignment', 'first');
      await model.closeRouteNote('assignment', 'first', true);
      expect(repository.readIds.length).assertEqual(1);
      expect(model.oldestUnread?.id).assertEqual('next');

      model.openRouteArchive('assignment', 'archived');
      expect(model.archivedOnRoute('assignment')).assertNull();
      expect(model.archivedOnRoute('other')).assertNull();
      expect(model.current).assertNull();
      await model.closeRouteNote('assignment', 'archived', true);
      expect(model.archivedOnRoute('assignment')).assertNull();
      expect(repository.readIds.length).assertEqual(1);

      model.openRouteArchive('assignment', 'next');
      await model.closeRouteNote('assignment', 'next', true);
      expect(model.unreadCount).assertEqual(0);
      expect(model.entries.length).assertEqual(3);
      expect(model.unreadClearedRevision).assertEqual(1);
      expect(await model.markRead('next')).assertTrue();
      expect(repository.readIds.length).assertEqual(2);
      expect(model.unreadClearedRevision).assertEqual(1);
      model.bindOwner('replacement');
      expect(model.archivedOnRoute('assignment')).assertNull();
      expect(model.unreadClearedRevision).assertEqual(0);
    });

    it('newMailSignalsAreAccountScopedDeduplicatedAndCoalescedAfterBaseline', 0, async () => {
      const repository = new NotificationRepository();
      repository.entries = [note('baseline')];
      const model = new JourneyNotificationsViewModel(repository, () => {});
      model.bindOwner('owner');
      await model.refresh();
      expect(model.unreadCount).assertEqual(1);
      expect(model.newUnreadRevision).assertEqual(0);
      repository.entries = [note('arrived'), note('baseline'), note('already-read', READ_AT)];
      await model.refresh();
      expect(model.newUnreadRevision).assertEqual(1);
      expect(model.newUnreadCount).assertEqual(1);
      await model.refresh();
      expect(model.newUnreadRevision).assertEqual(1);
      repository.entries = [note('another'), ...repository.entries];
      await model.refresh();
      expect(model.newUnreadCount).assertEqual(2);
      model.dismissNewUnread();
      await model.refresh();
      expect(model.newUnreadCount).assertEqual(0);
      expect(model.newUnreadRevision).assertEqual(2);
      model.bindOwner('replacement');
      await model.refresh();
      expect(model.newUnreadRevision).assertEqual(0);
      expect(model.newUnreadCount).assertEqual(0);
    });

    it('emptyBaselineStillDetectsArrivalAndFailedAcknowledgementKeepsUnread', 0, async () => {
      const repository = new NotificationRepository();
      const model = new JourneyNotificationsViewModel(repository, () => {});
      model.bindOwner('owner');
      await model.refresh();
      repository.entries = [note('arrived')];
      await model.refresh();
      expect(model.newUnreadCount).assertEqual(1);
      model.openRouteArchive('assignment', 'arrived');
      repository.writeError = new GameFailure('NETWORK_ERROR', '连接中断');
      await model.closeRouteNote('assignment', 'arrived', true);
      expect(model.unreadCount).assertEqual(1);
      expect(model.archivedOnRoute('assignment')?.id).assertEqual('arrived');
      expect(model.unreadClearedRevision).assertEqual(0);
      repository.writeError = null;
      await model.closeRouteNote('assignment', 'arrived', true);
      expect(model.unreadCount).assertEqual(0);
      expect(model.newUnreadCount).assertEqual(0);
      expect(model.unreadClearedRevision).assertEqual(1);
    });

    it('globalPollingOwnsItsReadWhenTheQuestStopsAndPausesSafely', 0, async () => {
      const repository = new NotificationRepository();
      repository.holdNextRead = true;
      const model = new JourneyNotificationsViewModel(repository, () => {});
      model.bindOwner('owner');
      model.setInboxPolling(true);
      model.setPolling(true);
      model.setPolling(false);
      expect(repository.lastCancellation?.cancelled).assertFalse();
      expect(model.gameplayReady).assertFalse();
      model.setInboxPolling(false);
      expect(repository.lastCancellation?.cancelled).assertTrue();
      repository.delayedRead?.([note('late')]);
      await new Promise<void>((resolve) => { setTimeout(resolve, 0); });
      expect(model.entries.length).assertEqual(0);
      expect(model.newUnreadRevision).assertEqual(0);
    });

    it('closingAutomaticMailDefersItOnTheCurrentRouteWithoutAcknowledging', 0, async () => {
      const repository = new NotificationRepository();
      repository.entries = [note('newest'), note('middle'), note('oldest')];
      const model = new JourneyNotificationsViewModel(repository, () => {});
      model.bindOwner('owner');
      await model.refresh();
      model.setPolling(true);
      try {
        expect(model.automaticUnreadOnRoute('assignment')?.id).assertEqual('oldest');
        await model.closeRouteNote('assignment', 'oldest', false);
        expect(model.automaticUnreadOnRoute('assignment')?.id).assertEqual('middle');
        await model.closeRouteNote('assignment', 'middle', false);
        await model.closeRouteNote('assignment', 'newest', false);
        expect(model.automaticUnreadOnRoute('assignment')).assertNull();
        expect(model.unreadEntries.length).assertEqual(3);
        expect(repository.readIds.length).assertEqual(0);
        await model.refresh();
        expect(model.automaticUnreadOnRoute('assignment')).assertNull();
        repository.entries = [note('arrived'), ...repository.entries];
        await model.refresh();
        expect(model.automaticUnreadOnRoute('assignment')?.id).assertEqual('arrived');
        expect(model.automaticUnreadOnRoute('other')?.id).assertEqual('oldest');
        model.openRouteArchive('assignment', 'oldest');
        repository.writeError = new GameFailure('NETWORK_ERROR', '连接中断');
        await model.closeRouteNote('assignment', 'oldest', true);
        expect(model.archivedOnRoute('assignment')?.id).assertEqual('oldest');
        expect(model.unreadCount).assertEqual(4);
        repository.writeError = null;
        await model.closeRouteNote('assignment', 'oldest', true);
        expect(model.archivedOnRoute('assignment')).assertNull();
        expect(model.unreadCount).assertEqual(3);
      } finally {
        model.setPolling(false);
      }
      expect(model.automaticUnreadOnRoute('assignment')?.id).assertEqual('arrived');
      model.leaveRoute('assignment');
      expect(model.automaticUnreadOnRoute('assignment')?.id).assertEqual('middle');
      model.bindOwner('replacement');
      expect(model.automaticUnreadOnRoute('assignment')).assertNull();
    });

    it('temporaryQuestReadPausesKeepDismissedMailUntilExplicitRouteExit', 0, async () => {
      const repository = new NotificationRepository();
      repository.entries = [note('one')];
      const model = new JourneyNotificationsViewModel(repository, () => {});
      model.bindOwner('owner');
      await model.refresh();
      model.setPolling(true);
      try {
        await model.closeRouteNote('assignment', 'one', false);
        model.setPolling(false);
        await model.refresh();
        model.setPolling(true);
        expect(model.automaticUnreadOnRoute('assignment')).assertNull();
        model.pauseReads();
        await model.refresh();
        model.setPolling(true);
        expect(model.automaticUnreadOnRoute('assignment')).assertNull();
        expect(model.unreadCount).assertEqual(1);
        expect(repository.readIds.length).assertEqual(0);
        model.leaveRoute('other');
        expect(model.automaticUnreadOnRoute('assignment')).assertNull();
        model.leaveRoute('assignment');
        expect(model.automaticUnreadOnRoute('assignment')?.id).assertEqual('one');
      } finally {
        model.suspend();
      }
    });

    it('anEarlyGlobalReadCannotBypassTheQuestStartupDelay', 0, async () => {
      const repository = new NotificationRepository();
      repository.holdNextRead = true;
      const model = new JourneyNotificationsViewModel(repository, () => {}, 30);
      model.bindOwner('owner');
      model.setInboxPolling(true);
      model.setPolling(true);
      try {
        repository.delayedRead?.([note('arrived')]);
        await new Promise<void>((resolve) => { setTimeout(resolve, 0); });
        expect(model.gameplayReady).assertFalse();
        expect(repository.notificationReads).assertEqual(1);
        await new Promise<void>((resolve) => { setTimeout(resolve, 35); });
        expect(model.gameplayReady).assertTrue();
        expect(repository.notificationReads).assertEqual(1);
      } finally {
        model.suspend();
      }
    });

    it('questDelayAloneCannotShowMailWithoutAConfirmedReadAndStopsWithItsOwner', 0, async () => {
      const repository = new NotificationRepository();
      repository.holdNextRead = true;
      const model = new JourneyNotificationsViewModel(repository, () => {}, 10);
      model.bindOwner('owner');
      model.setInboxPolling(true);
      model.setPolling(true);
      try {
        await new Promise<void>((resolve) => { setTimeout(resolve, 15); });
        expect(model.gameplayReady).assertFalse();
        repository.delayedRead?.([note('arrived')]);
        await new Promise<void>((resolve) => { setTimeout(resolve, 0); });
        expect(model.gameplayReady).assertTrue();
        model.setPolling(false);
        expect(model.gameplayReady).assertFalse();
        await new Promise<void>((resolve) => { setTimeout(resolve, 15); });
        expect(model.gameplayReady).assertFalse();
        expect(repository.notificationReads).assertEqual(1);
        expect(repository.lastCancellation?.cancelled).assertFalse();
      } finally {
        model.suspend();
      }
    });
  });
}
