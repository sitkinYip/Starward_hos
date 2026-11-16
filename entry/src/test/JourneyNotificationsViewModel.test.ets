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

  async notifications(cancellation?: ReadCancellation): Promise<GameNotification[]> {
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

export default function journeyNotificationsViewModelTests(): void {
  describe('JourneyNotificationsViewModel', () => {
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
  });
}
