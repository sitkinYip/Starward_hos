import { describe, expect, it } from '@ohos/hypium';
import { GameFailure } from '../main/ets/business/models';
import { GameplaySnapshot } from '../main/ets/business/GameplayModels';
import { MockGameRepository, sampleAssignment, sampleGameplaySnapshot } from '../main/ets/data/MockGameRepository';
import { GameplayViewModel } from '../main/ets/features/GameplayViewModel';

class PendingGameplayCall {
  readonly assignmentId: string;
  readonly requestId: string;
  readonly task: Promise<GameplaySnapshot>;
  private resolve: (value: GameplaySnapshot) => void = (_value: GameplaySnapshot) => {};
  private reject: (error: GameFailure) => void = (_error: GameFailure) => {};

  constructor(assignmentId: string, requestId: string = '') {
    this.assignmentId = assignmentId;
    this.requestId = requestId;
    this.task = new Promise<GameplaySnapshot>((resolve: (value: GameplaySnapshot) => void,
      reject: (error: GameFailure) => void) => {
      this.resolve = resolve;
      this.reject = reject;
    });
  }

  succeed(value: GameplaySnapshot = enteredSnapshot()): void {
    this.resolve(value);
  }

  fail(error: GameFailure): void {
    this.reject(error);
  }
}

// A controllable transport outcome, without reproducing ViewModel routing or retry logic.
class ControlledGameplayRepository extends MockGameRepository {
  entries: PendingGameplayCall[] = [];
  reads: PendingGameplayCall[] = [];

  constructor() {
    super(0);
  }

  async startAssignment(id: string, requestId: string): Promise<GameplaySnapshot> {
    const call: PendingGameplayCall = new PendingGameplayCall(id, requestId);
    this.entries.push(call);
    return call.task;
  }

  async gameplay(id: string): Promise<GameplaySnapshot> {
    const call: PendingGameplayCall = new PendingGameplayCall(id);
    this.reads.push(call);
    return call.task;
  }
}

function enteredSnapshot(id: string = 'assignment1', player: string = 'playeralice'): GameplaySnapshot {
  const detail = sampleAssignment();
  detail.id = id;
  detail.player = player;
  detail.status = 'active';
  detail.startedAt = '2026-11-04T00:00:00.000Z';
  return sampleGameplaySnapshot(detail);
}

class RequestIds {
  generated: number = 0;

  next(): string {
    this.generated++;
    return 'entry-command-' + this.generated;
  }
}

export default function gameplayViewModelTests(): void {
  describe('GameplayViewModel', () => {
    it('duplicateEntryWhileCurrentPageIsBusySendsOnlyOneCommand', 0, async () => {
      const repository: ControlledGameplayRepository = new ControlledGameplayRepository();
      const ids: RequestIds = new RequestIds();
      const viewModel: GameplayViewModel = new GameplayViewModel(repository, () => {}, () => {}, () => ids.next());
      viewModel.bindOwner('playeralice');
      const first: Promise<void> = viewModel.enter('assignment1');
      await viewModel.enter('assignment1');
      await viewModel.enter('another-assignment');
      expect(repository.entries.length).assertEqual(1);
      expect(viewModel.starting).assertTrue();
      repository.entries[0].succeed();
      await first;
      expect(viewModel.starting).assertFalse();
      expect(viewModel.visible).assertTrue();
      expect(viewModel.snapshot?.detail.id).assertEqual('assignment1');
      expect(viewModel.retryEntry).assertFalse();
    });

    it('unknownEntryOutcomeRetriesTheSameIdentityUntilConfirmed', 0, async () => {
      const repository: ControlledGameplayRepository = new ControlledGameplayRepository();
      const ids: RequestIds = new RequestIds();
      const viewModel: GameplayViewModel = new GameplayViewModel(repository, () => {}, () => {}, () => ids.next());
      viewModel.bindOwner('playeralice');
      const first: Promise<void> = viewModel.enter('assignment1');
      repository.entries[0].fail(new GameFailure('TIMEOUT', '等待超时'));
      await first;
      expect(repository.entries.length).assertEqual(1);
      expect(viewModel.retryEntry).assertTrue();
      const second: Promise<void> = viewModel.enter('assignment1');
      repository.entries[1].fail(new GameFailure('CONTRACT_ERROR', '响应无法确认'));
      await second;
      expect(viewModel.snapshot).assertNull();
      expect(viewModel.errorCode).assertEqual('CONTRACT_ERROR');
      const third: Promise<void> = viewModel.enter('assignment1');
      expect(repository.entries[1].requestId).assertEqual(repository.entries[0].requestId);
      expect(repository.entries[2].requestId).assertEqual(repository.entries[0].requestId);
      expect(ids.generated).assertEqual(1);
      repository.entries[2].succeed();
      await third;
      expect(viewModel.error).assertEqual('');
      expect(viewModel.retryEntry).assertFalse();
    });

    it('definiteAdmissionRejectionAllowsANewExplicitCommand', 0, async () => {
      const repository: ControlledGameplayRepository = new ControlledGameplayRepository();
      const ids: RequestIds = new RequestIds();
      const viewModel: GameplayViewModel = new GameplayViewModel(repository, () => {}, () => {}, () => ids.next());
      viewModel.bindOwner('playeralice');
      const first: Promise<void> = viewModel.enter('assignment1');
      repository.entries[0].fail(new GameFailure('NOT_STARTED', '场次尚未开放', 409));
      await first;
      expect(viewModel.retryEntry).assertFalse();
      expect(viewModel.visible).assertFalse();
      expect(viewModel.errorCode).assertEqual('NOT_STARTED');
      const later: Promise<void> = viewModel.enter('assignment1');
      expect(repository.entries[1].requestId === repository.entries[0].requestId).assertFalse();
      expect(ids.generated).assertEqual(2);
      repository.entries[1].succeed();
      await later;
      expect(viewModel.visible).assertTrue();
    });

    it('leavingAndReenteringKeepsTheCurrentRetryIdentityAfterAnOlderSuccess', 0, async () => {
      const repository: ControlledGameplayRepository = new ControlledGameplayRepository();
      const ids: RequestIds = new RequestIds();
      let accepted: number = 0;
      const viewModel: GameplayViewModel = new GameplayViewModel(repository, () => { accepted++; },
        () => {}, () => ids.next());
      viewModel.bindOwner('playeralice');
      const oldPage: Promise<void> = viewModel.enter('assignment1');
      viewModel.leave();
      const newPage: Promise<void> = viewModel.enter('assignment1');
      repository.entries[0].succeed();
      await oldPage;
      expect(accepted).assertEqual(0);
      expect(viewModel.starting).assertTrue();
      repository.entries[1].fail(new GameFailure('TIMEOUT', '确认结果超时'));
      await newPage;
      const retry: Promise<void> = viewModel.enter('assignment1');
      expect(repository.entries[2].requestId).assertEqual(repository.entries[0].requestId);
      expect(ids.generated).assertEqual(1);
      repository.entries[2].succeed();
      await retry;
      expect(accepted).assertEqual(1);
    });

    it('anOlderTerminalResponseDoesNotRetireTheReenteredPagesPendingCommand', 0, async () => {
      const repository: ControlledGameplayRepository = new ControlledGameplayRepository();
      const ids: RequestIds = new RequestIds();
      const viewModel: GameplayViewModel = new GameplayViewModel(repository, () => {}, () => {}, () => ids.next());
      viewModel.bindOwner('playeralice');
      const oldPage: Promise<void> = viewModel.enter('assignment1');
      viewModel.leave();
      const newPage: Promise<void> = viewModel.enter('assignment1');
      repository.entries[0].fail(new GameFailure('NOT_FOUND', '已无法访问', 404));
      await oldPage;
      expect(viewModel.error).assertEqual('');
      expect(viewModel.starting).assertTrue();
      repository.entries[1].fail(new GameFailure('NETWORK_ERROR', '连接中断'));
      await newPage;
      const retry: Promise<void> = viewModel.enter('assignment1');
      expect(repository.entries[2].requestId).assertEqual(repository.entries[0].requestId);
      repository.entries[2].succeed();
      await retry;
      expect(viewModel.visible).assertTrue();
    });

    it('logoutOrOwnerReplacementRejectsLateEntryEvenWhenThePlayerIdIsReused', 0, async () => {
      const owners: string[] = ['playeralice', 'another-player'];
      for (let i: number = 0; i < owners.length; i++) {
        const repository: ControlledGameplayRepository = new ControlledGameplayRepository();
        const ids: RequestIds = new RequestIds();
        let accepted: number = 0;
        const viewModel: GameplayViewModel = new GameplayViewModel(repository, () => { accepted++; },
          () => {}, () => ids.next());
        viewModel.bindOwner('playeralice');
        const oldAccount: Promise<void> = viewModel.enter('assignment1');
        viewModel.reset();
        viewModel.bindOwner(owners[i]);
        const newAccount: Promise<void> = viewModel.enter('assignment1');
        repository.entries[0].succeed();
        await oldAccount;
        expect(viewModel.snapshot).assertNull();
        expect(accepted).assertEqual(0);
        expect(viewModel.starting).assertTrue();
        expect(repository.entries[1].requestId === repository.entries[0].requestId).assertFalse();
        repository.entries[1].succeed(enteredSnapshot('assignment1', owners[i]));
        await newAccount;
        expect(viewModel.snapshot?.detail.player).assertEqual(owners[i]);
        expect(accepted).assertEqual(1);
      }
    });

    it('reopeningAfterAnUnknownWriteUsesTheFreshReadWithoutStartingAgain', 0, async () => {
      const repository: ControlledGameplayRepository = new ControlledGameplayRepository();
      const ids: RequestIds = new RequestIds();
      const viewModel: GameplayViewModel = new GameplayViewModel(repository, () => {}, () => {}, () => ids.next());
      viewModel.bindOwner('playeralice');
      const entry: Promise<void> = viewModel.enter('assignment1');
      repository.entries[0].fail(new GameFailure('TIMEOUT', '结果待确认'));
      await entry;
      viewModel.leave();
      const reopened: Promise<void> = viewModel.open('assignment1');
      expect(repository.entries.length).assertEqual(1);
      expect(repository.reads.length).assertEqual(1);
      const authoritative: GameplaySnapshot = enteredSnapshot();
      authoritative.detail.title = '服务端确认已入场';
      repository.reads[0].succeed(authoritative);
      await reopened;
      expect(viewModel.snapshot?.detail.title).assertEqual('服务端确认已入场');
      expect(viewModel.visible).assertTrue();
      expect(viewModel.loading).assertFalse();
      expect(viewModel.error).assertEqual('');
      expect(repository.entries.length).assertEqual(1);
    });

    it('wrongIdentityAndUnconfirmedSuccessKeepTheOriginalEntryCommand', 0, async () => {
      const repository: ControlledGameplayRepository = new ControlledGameplayRepository();
      const ids: RequestIds = new RequestIds();
      const viewModel: GameplayViewModel = new GameplayViewModel(repository, () => {}, () => {}, () => ids.next());
      viewModel.bindOwner('playeralice');
      const variants: GameplaySnapshot[] = [enteredSnapshot('wrong-assignment'),
        enteredSnapshot('assignment1', 'wrong-player'), enteredSnapshot(), enteredSnapshot()];
      variants[2].detail.startedAt = '';
      variants[3].detail.status = 'assigned';
      for (let i: number = 0; i < variants.length; i++) {
        const pending: Promise<void> = viewModel.enter('assignment1');
        repository.entries[i].succeed(variants[i]);
        await pending;
        expect(viewModel.errorCode).assertEqual('CONTRACT_ERROR');
        expect(viewModel.retryEntry).assertTrue();
        expect(viewModel.snapshot).assertNull();
        expect(repository.entries[i].requestId).assertEqual(repository.entries[0].requestId);
      }
      const confirmed: Promise<void> = viewModel.enter('assignment1');
      expect(ids.generated).assertEqual(1);
      repository.entries[4].succeed();
      await confirmed;
      expect(viewModel.visible).assertTrue();
    });

    it('authenticationFailuresAreReportedToTheOwningSession', 0, async () => {
      const failures: GameFailure[] = [new GameFailure('UNAUTHORIZED', '登录已过期', 401),
        new GameFailure('ACCOUNT_DISABLED', '账号已停用', 403),
        new GameFailure('PASSWORD_CHANGE_REQUIRED', '请先修改初始密码', 403)];
      for (let i: number = 0; i < failures.length; i++) {
        const repository: ControlledGameplayRepository = new ControlledGameplayRepository();
        const messages: string[] = [];
        const viewModel: GameplayViewModel = new GameplayViewModel(repository, () => {},
          (message: string) => { messages.push(message); }, () => 'auth-command');
        viewModel.bindOwner('playeralice');
        const pending: Promise<void> = viewModel.enter('assignment1');
        repository.entries[0].fail(failures[i]);
        await pending;
        expect(messages.length).assertEqual(1);
        expect(messages[0]).assertEqual(failures[i].message);
        expect(viewModel.snapshot).assertNull();
        expect(viewModel.starting).assertFalse();
        expect(viewModel.retryEntry).assertFalse();
      }
    });

    it('aLateReadCannotReopenAPageThatTheUserHasLeft', 0, async () => {
      const repository: ControlledGameplayRepository = new ControlledGameplayRepository();
      let accepted: number = 0;
      const viewModel: GameplayViewModel = new GameplayViewModel(repository, () => { accepted++; },
        () => {}, () => 'unused-command');
      viewModel.bindOwner('playeralice');
      const pending: Promise<void> = viewModel.open('assignment1');
      expect(viewModel.loading).assertTrue();
      viewModel.leave();
      repository.reads[0].succeed();
      await pending;
      expect(viewModel.visible).assertFalse();
      expect(viewModel.snapshot).assertNull();
      expect(viewModel.loading).assertFalse();
      expect(accepted).assertEqual(0);
      expect(repository.entries.length).assertEqual(0);
    });
  });
}
