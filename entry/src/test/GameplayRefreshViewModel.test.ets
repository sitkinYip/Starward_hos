import { describe, expect, it } from '@ohos/hypium';
import { GameplayAnswerResult, GameplaySnapshot } from '../main/ets/business/GameplayModels';
import { GameFailure } from '../main/ets/business/models';
import { ReadCancellation } from '../main/ets/business/ReadCancellation';
import { decodeGameplay } from '../main/ets/data/GameplayDecoder';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { GameplayViewModel } from '../main/ets/features/GameplayViewModel';
import { GAMEPLAY_CANCELLED_STARTED_JSON, GAMEPLAY_CHOICE_JSON, GAMEPLAY_COMPLETED_JSON,
  GAMEPLAY_STARTED_JSON } from './fixtures/GameplayFixture';

class ReadCall {
  readonly task: Promise<GameplaySnapshot>;
  private resolve: (value: GameplaySnapshot) => void = () => {};
  private reject: (error: GameFailure) => void = () => {};

  constructor() {
    this.task = new Promise<GameplaySnapshot>((resolve: (value: GameplaySnapshot) => void,
      reject: (error: GameFailure) => void) => { this.resolve = resolve; this.reject = reject; });
  }

  succeed(value: GameplaySnapshot): void { this.resolve(value); }
  fail(error: GameFailure): void { this.reject(error); }
}

class RefreshRepository extends MockGameRepository {
  reads: ReadCall[] = [];
  cancellations: (ReadCancellation | undefined)[] = [];
  entries: ReadCall[] = [];
  answerWrites: number = 0;

  constructor() { super(0); }

  async gameplay(_id: string, cancellation?: ReadCancellation): Promise<GameplaySnapshot> {
    const call: ReadCall = new ReadCall();
    this.reads.push(call);
    this.cancellations.push(cancellation);
    return call.task;
  }

  async startAssignment(_id: string, _requestId: string): Promise<GameplaySnapshot> {
    const call: ReadCall = new ReadCall();
    this.entries.push(call);
    return call.task;
  }

  async answerAssignment(_id: string, _level: string, _answer: string, _requestId: string): Promise<GameplayAnswerResult> {
    this.answerWrites++;
    throw new GameFailure('UNEXPECTED_TEST_WRITE', '刷新期间不应写入');
  }
}

function snapshot(source: string = GAMEPLAY_STARTED_JSON, player: string = 'playeralice'): GameplaySnapshot {
  const value: GameplaySnapshot = decodeGameplay(source);
  value.detail.serverTime = new Date().toISOString();
  value.detail.player = player;
  return value;
}

async function open(vm: GameplayViewModel, repository: RefreshRepository,
  value: GameplaySnapshot = snapshot()): Promise<void> {
  const pending: Promise<void> = vm.open('assignment1');
  repository.reads[repository.reads.length - 1].succeed(value);
  await pending;
}

async function waitForReads(repository: RefreshRepository, count: number): Promise<void> {
  const deadline: number = Date.now() + 6500;
  while (repository.reads.length < count && Date.now() < deadline) {
    await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 15); });
  }
  expect(repository.reads.length).assertEqual(count);
}

export default function gameplayRefreshViewModelTests(): void {
  describe('GameplayRefreshViewModel', () => {
    it('pullSupersedesAnInFlightPollAndIgnoresItsLateFatalResponse', 0, async () => {
      const repository: RefreshRepository = new RefreshRepository();
      let authenticationFailures: number = 0;
      const vm: GameplayViewModel = new GameplayViewModel(repository, () => {}, () => { authenticationFailures++; });
      vm.bindOwner('playeralice');
      await open(vm, repository);
      try {
        vm.setPollingActive(true);
        await waitForReads(repository, 2);
        expect(vm.refreshing).assertFalse();
        expect(vm.answerAllowed()).assertTrue();
        vm.editAnswer(' 原草稿 ');
        const manual: Promise<void> = vm.refresh();
        expect(repository.cancellations[1]?.cancelled).assertTrue();
        expect(repository.reads.length).assertEqual(3);
        const fresh: GameplaySnapshot = snapshot();
        fresh.detail.title = '最新快照';
        repository.reads[2].succeed(fresh);
        await manual;
        repository.reads[1].fail(new GameFailure('UNAUTHORIZED', '旧请求失败', 401));
        await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 0); });
        expect(vm.snapshot === fresh).assertTrue();
        expect(vm.draftAnswer).assertEqual(' 原草稿 ');
        expect(vm.error).assertEqual('');
        expect(vm.syncEpisode).assertEqual(0);
        expect(authenticationFailures).assertEqual(0);
        expect(vm.completionRevision).assertEqual(0);
        expect(repository.answerWrites).assertEqual(0);
      } finally {
        vm.leave();
      }
    });

    it('singleRefreshKeepsTheSnapshotAndLatestRawDraftWithoutWritingOrRemountIdentityChange', 0, async () => {
      const repository: RefreshRepository = new RefreshRepository();
      let identities: number = 0;
      const vm: GameplayViewModel = new GameplayViewModel(repository, () => {}, () => {}, () => `id-${++identities}`);
      vm.bindOwner('playeralice');
      const before: GameplaySnapshot = snapshot();
      await open(vm, repository, before);
      vm.editAnswer(' 原草稿 ');
      const pending: Promise<void> = vm.refresh();
      await vm.refresh();
      await vm.open('assignment1');
      await vm.enter('assignment1');
      expect(repository.reads.length).assertEqual(2);
      expect(repository.entries.length).assertEqual(0);
      expect(vm.snapshot === before).assertTrue();
      expect(vm.refreshing).assertTrue();
      expect(vm.loading).assertFalse();
      expect(vm.visible).assertTrue();
      expect(vm.answerEditable()).assertTrue();
      expect(vm.answerAllowed()).assertFalse();
      vm.editAnswer(' 最新 草稿 ');
      await vm.submitAnswer();
      expect(repository.answerWrites).assertEqual(0);
      expect(identities).assertEqual(0);
      repository.reads[1].succeed(snapshot());
      await pending;
      expect(vm.refreshing).assertFalse();
      expect(vm.currentLevel()?.id).assertEqual(before.levels[0].id);
      expect(vm.draftAnswer).assertEqual(' 最新 草稿 ');
      expect(vm.answerAllowed()).assertTrue();
      vm.leave();
    });

    it('temporaryReadFailureKeepsTrustedFactsAndAllowsAnExplicitGetRetry', 0, async () => {
      const failures: GameFailure[] = [new GameFailure('NETWORK_ERROR', '断网'), new GameFailure('TIMEOUT', '超时'),
        new GameFailure('REQUEST_TIMEOUT', '稍后再试', 408), new GameFailure('RATE_LIMITED', '稍后再试', 429),
        new GameFailure('UNAVAILABLE', '稍后再试', 503)];
      for (let i: number = 0; i < failures.length; i++) {
        const repository: RefreshRepository = new RefreshRepository();
        const vm: GameplayViewModel = new GameplayViewModel(repository);
        vm.bindOwner('playeralice');
        const before: GameplaySnapshot = snapshot();
        await open(vm, repository, before);
        vm.editAnswer(' 未提交原文 ');
        const failed: Promise<void> = vm.refresh();
        repository.reads[1].fail(failures[i]);
        await failed;
        expect(vm.snapshot === before).assertTrue();
        expect(vm.draftAnswer).assertEqual(' 未提交原文 ');
        expect(vm.error).assertEqual('');
        expect(vm.refreshError).assertEqual(failures[i].message);
        expect(vm.canRefresh()).assertTrue();
        expect(repository.reads.length).assertEqual(2);
        const retry: Promise<void> = vm.refresh();
        expect(vm.refreshError).assertEqual('');
        repository.reads[2].succeed(snapshot());
        await retry;
        expect(vm.refreshError).assertEqual('');
        expect(vm.draftAnswer).assertEqual(' 未提交原文 ');
        expect(repository.answerWrites).assertEqual(0);
        vm.leave();
      }
    });

    it('fatalReadErrorsClearPrivateFactsAndDraftCacheBeforeReporting', 0, async () => {
      const failures: GameFailure[] = [new GameFailure('UNAUTHORIZED', '请登录', 401),
        new GameFailure('FORBIDDEN', '不可访问', 403), new GameFailure('NOT_FOUND', '不存在', 404),
        new GameFailure('GONE', '已下线', 410), new GameFailure('CONTRACT_ERROR', '契约不符', 503)];
      for (let i: number = 0; i < failures.length; i++) {
        const repository: RefreshRepository = new RefreshRepository();
        let authenticationFailures: number = 0;
        const vm: GameplayViewModel = new GameplayViewModel(repository, () => {}, () => { authenticationFailures++; });
        vm.bindOwner('playeralice');
        await open(vm, repository);
        vm.editAnswer(' 私密旧草稿 ');
        const pending: Promise<void> = vm.refresh();
        repository.reads[1].fail(failures[i]);
        await pending;
        expect(vm.snapshot).assertNull();
        expect(vm.draftAnswer).assertEqual('');
        expect(vm.refreshing).assertFalse();
        expect(vm.refreshError).assertEqual('');
        expect(vm.errorCode).assertEqual(failures[i].code);
        expect(authenticationFailures).assertEqual(i === 0 ? 1 : 0);
        const retry: Promise<void> = vm.reload();
        repository.reads[2].succeed(snapshot());
        await retry;
        expect(vm.draftAnswer).assertEqual('');
        vm.leave();
      }
    });

    it('foreignSuccessfulReadIsRejectedBeforePublishingAnySnapshot', 0, async () => {
      const repository: RefreshRepository = new RefreshRepository();
      let accepted: number = 0;
      const vm: GameplayViewModel = new GameplayViewModel(repository, () => { accepted++; });
      vm.bindOwner('playeralice');
      await open(vm, repository);
      const pending: Promise<void> = vm.refresh();
      repository.reads[1].succeed(snapshot(GAMEPLAY_STARTED_JSON, 'other-player'));
      await pending;
      expect(accepted).assertEqual(1);
      expect(vm.snapshot).assertNull();
      expect(vm.errorCode).assertEqual('CONTRACT_ERROR');
      vm.leave();
    });

    it('refreshKeepsManualQuestionAndNextAvailabilityWhileBlockingMovement', 0, async () => {
      const repository: RefreshRepository = new RefreshRepository();
      const vm: GameplayViewModel = new GameplayViewModel(repository);
      vm.bindOwner('playeralice');
      await open(vm, repository, snapshot(GAMEPLAY_CHOICE_JSON));
      vm.moveTo(0);
      const levelId: string = vm.currentLevel()?.id || '';
      const pending: Promise<void> = vm.refresh();
      expect(vm.canMoveTo(1)).assertTrue();
      vm.moveTo(1);
      vm.nextQuestion();
      expect(vm.activeIndex).assertEqual(0);
      repository.reads[1].succeed(snapshot(GAMEPLAY_COMPLETED_JSON));
      await pending;
      expect(vm.currentLevel()?.id).assertEqual(levelId);
      expect(vm.activeIndex).assertEqual(0);
      expect(vm.answerEditable()).assertFalse();
      expect(vm.completionRevision).assertEqual(0);
      expect(vm.advancing).assertFalse();
      const cancelled: Promise<void> = vm.refresh();
      repository.reads[2].succeed(snapshot(GAMEPLAY_CANCELLED_STARTED_JSON));
      await cancelled;
      expect(vm.snapshot?.detail.status).assertEqual('cancelled');
      expect(vm.currentLevel()?.question).assertNull();
      expect(vm.answerAllowed()).assertFalse();
      expect(vm.completionRevision).assertEqual(0);
      vm.leave();
    });

    it('entryPendingAndUnconfirmedEntryCannotStartARefreshGet', 0, async () => {
      const repository: RefreshRepository = new RefreshRepository();
      const vm: GameplayViewModel = new GameplayViewModel(repository);
      vm.bindOwner('playeralice');
      await open(vm, repository);
      const pending: Promise<void> = vm.enter('assignment1');
      await vm.refresh();
      expect(repository.reads.length).assertEqual(1);
      repository.entries[0].fail(new GameFailure('TIMEOUT', '入场结果待确认'));
      await pending;
      expect(vm.retryEntry).assertTrue();
      await vm.refresh();
      expect(repository.reads.length).assertEqual(1);
      vm.leave();
    });

    it('leftOrReplacedAccountsIgnoreLateRefreshSuccessErrorAndFinally', 0, async () => {
      for (let scenario: number = 0; scenario < 3; scenario++) {
        for (let failure: number = 0; failure < 2; failure++) {
          const repository: RefreshRepository = new RefreshRepository();
          let accepted: number = 0;
          let authenticationFailures: number = 0;
          const vm: GameplayViewModel = new GameplayViewModel(repository, () => { accepted++; },
            () => { authenticationFailures++; });
          vm.bindOwner('playeralice');
          await open(vm, repository);
          const old: Promise<void> = vm.refresh();
          const player: string = scenario === 2 ? 'other-player' : 'playeralice';
          if (scenario === 0) { vm.leave(); } else { vm.reset(); vm.bindOwner(player); }
          expect(vm.refreshing).assertFalse();
          expect(vm.refreshError).assertEqual('');
          const fresh: GameplaySnapshot = snapshot(GAMEPLAY_STARTED_JSON, player);
          await open(vm, repository, fresh);
          const current: Promise<void> = vm.refresh();
          if (failure === 0) { repository.reads[1].succeed(snapshot()); }
          else { repository.reads[1].fail(new GameFailure('UNAUTHORIZED', '旧账号失效', 401)); }
          await old;
          expect(vm.snapshot === fresh).assertTrue();
          expect(vm.refreshing).assertTrue();
          expect(vm.error).assertEqual('');
          expect(authenticationFailures).assertEqual(0);
          expect(accepted).assertEqual(2);
          repository.reads[3].succeed(snapshot(GAMEPLAY_STARTED_JSON, player));
          await current;
          expect(vm.refreshing).assertFalse();
          expect(accepted).assertEqual(3);
          vm.leave();
        }
      }
    });
  });
}
