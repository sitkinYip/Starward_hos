import { describe, expect, it } from '@ohos/hypium';
import { GameFailure, Player } from '../main/ets/business/models';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { SliceViewModel } from '../main/ets/features/SliceViewModel';

class LostPasswordResponseRepository extends MockGameRepository {
  async changePassword(oldPassword: string, password: string, confirmation: string): Promise<Player> {
    await super.changePassword(oldPassword, password, confirmation);
    throw new GameFailure('NETWORK_ERROR', '连接中断，提交可能已生效；请退出后使用新密码登录确认。');
  }
}

async function enterHome(viewModel: SliceViewModel): Promise<void> {
  await viewModel.login('alice', 'Starward1234');
  await viewModel.changePassword('Starward1234', 'NewStarward1234', 'NewStarward1234');
}

export default function viewModelTests(): void {
  describe('ViewModel', () => {
    it('forcedPasswordGatePreventsListAndDetailRequests', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      let formAccepted: boolean = false;
      await viewModel.login('alice', 'Starward1234', () => { formAccepted = true; });
      expect(formAccepted).assertFalse();
      expect(viewModel.gate).assertEqual('password');
      await viewModel.refresh();
      await viewModel.openAssignment('assignment1');
      expect(viewModel.items.length).assertEqual(0);
      expect(viewModel.detail.id).assertEqual('');
      expect(repository.calls.join(',')).assertEqual('login');
      await viewModel.changePassword('Starward1234', 'NewStarward1234', 'NewStarward1234');
      expect(viewModel.gate).assertEqual('home');
      expect(viewModel.items.length).assertEqual(1);
      expect(viewModel.busy).assertFalse();
    });

    it('invalidInputsAndWrongPasswordKeepAuthGate', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      let formAccepted: boolean = false;
      const acceptForm = (): void => { formAccepted = true; };
      await viewModel.login('', '', acceptForm);
      expect(repository.calls.length).assertEqual(0);
      expect(viewModel.errorCode).assertEqual('VALIDATION_ERROR');
      expect(viewModel.error.length > 0).assertTrue();
      await viewModel.login('alice', 'WrongPassword123', acceptForm);
      expect(formAccepted).assertFalse();
      expect(viewModel.gate).assertEqual('login');
      expect(viewModel.player.id).assertEqual('');
      expect(viewModel.busy).assertFalse();
      expect(viewModel.error).assertEqual('账号或密码不正确');
    });

    it('duplicateLoginIsSingleFlightAndLogoutIgnoresResponse', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      viewModel.logout();
      repository.calls.length = 0;
      repository.delayMs = 5;
      let formAccepted: boolean = false;
      const acceptForm = (): void => { formAccepted = true; };
      const pending: Promise<void> = viewModel.login('alice', 'NewStarward1234', acceptForm);
      await viewModel.login('alice', 'NewStarward1234', acceptForm);
      viewModel.logout();
      await pending;
      expect(formAccepted).assertFalse();
      expect(repository.calls.join(',')).assertEqual('login');
      expect(viewModel.gate).assertEqual('login');
      expect(viewModel.player.id).assertEqual('');
      expect(viewModel.items.length).assertEqual(0);
      expect(viewModel.busy).assertFalse();
      expect(viewModel.error).assertEqual('');
    });

    it('handlesVerifiedLoginFormBeforeOpeningHomeEvenIfSystemSaveFails', 0, async () => {
      const viewModel: SliceViewModel = new SliceViewModel(new MockGameRepository(0));
      await enterHome(viewModel);
      viewModel.logout();
      let gateAtSave: string = '';
      await viewModel.login('alice', 'NewStarward1234', () => {
        gateAtSave = viewModel.gate;
        throw new Error('System password save unavailable');
      });
      expect(gateAtSave).assertEqual('login');
      expect(viewModel.gate).assertEqual('home');
      expect(viewModel.busy).assertFalse();
    });

    it('aLoginServiceFailureIsRecoverableInPlaceWithoutOpeningAnAccount', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      repository.nextFailure = new GameFailure('REQUEST_FAILED', '代理错误', 503);
      await viewModel.login('alice', 'Starward1234');
      expect(viewModel.loginNetworkError).assertTrue();
      expect(viewModel.gate).assertEqual('login');
      expect(viewModel.player.id).assertEqual('');
      expect(repository.calls.join(',')).assertEqual('login');
      await viewModel.login('alice', 'WrongPassword123');
      expect(viewModel.loginNetworkError).assertFalse();
      expect(viewModel.error).assertEqual('账号或密码不正确');
    });

    it('expiredSessionClearsPrivateStateAndReturnsToLogin', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      await viewModel.openAssignment('assignment1');
      expect(viewModel.detail.id).assertEqual('assignment1');
      repository.nextFailure = new GameFailure('UNAUTHORIZED', '登录已过期', 401);
      await viewModel.refresh();
      expect(viewModel.gate).assertEqual('login');
      expect(viewModel.player.id).assertEqual('');
      expect(viewModel.items.length).assertEqual(0);
      expect(viewModel.detail.id).assertEqual('');
      expect(viewModel.error).assertEqual('登录已过期');
    });

    it('logoutWhileLoadingDetailCannotRestorePrivateDetail', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      repository.delayMs = 5;
      const pending: Promise<void> = viewModel.openAssignment('assignment1');
      viewModel.logout();
      await pending;
      expect(viewModel.gate).assertEqual('login');
      expect(viewModel.detail.id).assertEqual('');
      expect(viewModel.detailError).assertEqual('');
      expect(viewModel.detailBusy).assertFalse();
    });

    it('forbiddenMeClearsAllPreviouslyVisiblePrivateState', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      await viewModel.openAssignment('assignment1');
      repository.nextFailure = new GameFailure('ACCOUNT_DISABLED', '账号已停用', 403);
      await viewModel.refresh();
      expect(viewModel.gate).assertEqual('login');
      expect(viewModel.player.id).assertEqual('');
      expect(viewModel.items.length).assertEqual(0);
      expect(viewModel.detail.id).assertEqual('');
      expect(viewModel.error).assertEqual('账号已停用');
    });

    it('lostPasswordResponseCanRecoverByNewPasswordWithoutReplay', 0, async () => {
      const repository: LostPasswordResponseRepository = new LostPasswordResponseRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await viewModel.login('alice', 'Starward1234');
      await viewModel.changePassword('Starward1234', 'NewStarward1234', 'NewStarward1234');
      expect(viewModel.gate).assertEqual('password');
      expect(viewModel.error).assertContain('结果尚未确认');
      expect(repository.calls.filter((operation: string) => operation === 'changePassword').length).assertEqual(1);
      viewModel.logout();
      await viewModel.login('alice', 'NewStarward1234');
      expect(viewModel.gate).assertEqual('home');
      expect(viewModel.items.length).assertEqual(1);
    });

    it('passwordServerFailureIsUnconfirmedAndIsNotReplayed', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await viewModel.login('alice', 'Starward1234');
      repository.nextFailure = new GameFailure('SERVICE_UNAVAILABLE', '服务暂不可用', 503);
      await viewModel.changePassword('Starward1234', 'NewStarward1234', 'NewStarward1234');
      expect(viewModel.gate).assertEqual('password');
      expect(viewModel.error).assertContain('结果尚未确认');
      expect(viewModel.errorCode).assertEqual('SERVICE_UNAVAILABLE');
      expect(viewModel.busy).assertFalse();
      expect(repository.calls.filter((operation: string) => operation === 'changePassword').length).assertEqual(1);
    });

    it('passwordClientRejectionPreservesDefiniteErrorAndIsNotReplayed', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await viewModel.login('alice', 'Starward1234');
      repository.nextFailure = new GameFailure('INVALID_PASSWORD', '当前密码不正确，请重新输入。', 400);
      await viewModel.changePassword('Starward1234', 'NewStarward1234', 'NewStarward1234');
      expect(viewModel.gate).assertEqual('password');
      expect(viewModel.error).assertEqual('当前密码不正确，请重新输入。');
      expect(viewModel.errorCode).assertEqual('INVALID_PASSWORD');
      expect(viewModel.busy).assertFalse();
      expect(repository.calls.filter((operation: string) => operation === 'changePassword').length).assertEqual(1);
    });

    it('fatalDetailErrorClearsPreviouslyVisibleDetail', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      await viewModel.openAssignment('assignment1');
      repository.nextFailure = new GameFailure('SESSION_OFFLINE', '场次已下线', 410);
      await viewModel.openAssignment('assignment1');
      expect(viewModel.detail.id).assertEqual('');
      expect(viewModel.detailError).assertEqual('场次已下线');
      expect(viewModel.detailBusy).assertFalse();
    });

    it('briefingReadResumesRemoteStartWithoutPlayingEntryEffects', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      await viewModel.openAssignment('assignment1');
      expect(viewModel.play.visible).assertFalse();
      await repository.startAssignment('assignment1', 'other-client');
      await viewModel.openAssignment('assignment1');
      expect(viewModel.detail.status).assertEqual('active');
      expect(viewModel.play.visible).assertTrue();
      expect(viewModel.play.currentLevel()?.question !== null).assertTrue();
      expect(viewModel.play.automaticClue).assertNull();
      expect(repository.calls.filter((operation: string) => operation === 'startAssignment').length).assertEqual(1);
    });

    it('leavingBriefingIgnoresLateRemoteStart', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      await viewModel.openAssignment('assignment1');
      await repository.startAssignment('assignment1', 'other-client');
      repository.delayMs = 5;
      const pending: Promise<void> = viewModel.openAssignment('assignment1');
      viewModel.stopBriefingSync();
      await pending;
      expect(viewModel.detail.status).assertEqual('assigned');
      expect(viewModel.detailBusy).assertFalse();
      expect(viewModel.play.visible).assertFalse();
    });

    it('briefingDoesNotReplaceUncertainLocalEntryWithReadRecovery', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      await viewModel.openAssignment('assignment1');
      await repository.startAssignment('assignment1', 'other-client');
      viewModel.play.retryEntry = true;
      const before: number = repository.calls.length;
      await viewModel.openAssignment('assignment1');
      expect(repository.calls.length).assertEqual(before);
      expect(viewModel.play.visible).assertFalse();
      viewModel.play.retryEntry = false;
      await viewModel.openAssignment('assignment1');
      expect(viewModel.play.visible).assertTrue();
    });

    it('manualLobbyRefreshKeepsAValidEmptySnapshotDuringAnOutage', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      repository.emptyAssignments = true;
      await viewModel.refresh();
      expect(viewModel.lobbyHasList).assertTrue();
      expect(viewModel.items.length).assertEqual(0);
      repository.nextFailure = new GameFailure('NETWORK_ERROR', '连接中断');
      await viewModel.refresh();
      expect(viewModel.gate).assertEqual('home');
      expect(viewModel.lobbyHasList).assertTrue();
      expect(viewModel.listError).assertEqual('');
      expect(viewModel.showLobbySyncNotice).assertTrue();
      await viewModel.refresh();
      expect(viewModel.showLobbySyncNotice).assertFalse();
    });
  });
}
