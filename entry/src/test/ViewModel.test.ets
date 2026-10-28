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
      await viewModel.login('alice', 'Starward1234');
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
      await viewModel.login('', '');
      expect(repository.calls.length).assertEqual(0);
      expect(viewModel.errorCode).assertEqual('VALIDATION_ERROR');
      expect(viewModel.error.length > 0).assertTrue();
      await viewModel.login('alice', 'WrongPassword123');
      expect(viewModel.gate).assertEqual('login');
      expect(viewModel.player.id).assertEqual('');
      expect(viewModel.busy).assertFalse();
      expect(viewModel.error).assertEqual('账号或密码不正确');
    });

    it('duplicateLoginIsSingleFlightAndLogoutIgnoresResponse', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(5);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      const pending: Promise<void> = viewModel.login('alice', 'Starward1234');
      await viewModel.login('alice', 'Starward1234');
      viewModel.logout();
      await pending;
      expect(repository.calls.join(',')).assertEqual('login');
      expect(viewModel.gate).assertEqual('login');
      expect(viewModel.player.id).assertEqual('');
      expect(viewModel.items.length).assertEqual(0);
      expect(viewModel.busy).assertFalse();
      expect(viewModel.error).assertEqual('');
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

    it('emptyAssignmentsAreSuccessWhileTransientErrorsRemainRetryable', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      repository.nextFailure = new GameFailure('NETWORK_ERROR', '连接中断');
      await viewModel.refresh();
      expect(viewModel.gate).assertEqual('home');
      expect(viewModel.listError).assertEqual('连接中断');
      repository.emptyAssignments = true;
      await viewModel.refresh();
      expect(viewModel.items.length).assertEqual(0);
      expect(viewModel.listError).assertEqual('');
    });
  });
}
