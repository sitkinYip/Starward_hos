import { describe, expect, it } from '@ohos/hypium';
import { GameFailure } from '../main/ets/business/models';
import { ProgressAttempt, ProgressWatchCommand, ProgressWatchDetail, ProgressWatchList } from '../main/ets/business/ProgressWatch';
import { ReadCancellation } from '../main/ets/business/ReadCancellation';
import { decodeProgressWatchDetail } from '../main/ets/data/DtoDecoder';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { ProgressWatchViewModel } from '../main/ets/features/ProgressWatchViewModel';
import { LaunchRoutes, PUSH_OPEN_ACTION } from '../main/ets/platform/LaunchRoutes';

const WATCH_ID: string = 'progresswatch01';
const OTHER_ID: string = 'progresswatch02';
const UNKNOWN_ID: string = 'progresswatch03';
const LATER: string = '2099-01-01T00:00:00.000Z';

function snapshot(id: string = WATCH_ID, expiresAt: string = LATER): ProgressWatchDetail {
  const detail: ProgressWatchDetail = new ProgressWatchDetail();
  detail.watch.id = id;
  detail.watch.expiresAt = expiresAt;
  detail.watch.status = 'assigned';
  detail.watch.assignmentId = 'assigned';
  detail.watch.playerName = '测试玩家';
  detail.watch.title = '测试场次';
  detail.watch.revision = 1;
  detail.pushAvailable = true;
  return detail;
}

class ProgressRepository extends MockGameRepository {
  current: ProgressWatchDetail = snapshot();
  other: ProgressWatchDetail | null = null;
  readIds: string[] = [];
  commands: ProgressWatchCommand[] = [];
  listFailure: GameFailure | null = null;
  detailFailure: GameFailure | null = null;
  failure: GameFailure | null = null;
  holdList: boolean = false;
  holdWrite: boolean = false;
  finishList: ((list: ProgressWatchList) => void) | null = null;
  finishWrite: ((detail: ProgressWatchDetail) => void) | null = null;

  list(): ProgressWatchList {
    const list: ProgressWatchList = new ProgressWatchList();
    list.items = this.other !== null ? [this.current.watch, this.other.watch] : [this.current.watch];
    return list;
  }

  async progressWatches(_cancellation?: ReadCancellation): Promise<ProgressWatchList> {
    if (this.listFailure !== null) { throw this.listFailure; }
    if (this.holdList) { return new Promise<ProgressWatchList>((resolve) => { this.finishList = resolve; }); }
    return this.list();
  }

  async progressWatch(id: string): Promise<ProgressWatchDetail> {
    this.readIds.push(id);
    if (this.detailFailure !== null) { throw this.detailFailure; }
    const other: ProgressWatchDetail | null = this.other;
    return other !== null && id === other.watch.id ? other : this.current;
  }

  async updateProgressWatch(_id: string, command: ProgressWatchCommand): Promise<ProgressWatchDetail> {
    this.commands.push(command);
    if (this.failure !== null) { throw this.failure; }
    if (this.holdWrite) { return new Promise<ProgressWatchDetail>((resolve) => { this.finishWrite = resolve; }); }
    const updated: ProgressWatchDetail = snapshot(this.current.watch.id, this.current.watch.expiresAt);
    updated.watch.revision = command.expectedRevision + 1;
    updated.watch.subscribed = command.subscribed;
    updated.watch.pushEnabled = command.pushEnabled;
    updated.watch.eventKinds = command.eventKinds;
    this.current = updated;
    return updated;
  }
}

async function turn(delay: number = 0): Promise<void> {
  await new Promise<void>((resolve: () => void) => { setTimeout(resolve, delay); });
}

export default function progressWatchesTests(): void {
  describe('ProgressWatches', () => {
    it('keepsSettingsAvailableWhenOptionalProgressAccessFails', 0, async () => {
      const repo: ProgressRepository = new ProgressRepository();
      const rejected: Object[] = [];
      const model: ProgressWatchViewModel = new ProgressWatchViewModel(repo, (error: Object) => { rejected.push(error); });
      const optionalFailures: GameFailure[] = [
        new GameFailure('NOT_FOUND', '旧版服务', 404),
        new GameFailure('FORBIDDEN', '没有进度授权', 403),
        new GameFailure('TIMEOUT', '查询超时'),
        new GameFailure('SERVER_ERROR', '服务暂不可用', 503)
      ];
      model.bindOwner('watcher');
      try {
        for (const failure of optionalFailures) {
          repo.listFailure = failure;
          model.setSettingsActive(true);
          await turn();
          expect(model.settingsVisible).assertFalse();
          expect(rejected.length).assertEqual(0);
        }
        repo.listFailure = null;
        model.setSettingsActive(true);
        await turn();
        expect(model.settingsVisible).assertTrue();
      } finally {
        model.setSettingsActive(false);
      }
    });

    it('reportsRealPlayerSessionFailuresFromSettingsAccess', 0, async () => {
      const repo: ProgressRepository = new ProgressRepository();
      const rejected: Object[] = [];
      const model: ProgressWatchViewModel = new ProgressWatchViewModel(repo, (error: Object) => { rejected.push(error); });
      const sessionFailures: GameFailure[] = [
        new GameFailure('AUTH_REQUIRED', '请重新登录', 401),
        new GameFailure('ACCOUNT_DISABLED', '账号停用', 403),
        new GameFailure('PASSWORD_CHANGE_REQUIRED', '请修改密码', 403)
      ];
      model.bindOwner('watcher');
      for (const failure of sessionFailures) {
        repo.listFailure = failure;
        model.setSettingsActive(true);
        await turn();
      }
      expect(rejected.length).assertEqual(sessionFailures.length);
      expect(sessionFailures.every((failure: GameFailure, index: number) => rejected[index] === failure)).assertTrue();
    });

    it('keepsAnExpiredDetailGrantLocalAndReportsARealSessionFailure', 0, async () => {
      const repo: ProgressRepository = new ProgressRepository();
      const rejected: Object[] = [];
      const model: ProgressWatchViewModel = new ProgressWatchViewModel(repo, (error: Object) => { rejected.push(error); });
      model.bindOwner('watcher');
      repo.detailFailure = new GameFailure('NOT_FOUND', '场次授权失效', 404);
      model.openPage(true);
      try {
        await turn();
        expect(repo.readIds[0]).assertEqual(WATCH_ID);
        expect(model.detail === null).assertTrue();
        expect(model.readError).assertEqual('场次授权失效');
        expect(rejected.length).assertEqual(0);

        const expiredSession: GameFailure = new GameFailure('AUTH_REQUIRED', '请重新登录', 401);
        repo.detailFailure = expiredSession;
        await model.refresh();
        expect(rejected.length).assertEqual(1);
        expect(rejected[0] === expiredSession).assertTrue();
      } finally {
        model.closePage();
      }
    });

    it('keepsAWritePermissionFailureLocalAndReportsARealSessionFailure', 0, async () => {
      const repo: ProgressRepository = new ProgressRepository();
      const rejected: Object[] = [];
      const model: ProgressWatchViewModel = new ProgressWatchViewModel(repo, (error: Object) => { rejected.push(error); });
      model.bindOwner('watcher');
      model.openPage(true);
      try {
        await turn();
        model.choose('correct', true);
        repo.failure = new GameFailure('FORBIDDEN', '不能修改此订阅', 403);
        await model.saveSelection();
        expect(repo.commands.length).assertEqual(1);
        expect(model.writeError).assertEqual('不能修改此订阅');
        expect(model.retryPending).assertFalse();
        expect(rejected.length).assertEqual(0);

        const disabled: GameFailure = new GameFailure('ACCOUNT_DISABLED', '账号停用', 403);
        repo.failure = disabled;
        await model.saveSelection();
        expect(repo.commands.length).assertEqual(2);
        expect(rejected.length).assertEqual(1);
        expect(rejected[0] === disabled).assertTrue();
      } finally {
        model.closePage();
      }
    });

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
      model.openPage(true);
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
      let sessionRejections: number = 0;
      const model: ProgressWatchViewModel = new ProgressWatchViewModel(repo, () => { sessionRejections++; });
      model.bindOwner('watcher');
      model.openPage(true);
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

      repo.failure = new GameFailure('TIMEOUT', 'timeout');
      await model.setPush(WATCH_ID, 3, false);
      expect(model.retryPending).assertTrue();
      repo.holdList = true;
      model.selectFromPush(WATCH_ID, true);
      expect(model.loading).assertTrue();
      repo.failure = null;
      await model.retrySave();
      expect(repo.commands.length).assertEqual(4);
      repo.holdList = false;
      repo.finishList?.(repo.list());
      await turn();
      await model.retrySave();
      expect(repo.commands[4].requestId).assertEqual(repo.commands[3].requestId);
      expect(model.detail?.watch.pushEnabled).assertFalse();
      model.closePage();
      expect(model.items.length).assertEqual(0);
      expect(sessionRejections).assertEqual(0);
    });

    it('defersPushTargetDuringSaveAndBackgroundThenAuthorizesTheTarget', 0, async () => {
      const repo: ProgressRepository = new ProgressRepository();
      repo.other = snapshot(OTHER_ID);
      const model: ProgressWatchViewModel = new ProgressWatchViewModel(repo, () => {});
      model.bindOwner('watcher');
      model.openPage(true);
      try {
        await turn();
        model.choose('correct', true);
        repo.holdWrite = true;
        const saving: Promise<void> = model.saveSelection();
        model.selectFromPush(OTHER_ID, true);
        expect(model.selectedId).assertEqual(WATCH_ID);
        model.setPageActive(false);
        repo.finishWrite?.(snapshot());
        await saving;
        expect(model.selectedId).assertEqual(WATCH_ID);
        expect(model.detail === null).assertTrue();
        model.setPageActive(true);
        await turn();
        expect(model.detail?.watch.id).assertEqual(OTHER_ID);
        expect(repo.readIds.join(',')).assertEqual(`${WATCH_ID},${OTHER_ID}`);

        model.choose('correct', true);
        const otherSave: Promise<void> = model.saveSelection();
        model.selectFromPush(WATCH_ID, true);
        repo.finishWrite?.(snapshot(OTHER_ID));
        await otherSave;
        await turn();
        expect(model.detail?.watch.id).assertEqual(WATCH_ID);

        model.selectFromPush(UNKNOWN_ID, true);
        await turn();
        expect(model.detail === null).assertTrue();
        expect(repo.readIds.length).assertEqual(3);
      } finally {
        model.closePage();
      }
    });

    it('appliesLatestPushBeforeMountAndClearsTheTargetOnAccountSwitch', 0, async () => {
      const repo: ProgressRepository = new ProgressRepository();
      repo.other = snapshot(OTHER_ID);
      const model: ProgressWatchViewModel = new ProgressWatchViewModel(repo, () => {});
      model.bindOwner('watcher');
      model.selectFromPush(WATCH_ID, false);
      model.selectFromPush(OTHER_ID, true);
      model.openPage(true);
      try {
        await turn();
        expect(model.detail?.watch.id).assertEqual(OTHER_ID);
        model.setPageActive(false);
        model.selectFromPush(OTHER_ID, true);
        model.bindOwner('other watcher');
        model.openPage(true);
        await turn();
        expect(model.detail?.watch.id).assertEqual(WATCH_ID);
      } finally {
        model.closePage();
      }
    });

    it('requiresCurrentSavedEventsForConsentAndRetainsDraftWhenTurningOffPush', 0, async () => {
      const repo: ProgressRepository = new ProgressRepository();
      repo.current.watch.eventKinds = ['correct'];
      repo.current.watch.subscribed = true;
      const model: ProgressWatchViewModel = new ProgressWatchViewModel(repo, () => {});
      model.bindOwner('watcher');
      model.openPage(true);
      try {
        await turn();
        model.choose('completed', true);
        expect(model.hasUnsavedSelection()).assertTrue();
        await model.setPush(WATCH_ID, 1, true);
        expect(repo.commands.length).assertEqual(0);
        expect(model.draft.join(',')).assertEqual('correct,completed');
        await model.saveSelection();
        expect(model.hasUnsavedSelection()).assertFalse();
        await model.setPush(WATCH_ID, 1, true);
        expect(repo.commands.length).assertEqual(1);
        await model.setPush(WATCH_ID, 2, true);
        expect(repo.commands[1].eventKinds.join(',')).assertEqual('correct,completed');
        model.choose('incorrect', true);
        await model.setPush(WATCH_ID, 3, false);
        expect(repo.commands[2].eventKinds.join(',')).assertEqual('correct,completed');
        expect(model.draft.join(',')).assertEqual('correct,incorrect,completed');
        expect(model.hasUnsavedSelection()).assertTrue();
        await model.refresh();
        expect(model.draft.join(',')).assertEqual('correct,incorrect,completed');
      } finally {
        model.closePage();
      }
    });

    it('expiresVisibleGrantsAndDoesNotBringBackDetailsAfterAnInFlightSave', 0, async () => {
      const repo: ProgressRepository = new ProgressRepository();
      const soon: number = Date.now() + 400;
      const later: number = soon + 250;
      repo.current = snapshot(WATCH_ID, new Date(soon).toISOString());
      repo.other = snapshot(OTHER_ID, new Date(later).toISOString());
      const model: ProgressWatchViewModel = new ProgressWatchViewModel(repo, () => {});
      model.bindOwner('watcher');
      model.setSettingsActive(true);
      model.openPage(true);
      try {
        await turn();
        expect(model.settingsVisible).assertTrue();
        expect(model.detail?.watch.id).assertEqual(WATCH_ID);
        model.choose('correct', true);
        repo.holdWrite = true;
        const saving: Promise<void> = model.saveSelection();
        await turn(Math.max(0, soon - Date.now() + 10));
        expect(model.detail === null).assertTrue();
        expect(model.items.length).assertEqual(1);
        expect(model.items[0]?.id).assertEqual(OTHER_ID);
        expect(model.settingsVisible).assertTrue();
        repo.finishWrite?.(snapshot());
        await saving;
        expect(model.detail === null).assertTrue();
        expect(model.retryPending).assertFalse();
        await turn(Math.max(0, later - Date.now() + 10));
        expect(model.settingsVisible).assertFalse();
        expect(model.items.length).assertEqual(0);
      } finally {
        model.closePage();
        model.setSettingsActive(false);
      }
    });

    it('decodesOnlyWrongAttemptContentAndAcceptsLegacyAttemptRows', 0, () => {
      const response: ProgressWatchDetail = snapshot();
      const row: Record<string, Object> = {
        'id': 'attempt', 'position': 1, 'result': 'incorrect', 'submittedAt': '2026-11-26T08:00:00.000Z'
      };
      const payload: Record<string, Object> = {
        'watch': response.watch, 'pushAvailable': true, 'solved': 0, 'total': 2, 'currentPosition': 1,
        'completedAt': '', 'recent': [row]
      };
      const legacy: string = JSON.stringify(payload);
      expect(decodeProgressWatchDetail(legacy, WATCH_ID).recent[0].submittedAnswer).assertEqual('');
      row['submittedAnswer'] = 'B';
      row['submittedOptionLabel'] = '第二个选项';
      const updated: ProgressAttempt = decodeProgressWatchDetail(JSON.stringify(payload), WATCH_ID).recent[0];
      expect(updated.submittedAnswer).assertEqual('B');
      expect(updated.submittedOptionLabel).assertEqual('第二个选项');
      row['result'] = 'correct';
      let rejected: boolean = false;
      try {
        decodeProgressWatchDetail(JSON.stringify(payload), WATCH_ID);
      } catch (error) {
        rejected = error instanceof GameFailure;
      }
      expect(rejected).assertTrue();
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
