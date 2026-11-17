import { describe, expect, it } from '@ohos/hypium';
import { AssignmentSummary, GameFailure, Player } from '../main/ets/business/models';
import { ReadCancellation } from '../main/ets/business/ReadCancellation';
import { MockGameRepository, sampleAssignment } from '../main/ets/data/MockGameRepository';
import { SliceViewModel } from '../main/ets/features/SliceViewModel';

const INTERVAL_MS: number = 30;

class LobbyCall<T> {
  readonly task: Promise<T>;
  private resolve: (value: T) => void = () => {};
  private reject: (error: GameFailure) => void = () => {};
  readonly cancellation: ReadCancellation;

  constructor(cancellation: ReadCancellation) {
    this.cancellation = cancellation;
    this.task = new Promise<T>((resolve: (value: T) => void, reject: (error: GameFailure) => void) => {
      this.resolve = resolve;
      this.reject = reject;
    });
  }

  succeed(value: T): void { this.resolve(value); }
  fail(error: GameFailure): void { this.reject(error); }
}

class LobbyRepository extends MockGameRepository {
  readonly playerReads: LobbyCall<Player>[] = [];
  readonly assignmentReads: LobbyCall<AssignmentSummary[]>[] = [];
  manualList: AssignmentSummary[] | null = null;

  constructor() { super(0); }

  async me(cancellation?: ReadCancellation): Promise<Player> {
    if (cancellation === undefined) { return super.me(); }
    this.calls.push('me');
    const call: LobbyCall<Player> = new LobbyCall<Player>(cancellation);
    this.playerReads.push(call);
    return call.task;
  }

  async assignments(cancellation?: ReadCancellation): Promise<AssignmentSummary[]> {
    if (cancellation === undefined) {
      if (this.manualList === null) { return super.assignments(); }
      this.calls.push('assignments');
      return this.manualList;
    }
    this.calls.push('assignments');
    const call: LobbyCall<AssignmentSummary[]> = new LobbyCall<AssignmentSummary[]>(cancellation);
    this.assignmentReads.push(call);
    return call.task;
  }
}

function player(name: string, forcePassword: boolean = false): Player {
  const value: Player = new Player();
  value.id = 'playeralice';
  value.displayName = name;
  value.totalXp = 120;
  value.level.order = 2;
  value.mustChangePassword = forcePassword;
  return value;
}

function assignments(id: string): AssignmentSummary[] {
  const row: AssignmentSummary = sampleAssignment();
  row.id = id;
  row.completedLevels = 1;
  return [row];
}

function wait(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void) => { setTimeout(resolve, ms); });
}

async function waitUntil(predicate: () => boolean): Promise<void> {
  const deadline: number = Date.now() + 1000;
  while (!predicate() && Date.now() < deadline) { await wait(5); }
  expect(predicate()).assertTrue();
}

async function waitForPair(repository: LobbyRepository, count: number): Promise<void> {
  await waitUntil(() => repository.playerReads.length === count && repository.assignmentReads.length === count);
}

async function enterHome(vm: SliceViewModel, repository: LobbyRepository): Promise<void> {
  await vm.login('alice', 'Starward1234');
  await vm.changePassword('Starward1234', 'NewStarward1234', 'NewStarward1234');
  expect(vm.gate).assertEqual('home');
  repository.calls.length = 0;
}

export default function lobbySyncViewModelTests(): void {
  describe('LobbySyncViewModel', () => {
    it('visibleLobbyReadsBothServerSnapshotsWithoutBusyOrBusinessWrites', 0, async () => {
      const repository: LobbyRepository = new LobbyRepository();
      const vm: SliceViewModel = new SliceViewModel(repository, INTERVAL_MS);
      await enterHome(vm, repository);
      try {
        vm.setLobbyPolling(true);
        await waitForPair(repository, 1);
        expect(vm.listBusy).assertFalse();
        expect(vm.items[0].id).assertEqual('assignment1');
        repository.playerReads[0].succeed(player('远端更新'));
        repository.assignmentReads[0].succeed(assignments('new-session'));
        await waitUntil(() => vm.items[0].id === 'new-session' && vm.player.displayName === '远端更新');
        vm.setLobbyPolling(false);
        expect(vm.player.level.order).assertEqual(2);
        expect(vm.items[0].completedLevels).assertEqual(1);
        expect(vm.listBusy).assertFalse();
        expect(repository.calls.join(',')).assertEqual('me,assignments');
      } finally {
        vm.setLobbyPolling(false);
      }
    });

    it('pullRefreshCancelsBothReadsAndLate401CannotOverrideItsSnapshot', 0, async () => {
      const repository: LobbyRepository = new LobbyRepository();
      const vm: SliceViewModel = new SliceViewModel(repository, INTERVAL_MS);
      await enterHome(vm, repository);
      try {
        vm.setLobbyPolling(true);
        await waitForPair(repository, 1);
        const oldPlayer: LobbyCall<Player> = repository.playerReads[0];
        const oldAssignments: LobbyCall<AssignmentSummary[]> = repository.assignmentReads[0];
        repository.manualList = assignments('manual-session');
        await vm.refresh();
        expect(oldPlayer.cancellation.cancelled).assertTrue();
        expect(oldAssignments.cancellation.cancelled).assertTrue();
        expect(vm.items[0].id).assertEqual('manual-session');
        expect(repository.playerReads.length).assertEqual(1);
        oldPlayer.fail(new GameFailure('UNAUTHORIZED', '旧登录已过期', 401));
        oldAssignments.succeed(assignments('old-session'));
        await waitForPair(repository, 2);
        expect(vm.gate).assertEqual('home');
        expect(vm.items[0].id).assertEqual('manual-session');
        expect(vm.showLobbySyncNotice).assertFalse();
      } finally {
        vm.setLobbyPolling(false);
      }
    });

    it('staleEmptyStateStaysVisibleAndNoticeReturnsOnlyAfterRecovery', 0, async () => {
      const repository: LobbyRepository = new LobbyRepository();
      repository.manualList = [];
      const vm: SliceViewModel = new SliceViewModel(repository, INTERVAL_MS);
      await enterHome(vm, repository);
      const unavailable: GameFailure = new GameFailure('SERVICE_UNAVAILABLE', '服务暂不可用', 503);
      try {
        vm.setLobbyPolling(true);
        await waitForPair(repository, 1);
        repository.playerReads[0].fail(unavailable);
        repository.assignmentReads[0].fail(unavailable);
        await waitForPair(repository, 2);
        expect(vm.showLobbySyncNotice).assertTrue();
        expect(vm.items.length).assertEqual(0);
        expect(vm.listError).assertEqual('');
        vm.dismissLobbySyncNotice();
        repository.playerReads[1].succeed(player('已恢复资料'));
        repository.assignmentReads[1].fail(unavailable);
        await waitForPair(repository, 3);
        expect(vm.showLobbySyncNotice).assertFalse();
        expect(vm.player.displayName).assertEqual('已恢复资料');
        repository.playerReads[2].succeed(player('已恢复资料'));
        repository.assignmentReads[2].succeed([]);
        await waitForPair(repository, 4);
        repository.playerReads[3].succeed(player('已恢复资料'));
        repository.assignmentReads[3].fail(unavailable);
        await waitUntil(() => vm.showLobbySyncNotice);
      } finally {
        vm.setLobbyPolling(false);
      }
    });

    it('leavingStopsReadsAndOnlyCurrentUnauthorizedClearsTheSession', 0, async () => {
      const repository: LobbyRepository = new LobbyRepository();
      const vm: SliceViewModel = new SliceViewModel(repository, INTERVAL_MS);
      await enterHome(vm, repository);
      try {
        vm.setLobbyPolling(true);
        await waitForPair(repository, 1);
        vm.setLobbyPolling(false);
        expect(repository.playerReads[0].cancellation.cancelled).assertTrue();
        expect(repository.assignmentReads[0].cancellation.cancelled).assertTrue();
        repository.playerReads[0].fail(new GameFailure('UNAUTHORIZED', '旧登录已过期', 401));
        repository.assignmentReads[0].succeed(assignments('old-session'));
        await wait(2 * INTERVAL_MS);
        expect(vm.gate).assertEqual('home');
        expect(vm.items[0].id).assertEqual('assignment1');
        expect(repository.playerReads.length).assertEqual(1);
        vm.setLobbyPolling(true);
        await waitForPair(repository, 2);
        repository.playerReads[1].fail(new GameFailure('UNAUTHORIZED', '登录已过期', 401));
        await waitUntil(() => vm.gate === 'login');
        expect(repository.assignmentReads[1].cancellation.cancelled).assertTrue();
        repository.assignmentReads[1].succeed(assignments('forbidden-session'));
        await wait(2 * INTERVAL_MS);
        expect(vm.player.id).assertEqual('');
        expect(vm.items.length).assertEqual(0);
        expect(vm.error).assertEqual('登录已过期');
        expect(repository.playerReads.length).assertEqual(2);
      } finally {
        vm.setLobbyPolling(false);
      }
    });

    it('oldPlayerReplyCannotUndoProfileSaveAndForcedPasswordClearsTheList', 0, async () => {
      const repository: LobbyRepository = new LobbyRepository();
      const vm: SliceViewModel = new SliceViewModel(repository, INTERVAL_MS);
      await enterHome(vm, repository);
      try {
        vm.setLobbyPolling(true);
        await waitForPair(repository, 1);
        vm.editProfileName('新昵称');
        await vm.saveProfile();
        expect(repository.playerReads[0].cancellation.cancelled).assertTrue();
        repository.playerReads[0].succeed(player('旧昵称'));
        repository.assignmentReads[0].succeed(assignments('old-session'));
        await waitForPair(repository, 2);
        expect(vm.player.displayName).assertEqual('新昵称');
        expect(vm.items[0].id).assertEqual('assignment1');
        repository.playerReads[1].succeed(player('被要求改密', true));
        await waitUntil(() => vm.gate === 'password');
        expect(repository.assignmentReads[1].cancellation.cancelled).assertTrue();
        repository.assignmentReads[1].succeed(assignments('forbidden-session'));
        await wait(2 * INTERVAL_MS);
        expect(vm.items.length).assertEqual(0);
        expect(repository.playerReads.length).assertEqual(2);
      } finally {
        vm.setLobbyPolling(false);
      }
    });
  });
}
