import { describe, expect, it } from '@ohos/hypium';
import { AvatarImage, AvatarUpload, GameFailure, Player } from '../main/ets/business/models';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { SliceViewModel } from '../main/ets/features/SliceViewModel';

const INITIAL_PASSWORD: string = 'Starward1234';
const FIRST_PASSWORD: string = 'NewStarward1234';
const NEXT_PASSWORD: string = 'LaterStarward1234';

function avatarUpload(): AvatarUpload {
  const value: AvatarUpload = new AvatarUpload();
  value.data = new Uint8Array([255, 216, 255, 1]).buffer as ArrayBuffer;
  return value;
}

function avatarImage(): AvatarImage {
  const value: AvatarImage = new AvatarImage();
  value.mimeType = 'image/jpeg';
  value.data = avatarUpload().data;
  return value;
}

async function enterHome(viewModel: SliceViewModel): Promise<void> {
  await viewModel.login('alice', INITIAL_PASSWORD);
  await viewModel.changePassword(INITIAL_PASSWORD, FIRST_PASSWORD, FIRST_PASSWORD);
}

function calls(repository: MockGameRepository, name: string): number {
  return repository.calls.filter((operation: string) => operation === name).length;
}

class DeferredMeRepository extends MockGameRepository {
  holdNextMe: boolean = false;
  private meValue: Player = new Player();
  private meFailure: GameFailure | null = null;
  private releaseMe: () => void = () => {};

  async me(): Promise<Player> {
    if (!this.holdNextMe) {
      return super.me();
    }
    this.holdNextMe = false;
    this.calls.push('me');
    await new Promise<void>((resolve: () => void) => { this.releaseMe = resolve; });
    if (this.meFailure !== null) {
      throw this.meFailure;
    }
    return this.meValue;
  }

  completeMe(player: Player): void {
    this.meValue = player;
    this.releaseMe();
  }

  cancelMe(): void {
    this.meFailure = new GameFailure('CANCELLED', '资料已更新，本次同步已取消。');
    this.releaseMe();
  }
}

class DeferredProfileRepository extends MockGameRepository {
  holdProfile: boolean = false;
  profileCalls: number = 0;
  private profileValue: Player = new Player();
  private releaseProfile: () => void = () => {};

  async updateProfile(displayName: string, avatar: AvatarUpload | null = null): Promise<Player> {
    this.profileCalls++;
    if (!this.holdProfile) {
      return super.updateProfile(displayName, avatar);
    }
    await new Promise<void>((resolve: () => void) => { this.releaseProfile = resolve; });
    return this.profileValue;
  }

  completeProfile(player: Player): void {
    this.profileValue = player;
    this.releaseProfile();
  }
}

class AvatarFailureRepository extends MockGameRepository {
  avatarFailure: GameFailure = new GameFailure('AVATAR_FETCH_FAILED', '文件凭据已失效', 401);

  async avatar(forceRefresh: boolean = false): Promise<AvatarImage | null> {
    this.calls.push(forceRefresh ? 'avatarRefresh' : 'avatar');
    throw this.avatarFailure;
  }
}

class RecoverableAvatarRepository extends MockGameRepository {
  private avatarFailure: GameFailure | null = new GameFailure('AVATAR_FETCH_FAILED', '文件服务暂不可用', 503);

  async avatar(forceRefresh: boolean = false): Promise<AvatarImage | null> {
    if (this.avatarFailure !== null) {
      this.calls.push(forceRefresh ? 'avatarRefresh' : 'avatar');
      const failure: GameFailure = this.avatarFailure;
      this.avatarFailure = null;
      throw failure;
    }
    return super.avatar(forceRefresh);
  }
}

class DeferredAvatarRepository extends MockGameRepository {
  avatarCalls: number = 0;
  private releaseAvatar: () => void = () => {};

  async avatar(forceRefresh: boolean = false): Promise<AvatarImage | null> {
    this.avatarCalls++;
    this.calls.push(forceRefresh ? 'avatarRefresh' : 'avatar');
    await new Promise<void>((resolve: () => void) => { this.releaseAvatar = resolve; });
    return avatarImage();
  }

  completeAvatar(): void {
    this.releaseAvatar();
  }
}

class LostAccountPasswordRepository extends MockGameRepository {
  dropPasswordResponse: boolean = false;

  async changePassword(oldPassword: string, password: string, confirmation: string): Promise<Player> {
    const player: Player = await super.changePassword(oldPassword, password, confirmation);
    if (this.dropPasswordResponse) {
      throw new GameFailure('NETWORK_ERROR', '连接在服务端改密后中断');
    }
    return player;
  }
}

export default function profileViewModelTests(): void {
  describe('ProfileViewModel', () => {
    it('refreshKeepsAnUnsavedNameAndAvatarDraft', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      const oldName: string = viewModel.player.displayName;
      viewModel.openProfile();
      viewModel.editProfileName('未保存的昵称');
      viewModel.selectProfileAvatar(avatarUpload());
      await viewModel.refresh();
      viewModel.openProfile();
      expect(viewModel.player.displayName).assertEqual(oldName);
      expect(viewModel.profileName).assertEqual('未保存的昵称');
      expect(viewModel.profileUpload !== null).assertTrue();
      expect(viewModel.profilePreview?.mimeType).assertEqual('image/jpeg');
      expect(calls(repository, 'updateProfile')).assertEqual(0);
    });

    it('emptyNameNeverWritesAndProfileSaveIsSingleFlight', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      viewModel.editProfileName('  ');
      await viewModel.saveProfile();
      expect(calls(repository, 'updateProfile')).assertEqual(0);
      expect(viewModel.profileError).assertEqual('给自己起个名字，再出发吧。');
      viewModel.editProfileName(' 新的旅人 ');
      repository.delayMs = 5;
      const saving: Promise<void> = viewModel.saveProfile();
      await viewModel.saveProfile();
      await saving;
      expect(calls(repository, 'updateProfile')).assertEqual(1);
      expect(viewModel.player.displayName).assertEqual('新的旅人');
      expect(viewModel.profileName).assertEqual('新的旅人');
      expect(viewModel.profileSaved).assertTrue();
      expect(viewModel.profileBusy).assertFalse();
    });

    it('sameValueNicknameEchoPreservesSavedFeedbackUntilTheUserActuallyEdits', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      viewModel.editProfileName('  原生资料验收者  ');
      await viewModel.saveProfile();
      expect(viewModel.player.displayName).assertEqual('原生资料验收者');
      expect(viewModel.profileName).assertEqual('原生资料验收者');
      expect(viewModel.profileSaved).assertTrue();
      expect(calls(repository, 'updateProfile')).assertEqual(1);

      // A native text-field echo of the authoritative value is not a user edit.
      viewModel.editProfileName(viewModel.profileName);
      expect(viewModel.profileSaved).assertTrue();
      expect(viewModel.profileError).assertEqual('');
      expect(calls(repository, 'updateProfile')).assertEqual(1);
      await viewModel.refresh();
      viewModel.openProfile();
      expect(viewModel.profileName).assertEqual('原生资料验收者');
      expect(viewModel.profileSaved).assertTrue();
      expect(calls(repository, 'updateProfile')).assertEqual(1);

      viewModel.editProfileName('原生资料验收者的新名字');
      expect(viewModel.profileSaved).assertFalse();
      expect(viewModel.profileName).assertEqual('原生资料验收者的新名字');
      expect(calls(repository, 'updateProfile')).assertEqual(1);
      await viewModel.saveProfile();
      expect(viewModel.player.displayName).assertEqual('原生资料验收者的新名字');
      expect(viewModel.profileSaved).assertTrue();
      expect(calls(repository, 'updateProfile')).assertEqual(2);
    });

    it('failedSaveKeepsTheDraftAndExplicitRetryUsesServerResult', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      const oldName: string = viewModel.player.displayName;
      viewModel.editProfileName('新的名片');
      viewModel.selectProfileAvatar(avatarUpload());
      repository.nextFailure = new GameFailure('SERVICE_UNAVAILABLE', '资料服务暂不可用', 503);
      await viewModel.saveProfile();
      expect(viewModel.player.displayName).assertEqual(oldName);
      expect(viewModel.profileName).assertEqual('新的名片');
      expect(viewModel.profileUpload !== null).assertTrue();
      expect(viewModel.profilePreview !== null).assertTrue();
      expect(viewModel.profileError).assertEqual('资料服务暂不可用');
      expect(viewModel.profileSaved).assertFalse();
      expect(calls(repository, 'updateProfile')).assertEqual(1);
      await viewModel.saveProfile();
      expect(viewModel.player.displayName).assertEqual('新的名片');
      expect(viewModel.profileSaved).assertTrue();
      expect(viewModel.profileUpload === null && viewModel.profilePreview === null).assertTrue();
      expect(calls(repository, 'updateProfile')).assertEqual(2);
    });

    it('lateProfileSuccessCannotRestoreStateAfterLogout', 0, async () => {
      const repository: DeferredProfileRepository = new DeferredProfileRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      const latePlayer: Player = viewModel.player;
      repository.holdProfile = true;
      viewModel.editProfileName('待保存名片');
      viewModel.selectProfileAvatar(avatarUpload());
      const saving: Promise<void> = viewModel.saveProfile();
      await viewModel.saveProfile();
      expect(repository.profileCalls).assertEqual(1);
      viewModel.logout();
      repository.completeProfile(latePlayer);
      await saving;
      expect(viewModel.gate).assertEqual('login');
      expect(viewModel.player.id).assertEqual('');
      expect(viewModel.profileName).assertEqual('');
      expect(viewModel.profileUpload === null && viewModel.profilePreview === null).assertTrue();
      expect(viewModel.profileSaved || viewModel.profileBusy).assertFalse();
      expect(viewModel.profileError).assertEqual('');
    });

    it('oldMeSuccessCannotRollBackTheSavedProfile', 0, async () => {
      const repository: DeferredMeRepository = new DeferredMeRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      const oldPlayer: Player = viewModel.player;
      repository.holdNextMe = true;
      const syncing: Promise<void> = viewModel.refresh();
      viewModel.editProfileName('保存后的昵称');
      await viewModel.saveProfile();
      repository.completeMe(oldPlayer);
      await syncing;
      expect(viewModel.player.displayName).assertEqual('保存后的昵称');
      expect(viewModel.profileName).assertEqual('保存后的昵称');
      expect(viewModel.profileSaved).assertTrue();
      expect(viewModel.listError).assertEqual('');
      expect(viewModel.listBusy).assertFalse();
    });

    it('expectedCancellationOfOldMeDoesNotCreateAFalseSyncError', 0, async () => {
      const repository: DeferredMeRepository = new DeferredMeRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      repository.holdNextMe = true;
      const syncing: Promise<void> = viewModel.refresh();
      viewModel.editProfileName('新昵称');
      await viewModel.saveProfile();
      repository.cancelMe();
      await syncing;
      expect(viewModel.player.displayName).assertEqual('新昵称');
      expect(viewModel.profileSaved).assertTrue();
      expect(viewModel.listError).assertEqual('');
      expect(viewModel.listBusy).assertFalse();
    });

    it('ordinaryPasswordSuccessStaysHomeAndSignalsFieldClearing', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      viewModel.editProfileName('尚未保存的名字');
      const writes: number = calls(repository, 'changePassword');
      const revision: number = viewModel.securitySuccessRevision;
      await viewModel.changeAccountPassword(FIRST_PASSWORD, NEXT_PASSWORD, NEXT_PASSWORD);
      expect(viewModel.gate).assertEqual('home');
      expect(viewModel.securitySaved).assertTrue();
      expect(viewModel.securityBusy || viewModel.securityUnconfirmed).assertFalse();
      expect(viewModel.securitySuccessRevision).assertEqual(revision + 1);
      expect(viewModel.profileName).assertEqual('尚未保存的名字');
      expect(calls(repository, 'changePassword')).assertEqual(writes + 1);
      viewModel.logout();
      await viewModel.login('alice', NEXT_PASSWORD);
      expect(viewModel.gate).assertEqual('home');
    });

    it('lostOrdinaryPasswordResponseRequiresReloginWithoutAnyReplay', 0, async () => {
      const repository: LostAccountPasswordRepository = new LostAccountPasswordRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      repository.dropPasswordResponse = true;
      const passwordWrites: number = calls(repository, 'changePassword');
      await viewModel.changeAccountPassword(FIRST_PASSWORD, NEXT_PASSWORD, NEXT_PASSWORD);
      expect(viewModel.securityError).assertContain('结果尚未确认');
      expect(viewModel.securityUnconfirmed).assertTrue();
      expect(viewModel.securitySaved || viewModel.securityBusy).assertFalse();
      const profileWrites: number = calls(repository, 'updateProfile');
      const reads: number = calls(repository, 'me');
      viewModel.editProfileName('不应提交的资料');
      await viewModel.changeAccountPassword(FIRST_PASSWORD, NEXT_PASSWORD, NEXT_PASSWORD);
      await viewModel.saveProfile();
      await viewModel.refresh();
      await viewModel.openAssignment('assignment1');
      expect(calls(repository, 'changePassword')).assertEqual(passwordWrites + 1);
      expect(calls(repository, 'updateProfile')).assertEqual(profileWrites);
      expect(calls(repository, 'me')).assertEqual(reads);
      expect(calls(repository, 'assignment')).assertEqual(0);
      viewModel.logout();
      await viewModel.login('alice', NEXT_PASSWORD);
      expect(viewModel.gate).assertEqual('home');
      expect(viewModel.securityUnconfirmed).assertFalse();
    });

    it('wrongCurrentPasswordPreservesADefiniteErrorAndAllowsANewAttempt', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      const writes: number = calls(repository, 'changePassword');
      await viewModel.changeAccountPassword('WrongPassword123', NEXT_PASSWORD, NEXT_PASSWORD);
      expect(viewModel.gate).assertEqual('home');
      expect(viewModel.securityError).assertEqual('当前密码不正确，请重新输入。');
      expect(viewModel.securityUnconfirmed || viewModel.securitySaved || viewModel.securityBusy).assertFalse();
      expect(calls(repository, 'changePassword')).assertEqual(writes + 1);
      await viewModel.changeAccountPassword(FIRST_PASSWORD, NEXT_PASSWORD, NEXT_PASSWORD);
      expect(viewModel.securitySaved).assertTrue();
      expect(calls(repository, 'changePassword')).assertEqual(writes + 2);
    });

    it('avatarFile401IsRetryableWhileMainAuthentication401LogsOut', 0, async () => {
      const repository: AvatarFailureRepository = new AvatarFailureRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      await viewModel.loadAvatar(true);
      expect(viewModel.gate).assertEqual('home');
      expect(viewModel.player.id).assertEqual('playeralice');
      expect(viewModel.avatarError).assertContain('重试');
      expect(viewModel.avatarBusy).assertFalse();
      repository.avatarFailure = new GameFailure('UNAUTHORIZED', '登录已过期', 401);
      await viewModel.loadAvatar(true);
      expect(viewModel.gate).assertEqual('login');
      expect(viewModel.player.id).assertEqual('');
      expect(viewModel.error).assertEqual('登录已过期');
    });

    it('avatarFailurePersistsAcrossProfileAndMeRefreshUntilExplicitRetry', 0, async () => {
      const repository: RecoverableAvatarRepository = new RecoverableAvatarRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      await repository.updateProfile(viewModel.player.displayName, avatarUpload());
      await viewModel.refresh();
      expect(calls(repository, 'avatar')).assertEqual(1);
      expect(viewModel.gate).assertEqual('home');
      expect(viewModel.avatarBusy).assertFalse();
      expect(viewModel.avatarImage === null).assertTrue();
      const error: string = viewModel.avatarError;
      expect(error).assertEqual('头像读取失败，请重试。');

      viewModel.openProfile();
      await viewModel.refresh();
      viewModel.openProfile();
      expect(calls(repository, 'avatar')).assertEqual(1);
      expect(calls(repository, 'avatarRefresh')).assertEqual(0);
      expect(viewModel.avatarError).assertEqual(error);
      expect(viewModel.avatarBusy).assertFalse();
      expect(viewModel.avatarImage === null).assertTrue();

      await viewModel.loadAvatar(true);
      expect(calls(repository, 'avatar')).assertEqual(1);
      expect(calls(repository, 'avatarRefresh')).assertEqual(1);
      expect(viewModel.avatarError).assertEqual('');
      expect(viewModel.avatarBusy).assertFalse();
      expect(viewModel.avatarImage?.mimeType).assertEqual('image/jpeg');
      expect(viewModel.avatarImage?.data.byteLength).assertEqual(avatarUpload().data.byteLength);
    });

    it('undecodableCurrentAvatarKeepsItsErrorAcrossSyncUntilExplicitReload', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      await repository.updateProfile(viewModel.player.displayName, avatarUpload());
      await viewModel.refresh();
      const undecodable: AvatarImage = viewModel.avatarImage as AvatarImage;
      expect(undecodable !== null).assertTrue();
      expect(calls(repository, 'avatar')).assertEqual(1);

      viewModel.reportAvatarDecodeFailure(undecodable);
      expect(viewModel.gate).assertEqual('home');
      expect(viewModel.avatarImage === null).assertTrue();
      expect(viewModel.avatarError).assertEqual('头像读取失败，请重试。');
      viewModel.openProfile();
      await viewModel.refresh();
      viewModel.openProfile();
      expect(calls(repository, 'avatar')).assertEqual(1);
      expect(calls(repository, 'avatarRefresh')).assertEqual(0);
      expect(viewModel.avatarImage === null).assertTrue();
      expect(viewModel.avatarError).assertEqual('头像读取失败，请重试。');

      await viewModel.loadAvatar(true);
      expect(calls(repository, 'avatarRefresh')).assertEqual(1);
      expect(viewModel.avatarImage !== null && viewModel.avatarImage !== undecodable).assertTrue();
      expect(viewModel.avatarImage?.mimeType).assertEqual('image/jpeg');
      expect(viewModel.avatarError).assertEqual('');
    });

    it('successfulInflightReloadClearsTheOldImagesLateDecodeError', 0, async () => {
      const repository: DeferredAvatarRepository = new DeferredAvatarRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      viewModel.player.avatar = 'private-avatar.jpg';
      const initialLoading: Promise<void> = viewModel.loadAvatar();
      repository.completeAvatar();
      await initialLoading;
      const oldImage: AvatarImage = viewModel.avatarImage as AvatarImage;
      expect(oldImage !== null).assertTrue();

      const reloading: Promise<void> = viewModel.loadAvatar(true);
      expect(repository.avatarCalls).assertEqual(2);
      expect(viewModel.avatarBusy).assertTrue();
      viewModel.reportAvatarDecodeFailure(oldImage);
      expect(viewModel.avatarImage === null).assertTrue();
      expect(viewModel.avatarError).assertEqual('头像读取失败，请重试。');
      repository.completeAvatar();
      await reloading;
      const currentImage: AvatarImage = viewModel.avatarImage as AvatarImage;
      expect(currentImage !== null && currentImage !== oldImage).assertTrue();
      expect(currentImage.mimeType).assertEqual('image/jpeg');
      expect(viewModel.avatarError).assertEqual('');
      expect(viewModel.avatarBusy).assertFalse();
      expect(calls(repository, 'avatarRefresh')).assertEqual(1);

      viewModel.reportAvatarDecodeFailure(oldImage);
      expect(viewModel.avatarImage === currentImage).assertTrue();
      expect(viewModel.avatarError).assertEqual('');
      expect(repository.avatarCalls).assertEqual(2);
    });

    it('lateDecodeFailuresCannotClearANewerImageOrPolluteLogoutAndTheNextLogin', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      await repository.updateProfile(viewModel.player.displayName, avatarUpload());
      await viewModel.refresh();
      const oldImage: AvatarImage = viewModel.avatarImage as AvatarImage;
      expect(oldImage !== null).assertTrue();
      await viewModel.loadAvatar(true);
      const newerImage: AvatarImage = viewModel.avatarImage as AvatarImage;
      expect(newerImage !== null && newerImage !== oldImage).assertTrue();
      viewModel.selectProfileAvatar(avatarUpload());
      const oldPreview: AvatarImage = viewModel.profilePreview as AvatarImage;
      viewModel.selectProfileAvatar(avatarUpload());
      const newerPreview: AvatarImage = viewModel.profilePreview as AvatarImage;
      viewModel.reportAvatarDecodeFailure(oldImage);
      viewModel.reportAvatarDecodeFailure(oldPreview);
      expect(viewModel.avatarImage === newerImage && viewModel.profilePreview === newerPreview).assertTrue();
      expect(viewModel.profileUpload !== null).assertTrue();
      expect(viewModel.avatarError).assertEqual('');
      expect(viewModel.profileError).assertEqual('');

      viewModel.logout();
      viewModel.reportAvatarDecodeFailure(newerImage);
      viewModel.reportAvatarDecodeFailure(newerPreview);
      expect(viewModel.gate).assertEqual('login');
      expect(viewModel.avatarImage === null && viewModel.profilePreview === null).assertTrue();
      expect(viewModel.avatarError).assertEqual('');
      expect(viewModel.profileError).assertEqual('');
      await viewModel.login('alice', FIRST_PASSWORD);
      const nextSessionImage: AvatarImage = viewModel.avatarImage as AvatarImage;
      expect(nextSessionImage !== null && nextSessionImage !== newerImage).assertTrue();
      viewModel.reportAvatarDecodeFailure(newerImage);
      viewModel.reportAvatarDecodeFailure(newerPreview);
      expect(viewModel.gate).assertEqual('home');
      expect(viewModel.avatarImage === nextSessionImage).assertTrue();
      expect(viewModel.profilePreview === null && viewModel.profileUpload === null).assertTrue();
      expect(viewModel.avatarError).assertEqual('');
      expect(viewModel.profileError).assertEqual('');
    });

    it('undecodablePreviewCannotBeUploadedAgainAndKeepsOnlyTheNicknameDraft', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      viewModel.editProfileName('保留下来的昵称');
      viewModel.selectProfileAvatar(avatarUpload());
      const undecodable: AvatarImage = viewModel.profilePreview as AvatarImage;
      expect(undecodable !== null).assertTrue();
      viewModel.reportAvatarDecodeFailure(undecodable);
      expect(viewModel.profilePreview === null && viewModel.profileUpload === null).assertTrue();
      expect(viewModel.profileName).assertEqual('保留下来的昵称');
      expect(viewModel.profileError).assertEqual('头像预览失败，请重新选择照片。');
      expect(viewModel.avatarError).assertEqual('');
      expect(calls(repository, 'updateProfile')).assertEqual(0);
      await viewModel.refresh();
      viewModel.openProfile();
      expect(viewModel.profileName).assertEqual('保留下来的昵称');
      expect(viewModel.profileError).assertEqual('头像预览失败，请重新选择照片。');

      await viewModel.saveProfile();
      expect(calls(repository, 'updateProfile')).assertEqual(1);
      expect(viewModel.player.displayName).assertEqual('保留下来的昵称');
      expect(viewModel.player.avatar).assertEqual('');
      expect(viewModel.profileSaved).assertTrue();

      viewModel.selectProfileAvatar(avatarUpload());
      viewModel.reportAvatarDecodeFailure(viewModel.profilePreview as AvatarImage);
      await repository.updateProfile('来自服务端的新名字');
      await viewModel.refresh();
      viewModel.openProfile();
      expect(viewModel.profileName).assertEqual('来自服务端的新名字');
      expect(viewModel.profileUpload === null && viewModel.profilePreview === null).assertTrue();
    });

    it('logoutClearsSelectedAndPendingAvatarAndIgnoresLateBytes', 0, async () => {
      const repository: DeferredAvatarRepository = new DeferredAvatarRepository(0);
      const viewModel: SliceViewModel = new SliceViewModel(repository);
      await enterHome(viewModel);
      viewModel.player.avatar = 'private-avatar.jpg';
      viewModel.selectProfileAvatar(avatarUpload());
      const loading: Promise<void> = viewModel.loadAvatar();
      await viewModel.loadAvatar();
      expect(repository.avatarCalls).assertEqual(1);
      viewModel.logout();
      repository.completeAvatar();
      await loading;
      expect(viewModel.gate).assertEqual('login');
      expect(viewModel.avatarImage === null && viewModel.profilePreview === null && viewModel.profileUpload === null)
        .assertTrue();
      expect(viewModel.avatarError).assertEqual('');
      expect(viewModel.avatarBusy || viewModel.profileBusy).assertFalse();
    });
  });
}
