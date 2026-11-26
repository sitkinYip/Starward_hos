import { describe, expect, it } from '@ohos/hypium';
import { GameFailure } from '../main/ets/business/models';
import { ProgressWatchCommand, ProgressWatchDetail, ProgressWatchList } from '../main/ets/business/ProgressWatch';
import { ReadCancellation } from '../main/ets/business/ReadCancellation';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { ProgressWatchViewModel } from '../main/ets/features/ProgressWatchViewModel';
import { LaunchRoutes, PUSH_OPEN_ACTION } from '../main/ets/platform/LaunchRoutes';

const WATCH_ID: string = 'progresswatch01';

function snapshot(): ProgressWatchDetail {
  const detail: ProgressWatchDetail = new ProgressWatchDetail();
  detail.watch.id = WATCH_ID;
  detail.watch.revision = 1;
  return detail;
}

class ProgressRepository extends MockGameRepository {
  current: ProgressWatchDetail = snapshot();
  commands: ProgressWatchCommand[] = [];
  failure: GameFailure | null = null;
  holdList: boolean = false;
  holdWrite: boolean = false;
  finishList: ((list: ProgressWatchList) => void) | null = null;
  finishWrite: ((detail: ProgressWatchDetail) => void) | null = null;

  list(): ProgressWatchList {
    const list: ProgressWatchList = new ProgressWatchList();
    list.items = [this.current.watch];
    return list;
  }

  async progressWatches(_cancellation?: ReadCancellation): Promise<ProgressWatchList> {
    if (this.holdList) { return new Promise<ProgressWatchList>((resolve) => { this.finishList = resolve; }); }
    return this.list();
  }

  async progressWatch(_id: string): Promise<ProgressWatchDetail> { return this.current; }

  async updateProgressWatch(_id: string, command: ProgressWatchCommand): Promise<ProgressWatchDetail> {
    this.commands.push(command);
    if (this.failure !== null) { throw this.failure; }
    if (this.holdWrite) { return new Promise<ProgressWatchDetail>((resolve) => { this.finishWrite = resolve; }); }
    const updated: ProgressWatchDetail = snapshot();
    updated.watch.revision = command.expectedRevision + 1;
    updated.watch.subscribed = command.subscribed;
    updated.watch.pushEnabled = command.pushEnabled;
    updated.watch.eventKinds = command.eventKinds;
    this.current = updated;
    return updated;
  }
}

async function turn(): Promise<void> {
  await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 0); });
}

export default function progressWatchesTests(): void {
  describe('ProgressWatches', () => {
    it('ignoresAccessAndWriteResultsFromAFormerAccount', 0, async () => {
      const repo: ProgressRepository = new ProgressRepository();
      const model: ProgressWatchViewModel = new ProgressWatchViewModel(repo, () => {});
      model.bindOwner('watcher');
      repo.holdList = true;
      model.setSettingsActive(true);
      model.bindOwner('solver');
      repo.finishList?.(repo.list());
      await turn();
      expect(model.settingsVisible).assertFalse();
      repo.holdList = false;
      model.openPage(WATCH_ID, true);
      await turn();
      model.choose('correct', true);
      repo.holdWrite = true;
      const save: Promise<void> = model.saveSelection();
      model.bindOwner('');
      repo.finishWrite?.(snapshot());
      await save;
      expect(model.detail === null).assertTrue();
      expect(model.draft.length).assertEqual(0);
    });

    it('keepsConsentSeparateAndReusesTheConfirmedRequestOnRetry', 0, async () => {
      const repo: ProgressRepository = new ProgressRepository();
      const model: ProgressWatchViewModel = new ProgressWatchViewModel(repo, () => {});
      model.bindOwner('watcher');
      model.openPage(WATCH_ID, true);
      await turn();
      model.choose('completed', true);
      repo.failure = new GameFailure('TIMEOUT', 'timeout');
      await model.saveSelection();
      expect(model.retryPending).assertTrue();
      model.setPageActive(false);
      model.setPageActive(true);
      expect(model.detail === null).assertTrue();
      expect(model.retryPending).assertTrue();
      repo.failure = null;
      await model.retrySave();
      await turn();
      expect(model.detail?.watch.revision).assertEqual(2);
      expect(repo.commands[0].requestId).assertEqual(repo.commands[1].requestId);
      expect(repo.commands[1].pushEnabled).assertFalse();
      await model.setPush(WATCH_ID, 1, true);
      expect(repo.commands.length).assertEqual(2);
      await model.setPush(WATCH_ID, 2, true);
      expect(repo.commands[2].pushEnabled).assertTrue();
      expect(repo.commands[2].eventKinds[0]).assertEqual('completed');
      model.closePage();
      expect(model.items.length).assertEqual(0);
    });

    it('parsesOnlyWellFormedProgressPushTargets', 0, () => {
      const data: Record<string, Object> = {
        'starwardPushVersion': '1', 'starwardPushKind': 'progress', 'starwardPushEventId': 'progress-test-event',
        'starwardPushProfileId': 'anonymous-profile-id', 'starwardPushTargetId': '../different-player'
      };
      expect(LaunchRoutes.receivePush(PUSH_OPEN_ACTION, data)).assertFalse();
      data['starwardPushTargetId'] = WATCH_ID;
      expect(LaunchRoutes.receivePush(PUSH_OPEN_ACTION, data)).assertTrue();
      const route = LaunchRoutes.nextPush();
      expect(route?.target).assertEqual(WATCH_ID);
      if (route !== null) { LaunchRoutes.consumePush(route); }
      expect(LaunchRoutes.receivePush(PUSH_OPEN_ACTION, data)).assertFalse();
    });
  });
}
