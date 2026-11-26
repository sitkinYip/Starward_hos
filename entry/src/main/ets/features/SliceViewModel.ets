import { GameRepository } from '../business/GameRepository';
import { isRestoredSessionInvalid } from '../business/CredentialStore';
import { AssignmentDetail, AssignmentSummary, AvatarImage, AvatarUpload, GameFailure, Player,
  validateDisplayName, validatePasswordChange } from '../business/models';
import { GameplayPresentation, GameplaySnapshot } from '../business/GameplayModels';
import { GameplayViewModel } from './GameplayViewModel';
import { NarrativeViewModel } from './NarrativeViewModel';
import { StarLettersViewModel } from './StarLettersViewModel';
import { JourneyNotificationsViewModel } from './JourneyNotificationsViewModel';
import { RewardsViewModel } from './RewardsViewModel';
import { createRequestIdentity } from '../platform/RequestIdentity';
import { ReadCancellation } from '../business/ReadCancellation';
import { PushDevice, PushStatus } from '../business/PushRegistration';
import { PushSubscriptionsViewModel } from './PushSubscriptionsViewModel';
import { LobbyFeed } from '../business/LobbyFeed';
import { LobbyUnread } from './LobbyUnread';

const ASSIGNMENT_SYNC_INTERVAL_MS: number = 5000;

function loginConnectionMessage(error: Object): string {
  if (!(error instanceof GameFailure)) { return ''; }
  if (error.code === 'TLS_ERROR') { return '安全连接失败，请稍后重试。'; }
  if (error.code === 'TIMEOUT' || error.status === 408) { return '连接超时，请稍后重试。'; }
  if (error.code === 'NETWORK_ERROR') { return '网络连接中断，请检查网络后重试。'; }
  if (error.status === 429) { return '登录请求过于频繁，请稍后重试。'; }
  return error.status >= 500 ? '登录服务暂不可用，请稍后重试。' : '';
}

/** A lobby cycle owns two independent requests, each with its own NetworkKit cancellation. */
class LobbyRead {
  readonly player: ReadCancellation = new ReadCancellation();
  readonly assignments: ReadCancellation = new ReadCancellation();
  readonly generation: number;
  readonly profileRevision: number;

  constructor(generation: number, profileRevision: number) {
    this.generation = generation;
    this.profileRevision = profileRevision;
  }
}

@ObservedV2
export class SliceViewModel {
  @Trace gate: string = 'login';
  @Trace busy: boolean = false;
  @Trace error: string = '';
  @Trace errorCode: string = '';
  @Trace loginNetworkError: boolean = false;
  @Trace player: Player = new Player();
  @Trace items: AssignmentSummary[] = [];
  @Trace detail: AssignmentDetail = new AssignmentDetail();
  @Trace briefingPresentation: GameplayPresentation | null = null;
  @Trace listBusy: boolean = false;
  @Trace detailBusy: boolean = false;
  @Trace listError: string = '';
  @Trace lobbyHasList: boolean = false;
  @Trace showLobbySyncNotice: boolean = false;
  @Trace detailError: string = '';
  @Trace profileName: string = '';
  @Trace profileUpload: AvatarUpload | null = null;
  @Trace profilePreview: AvatarImage | null = null;
  @Trace profileBusy: boolean = false;
  @Trace profileError: string = '';
  @Trace profileSaved: boolean = false;
  @Trace avatarImage: AvatarImage | null = null;
  @Trace avatarBusy: boolean = false;
  @Trace avatarError: string = '';
  @Trace securityBusy: boolean = false;
  @Trace securityError: string = '';
  @Trace securitySaved: boolean = false;
  @Trace securityUnconfirmed: boolean = false;
  @Trace securitySuccessRevision: number = 0;
  @Trace now: number = Date.now();
  readonly mode: string;
  readonly play: GameplayViewModel;
  readonly narrative: NarrativeViewModel;
  readonly starLetters: StarLettersViewModel;
  readonly journey: JourneyNotificationsViewModel;
  readonly rewards: RewardsViewModel;
  readonly lobbyUnread: LobbyUnread = new LobbyUnread();
  readonly pushSubscriptions: PushSubscriptionsViewModel;
  readonly onboardingSubscriptions: PushSubscriptionsViewModel;
  private readonly repository: GameRepository;
  private generation: number = 0;
  private restoreRead: ReadCancellation | null = null;
  private detailRead: ReadCancellation | null = null;
  private openingId: string = '';
  private briefingAssignmentId: string = '';
  private briefingPollTimer: number = -1;
  private serverOffset: number = 0;
  private profileDirty: boolean = false;
  private profileRevision: number = 0;
  private avatarRequest: number = 0;
  private gameplayPlayerPolling: boolean = false;
  private playerPollTimer: number = -1;
  private playerPollRead: ReadCancellation | null = null;
  private lobbyPolling: boolean = false;
  private homeFeedActive: boolean = false;
  private homeFeedUnavailable: boolean = false;
  private lobbyPollTimer: number = -1;
  private lobbyRead: LobbyRead | null = null;
  private lobbyPlayerReadFailed: boolean = false;
  private lobbyListReadFailed: boolean = false;
  private readonly lobbySyncIntervalMs: number;

  constructor(repository: GameRepository,
    lobbySyncIntervalMs: number = ASSIGNMENT_SYNC_INTERVAL_MS) {
    this.repository = repository;
    this.lobbySyncIntervalMs = lobbySyncIntervalMs;
    this.mode = repository.mode;
    this.narrative = new NarrativeViewModel(repository, (message: string) => {
      this.logout();
      this.error = message;
    });
    this.starLetters = new StarLettersViewModel(repository, (message: string) => {
      this.logout();
      this.error = message;
    });
    this.journey = new JourneyNotificationsViewModel(repository, (message: string) => {
      this.logout();
      this.error = message;
    });
    this.rewards = new RewardsViewModel(repository, (error: Object) => this.rejectPlayerSession(error));
    this.pushSubscriptions = new PushSubscriptionsViewModel(repository, (error: Object) => this.rejectPlayerSession(error));
    this.onboardingSubscriptions = new PushSubscriptionsViewModel(repository, (error: Object) => this.rejectPlayerSession(error));
    this.play = new GameplayViewModel(repository, (snapshot: GameplaySnapshot) => {
      if (this.gate === 'home' && snapshot.detail.player === this.player.id) {
        this.publishDetail(snapshot.detail);
      }
    }, (message: string) => {
      this.logout();
      this.error = message;
    }, createRequestIdentity, (player: Player) => {
      if (this.gate === 'home' && player.id === this.player.id) {
        // A full answer settlement supersedes an older in-flight player read.
        this.profileRevision++;
        this.interruptPlayerPoll();
        this.acceptPlayer(player);
        this.schedulePlayerPoll();
      }
    }, () => this.gate === 'home' ? this.player : null);
  }

  private message(error: Object): string {
    if (error instanceof Error && error.message.length > 0) {
      return error.message;
    }
    return '请求失败，请稍后重试。';
  }

  private sessionExpired(error: Object): boolean {
    return error instanceof GameFailure && error.status === 401;
  }

  private fatalPlayer(error: Object): boolean {
    return error instanceof GameFailure && (error.status === 401 || error.status === 403 ||
      error.status === 404 || error.status === 410 || error.code === 'SESSION_OFFLINE' ||
      error.code === 'ACCOUNT_DISABLED' || error.code === 'PASSWORD_CHANGE_REQUIRED');
  }

  private rejectPlayerSession(error: Object): void {
    const message: string = this.message(error);
    this.logout();
    this.error = message;
    this.errorCode = error instanceof GameFailure ? error.code : 'UNKNOWN_ERROR';
  }

  private passwordMessage(error: Object): string {
    if (error instanceof GameFailure && (error.code === 'NETWORK_ERROR' ||
      error.code === 'TIMEOUT' || error.code === 'CONTRACT_ERROR' || error.status >= 500)) {
      return '密码修改结果尚未确认。请退出登录，尝试使用新密码登录确认结果。';
    }
    return this.message(error);
  }

  private acceptPlayer(player: Player): void {
    const identityChanged: boolean = this.player.id !== player.id;
    const avatarChanged: boolean = identityChanged || this.player.avatar !== player.avatar;
    this.player = player;
    if (identityChanged || !this.profileDirty) {
      this.profileName = player.displayName;
    }
    this.gate = player.mustChangePassword ? 'password' : 'home';
    this.play.bindOwner(player.mustChangePassword ? '' : player.id);
    this.play.setPlayerSyncFailed(false);
    this.narrative.bindOwner(player.mustChangePassword ? '' : player.id);
    this.starLetters.bindOwner(player.mustChangePassword ? '' : player.id);
    this.journey.bindOwner(player.mustChangePassword ? '' : player.id);
    this.rewards.bindOwner(player.mustChangePassword ? '' : player.id);
    this.lobbyUnread.bindOwner(player.mustChangePassword ? '' : player.id);
    this.pushSubscriptions.bindOwner(player.mustChangePassword ? '' : player.id);
    this.onboardingSubscriptions.bindOwner(player.mustChangePassword ? '' : player.id);
    if (avatarChanged) {
      this.avatarRequest++;
      this.avatarImage = null;
      this.avatarBusy = false;
      this.avatarError = '';
    }
    if (player.mustChangePassword) {
      this.setLobbyPolling(false);
      this.lobbyHasList = false;
      this.stopBriefingSync();
      this.setGameplayPlayerPolling(false);
      this.items = [];
      this.clearDetail();
      this.listError = '';
      this.detailError = '';
    } else if (player.avatar.length > 0 && this.avatarImage === null && !this.avatarBusy &&
      this.avatarError.length === 0) {
      this.loadAvatar();
    }
  }

  openProfile(): void {
    if (this.gate !== 'home') {
      return;
    }
    if (!this.profileDirty) {
      this.profileName = this.player.displayName;
    }
    if (this.player.avatar.length > 0 && this.avatarImage === null && !this.avatarBusy &&
      this.avatarError.length === 0) {
      this.loadAvatar();
    }
  }

  editProfileName(value: string): void {
    if (this.profileBusy || this.gate !== 'home' || value === this.profileName) {
      return;
    }
    this.profileName = value;
    this.profileDirty = value !== this.player.displayName || this.profileUpload !== null;
    this.profileError = '';
    this.profileSaved = false;
  }

  selectProfileAvatar(upload: AvatarUpload | null): void {
    if (this.profileBusy || this.gate !== 'home') {
      return;
    }
    this.profileUpload = upload;
    if (upload !== null) {
      const preview: AvatarImage = new AvatarImage();
      preview.data = upload.data;
      preview.mimeType = upload.mimeType;
      this.profilePreview = preview;
    } else {
      this.profilePreview = null;
    }
    this.profileDirty = this.profileName !== this.player.displayName || upload !== null;
    this.profileError = '';
    this.profileSaved = false;
  }

  reportProfileError(message: string): void {
    if (this.gate === 'home') {
      this.profileError = message;
      this.profileSaved = false;
    }
  }

  reportAvatarDecodeFailure(image: AvatarImage): void {
    if (this.gate !== 'home') {
      return;
    }
    if (image === this.profilePreview) {
      this.profilePreview = null;
      this.profileUpload = null;
      this.profileDirty = this.profileName !== this.player.displayName;
      this.profileSaved = false;
      this.profileError = '头像预览失败，请重新选择照片。';
    } else if (image === this.avatarImage) {
      this.avatarImage = null;
      this.avatarError = '头像读取失败，请重试。';
    }
  }

  async loadAvatar(forceRefresh: boolean = false): Promise<void> {
    if (this.gate !== 'home' || this.avatarBusy || this.securityUnconfirmed) {
      return;
    }
    const generation: number = this.generation;
    const request: number = ++this.avatarRequest;
    const avatar: string = this.player.avatar;
    this.avatarBusy = true;
    this.avatarError = '';
    try {
      const image: AvatarImage | null = await this.repository.avatar(forceRefresh);
      if (generation === this.generation && request === this.avatarRequest && avatar === this.player.avatar &&
        this.gate === 'home') {
        this.avatarImage = image;
        this.avatarError = '';
      }
    } catch (error) {
      if (generation === this.generation && request === this.avatarRequest && this.gate === 'home') {
        if (this.sessionExpired(error as Object) && !(error instanceof GameFailure && error.code === 'AVATAR_FETCH_FAILED')) {
          const message: string = this.message(error as Object);
          this.logout();
          this.error = message;
        } else {
          this.avatarError = '头像读取失败，请重试。';
        }
      }
    } finally {
      if (generation === this.generation && request === this.avatarRequest) {
        this.avatarBusy = false;
      }
    }
  }

  async saveProfile(): Promise<void> {
    if (this.gate !== 'home' || this.profileBusy || this.securityBusy || this.securityUnconfirmed) {
      return;
    }
    const validation: string = validateDisplayName(this.profileName);
    if (validation.length > 0) {
      this.profileError = validation;
      this.profileSaved = false;
      return;
    }
    const generation: number = this.generation;
    this.profileRevision++;
    this.interruptPlayerPoll();
    this.interruptLobbyPoll();
    this.profileBusy = true;
    this.profileError = '';
    this.profileSaved = false;
    try {
      const player: Player = await this.repository.updateProfile(this.profileName.trim(), this.profileUpload);
      if (generation !== this.generation) {
        return;
      }
      this.acceptPlayer(player);
      this.profileName = player.displayName;
      this.profileDirty = false;
      this.profileUpload = null;
      this.profilePreview = null;
      this.profileSaved = true;
    } catch (error) {
      if (generation === this.generation) {
        const message: string = this.message(error as Object);
        if (this.sessionExpired(error as Object)) {
          this.logout();
          this.error = message;
        } else {
          this.profileError = message;
        }
      }
    } finally {
      if (generation === this.generation) {
        this.profileBusy = false;
        this.schedulePlayerPoll();
        this.scheduleLobbyPoll();
      }
    }
  }

  clearSecurityFeedback(): void {
    if (!this.securityBusy) {
      this.securitySaved = false;
      if (!this.securityUnconfirmed) {
        this.securityError = '';
      }
    }
  }

  async changeAccountPassword(oldPassword: string, password: string, confirmation: string): Promise<void> {
    if (this.gate !== 'home' || this.profileBusy || this.securityBusy || this.securityUnconfirmed) {
      return;
    }
    const validation: string = validatePasswordChange(oldPassword, password, confirmation);
    if (validation.length > 0) {
      this.securityError = validation;
      this.securitySaved = false;
      return;
    }
    let generation: number = this.generation;
    this.profileRevision++;
    this.interruptPlayerPoll();
    this.interruptLobbyPoll();
    this.securityBusy = true;
    this.cancelAssignmentRead();
    this.securityError = '';
    this.securitySaved = false;
    try {
      const player: Player = await this.repository.changePassword(oldPassword, password, confirmation);
      if (generation !== this.generation) {
        return;
      }
      generation = ++this.generation;
      this.play.reset();
      this.narrative.close();
      this.starLetters.bindOwner('');
      this.journey.bindOwner('');
      this.rewards.bindOwner('');
      this.pushSubscriptions.bindOwner('');
      this.onboardingSubscriptions.bindOwner('');
      this.listBusy = false;
      this.avatarRequest++;
      this.avatarBusy = false;
      this.acceptPlayer(player);
      this.securitySaved = true;
      this.securitySuccessRevision++;
    } catch (error) {
      if (generation === this.generation) {
        if (this.handlePasswordStorageFailure(error as Object)) { return; }
        const message: string = this.passwordMessage(error as Object);
        if (this.sessionExpired(error as Object)) {
          this.logout();
          this.error = message;
        } else {
          this.securityError = message;
          this.securityUnconfirmed = error instanceof GameFailure && (error.code === 'NETWORK_ERROR' ||
            error.code === 'TIMEOUT' || error.code === 'CONTRACT_ERROR' || error.status >= 500);
        }
      }
    } finally {
      if (generation === this.generation) {
        this.securityBusy = false;
        this.scheduleBriefingPoll();
        this.schedulePlayerPoll();
        this.scheduleLobbyPoll();
      }
    }
  }

  async restoreSession(): Promise<void> {
    if (this.mode !== 'https' || this.busy || (this.gate !== 'login' && this.gate !== 'restore-error')) { return; }
    const generation: number = ++this.generation;
    const read: ReadCancellation = new ReadCancellation();
    this.restoreRead = read;
    this.gate = 'restoring';
    this.busy = true;
    this.error = '';
    this.errorCode = '';
    this.loginNetworkError = false;
    try {
      const player: Player | null = await this.repository.restoreSession(read);
      if (generation !== this.generation) { return; }
      if (player === null) {
        this.gate = 'login';
        return;
      }
      this.acceptPlayer(player);
      if (!player.mustChangePassword) { await this.refreshHome(false); }
    } catch (error) {
      if (generation === this.generation) {
        this.errorCode = error instanceof GameFailure ? error.code : 'UNKNOWN_ERROR';
        if (this.errorCode === 'CREDENTIAL_CLEAR_ERROR') {
          this.gate = 'signout-error';
          this.error = this.message(error as Object);
        } else if (isRestoredSessionInvalid(error as Object)) {
          this.gate = 'login';
          this.error = '登录已失效，请重新登录。';
        } else {
          this.gate = 'restore-error';
          this.error = this.message(error as Object);
        }
      }
    } finally {
      if (generation === this.generation) {
        this.restoreRead = null;
        this.busy = false;
      }
    }
  }

  async login(account: string, password: string, beforeEnterHome?: () => void): Promise<void> {
    if (this.busy || this.gate !== 'login') {
      return;
    }
    this.loginNetworkError = false;
    if (account.trim().length === 0 || password.length === 0) {
      this.error = '请输入账号和密码。';
      this.errorCode = 'VALIDATION_ERROR';
      return;
    }
    const generation: number = ++this.generation;
    this.busy = true;
    this.error = '';
    this.errorCode = '';
    try {
      const player: Player = await this.repository.login(account, password);
      if (generation !== this.generation) {
        return;
      }
      if (!player.mustChangePassword) {
        try {
          beforeEnterHome?.();
        } catch {
          // Optional system form handling cannot block a verified login.
        }
      }
      this.acceptPlayer(player);
      if (!player.mustChangePassword) {
        await this.refresh();
      }
    } catch (error) {
      if (generation === this.generation) {
        const connectionMessage: string = loginConnectionMessage(error as Object);
        this.loginNetworkError = connectionMessage.length > 0;
        this.error = this.loginNetworkError ? connectionMessage : this.message(error as Object);
        this.errorCode = error instanceof GameFailure ? error.code : 'UNKNOWN_ERROR';
        if (this.errorCode === 'CREDENTIAL_CLEAR_ERROR') { this.gate = 'signout-error'; }
      }
    } finally {
      if (generation === this.generation) {
        this.busy = false;
      }
    }
  }

  clearLoginInputError(): void {
    if (this.gate === 'login' && !this.busy && !this.loginNetworkError) {
      this.error = '';
      this.errorCode = '';
    }
  }

  async changePassword(oldPassword: string, password: string, confirmation: string): Promise<void> {
    if (this.busy || this.gate !== 'password') {
      return;
    }
    const validation: string = validatePasswordChange(oldPassword, password, confirmation);
    if (validation.length > 0) {
      this.error = validation;
      this.errorCode = 'VALIDATION_ERROR';
      return;
    }
    let generation: number = this.generation;
    this.busy = true;
    this.error = '';
    this.errorCode = '';
    try {
      const player: Player = await this.repository.changePassword(oldPassword, password, confirmation);
      if (generation !== this.generation) {
        return;
      }
      // Credential rotation invalidates every response started under the previous token.
      generation = ++this.generation;
      this.cancelAssignmentRead();
      this.listBusy = false;
      this.acceptPlayer(player);
      if (!player.mustChangePassword) {
        await this.refresh();
      }
    } catch (error) {
      if (generation === this.generation) {
        if (this.handlePasswordStorageFailure(error as Object)) { return; }
        const message: string = this.passwordMessage(error as Object);
        if (this.sessionExpired(error as Object)) {
          this.logout();
        }
        this.error = message;
        this.errorCode = error instanceof GameFailure ? error.code : 'UNKNOWN_ERROR';
      }
    } finally {
      if (generation === this.generation) {
        this.busy = false;
      }
    }
  }

  private handlePasswordStorageFailure(error: Object): boolean {
    if (!(error instanceof GameFailure) || (error.code !== 'PASSWORD_CHANGED_SESSION_NOT_SAVED' &&
      error.code !== 'CREDENTIAL_CLEAR_ERROR')) { return false; }
    this.logout();
    this.error = error.message;
    this.errorCode = error.code;
    return true;
  }

  async refresh(): Promise<void> {
    await this.refreshHome(true);
  }

  private async refreshHome(recheckPlayer: boolean): Promise<void> {
    if (this.gate !== 'home' || this.listBusy || this.profileBusy || this.securityBusy || this.securityUnconfirmed) {
      return;
    }
    const generation: number = this.generation;
    const profileRevision: number = this.profileRevision;
    this.interruptPlayerPoll();
    this.interruptLobbyPoll();
    this.listBusy = true;
    this.listError = '';
    this.tick();
    let readingPlayer: boolean = recheckPlayer;
    try {
      if (recheckPlayer) {
        const player: Player = await this.repository.me();
        readingPlayer = false;
        if (generation !== this.generation || profileRevision !== this.profileRevision) { return; }
        this.acceptPlayer(player);
        if (this.gate !== 'home') { return; }
        this.setLobbyReadFailed(true, false);
      }
      const items: AssignmentSummary[] = await this.fetchLobbyAssignments(() =>
        generation === this.generation && this.gate === 'home' && profileRevision === this.profileRevision);
      if (generation !== this.generation || this.gate !== 'home' || profileRevision !== this.profileRevision) {
        return;
      }
      this.publishLobbyAssignments(items);
      this.setLobbyReadFailed(false, false);
    } catch (error) {
      if (generation === this.generation && profileRevision === this.profileRevision) {
        if (this.fatalPlayer(error as Object)) {
          this.rejectPlayerSession(error as Object);
        } else if (!(error instanceof GameFailure && error.code === 'CANCELLED')) {
          if (this.lobbyHasList) {
            this.setLobbyReadFailed(readingPlayer, true);
          } else {
            this.listError = this.message(error as Object);
          }
          if (readingPlayer && (this.play.visible || this.canPollBriefing())) { this.play.setPlayerSyncFailed(true); }
        }
      }
    } finally {
      if (generation === this.generation) {
        this.listBusy = false;
        this.schedulePlayerPoll();
        this.scheduleLobbyPoll();
      }
    }
  }

  setLobbyPolling(active: boolean): void {
    this.lobbyPolling = active;
    if (active) {
      this.scheduleLobbyPoll();
    } else {
      this.interruptLobbyPoll();
      this.lobbyPlayerReadFailed = false;
      this.lobbyListReadFailed = false;
      this.dismissLobbySyncNotice();
    }
  }

  setHomeFeedActive(active: boolean): void {
    const enabled: boolean = active && !this.homeFeedUnavailable && this.repository.home !== undefined;
    if (this.homeFeedActive === enabled) { return; }
    this.homeFeedActive = enabled;
    this.rewards.setHomeFeedActive(enabled);
    this.journey.setHomeFeedActive(enabled);
  }

  usesHomeFeed(): boolean { return this.homeFeedActive; }

  private async fetchLobbyAssignments(current: () => boolean, cancellation?: ReadCancellation): Promise<AssignmentSummary[]> {
    if (this.homeFeedActive && this.repository.home !== undefined) {
      const rewardRevision: number = this.rewards.feedRevision();
      const journeyRevision: number = this.journey.feedRevision();
      try {
        const feed: LobbyFeed = await this.repository.home(cancellation);
        if (current()) {
          this.rewards.acceptHomeEntries(feed.rewards, rewardRevision);
          this.journey.acceptHomeEntries(feed.notifications, journeyRevision);
        }
        return feed.assignments;
      } catch (error) {
        if (!current()) { return []; }
        if (!(error instanceof GameFailure && error.status === 404 && error.code === 'NOT_FOUND')) {
          const failure: Error = error instanceof Error ? error : new Error('暂时无法同步旅途更新。');
          this.rewards.acceptHomeFailure(failure, rewardRevision);
          this.journey.acceptHomeFailure(failure, journeyRevision);
          throw failure;
        }
        this.homeFeedUnavailable = true;
        this.setHomeFeedActive(false);
        void this.journey.refresh();
      }
    }
    return await this.repository.assignments(cancellation);
  }

  dismissLobbySyncNotice(): void {
    this.showLobbySyncNotice = false;
  }

  private canPollLobby(): boolean {
    return this.lobbyPolling && this.gate === 'home' && this.player.id.length > 0 &&
      !this.listBusy && !this.profileBusy && !this.securityBusy && !this.securityUnconfirmed;
  }

  private interruptLobbyPoll(): void {
    if (this.lobbyPollTimer !== -1) { clearTimeout(this.lobbyPollTimer); this.lobbyPollTimer = -1; }
    const read: LobbyRead | null = this.lobbyRead;
    this.lobbyRead = null;
    read?.player.cancel();
    read?.assignments.cancel();
  }

  private scheduleLobbyPoll(): void {
    if (this.lobbyPollTimer !== -1 || this.lobbyRead !== null || !this.canPollLobby()) { return; }
    this.lobbyPollTimer = setTimeout(() => {
      this.lobbyPollTimer = -1;
      void this.pollLobby();
    }, this.lobbySyncIntervalMs);
  }

  private async pollLobby(): Promise<void> {
    if (!this.canPollLobby()) { return; }
    const read: LobbyRead = new LobbyRead(this.generation, this.profileRevision);
    this.lobbyRead = read;
    try {
      await Promise.all([this.pollLobbyPlayer(read), this.pollLobbyAssignments(read)]);
    } finally {
      if (this.lobbyRead === read) {
        this.lobbyRead = null;
        this.scheduleLobbyPoll();
      }
    }
  }

  private currentLobbyRead(read: LobbyRead): boolean {
    return this.lobbyRead === read && read.generation === this.generation &&
      read.profileRevision === this.profileRevision && this.canPollLobby();
  }

  private async pollLobbyPlayer(read: LobbyRead): Promise<void> {
    try {
      const player: Player = await this.repository.me(read.player);
      if (!this.currentLobbyRead(read)) { return; }
      this.acceptPlayer(player);
      this.setLobbyReadFailed(true, false);
    } catch (error) {
      this.failLobbyRead(read, true, error as Object);
    }
  }

  private async pollLobbyAssignments(read: LobbyRead): Promise<void> {
    try {
      const items: AssignmentSummary[] = await this.fetchLobbyAssignments(() => this.currentLobbyRead(read),
        read.assignments);
      if (!this.currentLobbyRead(read)) { return; }
      this.publishLobbyAssignments(items);
      this.setLobbyReadFailed(false, false);
    } catch (error) {
      this.failLobbyRead(read, false, error as Object);
    }
  }

  private publishLobbyAssignments(items: AssignmentSummary[]): void {
    this.lobbyHasList = true;
    this.listError = '';
    if (JSON.stringify(items) !== JSON.stringify(this.items)) { this.items = items; }
  }

  private failLobbyRead(read: LobbyRead, player: boolean, error: Object): void {
    if (!this.currentLobbyRead(read) || (error instanceof GameFailure && error.code === 'CANCELLED')) { return; }
    if (this.fatalPlayer(error)) {
      this.rejectPlayerSession(error);
    } else if (!player && !this.lobbyHasList) {
      this.listError = this.message(error);
    } else {
      this.setLobbyReadFailed(player, true);
    }
  }

  private setLobbyReadFailed(player: boolean, failed: boolean): void {
    const wasFailed: boolean = this.lobbyPlayerReadFailed || this.lobbyListReadFailed;
    if (player) { this.lobbyPlayerReadFailed = failed; } else { this.lobbyListReadFailed = failed; }
    if (!this.lobbyPlayerReadFailed && !this.lobbyListReadFailed) {
      this.dismissLobbySyncNotice();
    } else if (!wasFailed) {
      this.showLobbySyncNotice = true;
    }
  }

  setGameplayPlayerPolling(active: boolean): void {
    this.gameplayPlayerPolling = active;
    this.updatePlayerPolling();
  }

  private updatePlayerPolling(): void {
    if (this.canPollPlayer()) { this.schedulePlayerPoll(); } else { this.interruptPlayerPoll(); }
  }

  private canPollPlayer(): boolean {
    const gameplay: boolean = this.gameplayPlayerPolling && this.play.visible && this.play.error.length === 0;
    return (gameplay || this.canPollBriefing()) && this.gate === 'home' &&
      !this.listBusy && !this.profileBusy && !this.securityBusy && !this.securityUnconfirmed &&
      !this.play.refreshing && !this.play.loading && !this.play.starting;
  }

  private interruptPlayerPoll(): void {
    if (this.playerPollTimer !== -1) { clearTimeout(this.playerPollTimer); this.playerPollTimer = -1; }
    const read: ReadCancellation | null = this.playerPollRead;
    this.playerPollRead = null;
    read?.cancel();
  }

  private schedulePlayerPoll(): void {
    if (this.playerPollTimer !== -1 || this.playerPollRead !== null || !this.canPollPlayer()) { return; }
    this.playerPollTimer = setTimeout(() => {
      this.playerPollTimer = -1;
      void this.pollPlayer();
    }, ASSIGNMENT_SYNC_INTERVAL_MS);
  }

  private async pollPlayer(): Promise<void> {
    if (!this.canPollPlayer()) { return; }
    const read: ReadCancellation = new ReadCancellation();
    this.playerPollRead = read;
    const generation: number = this.generation;
    const revision: number = this.profileRevision;
    try {
      const player: Player = await this.repository.me(read);
      if (this.playerPollRead === read && generation === this.generation && revision === this.profileRevision &&
        this.canPollPlayer()) {
        this.acceptPlayer(player);
      }
    } catch (error) {
      if (this.playerPollRead === read && generation === this.generation && revision === this.profileRevision &&
        this.canPollPlayer()) {
        if (this.fatalPlayer(error as Object)) {
          this.rejectPlayerSession(error as Object);
        } else if (!(error instanceof GameFailure && error.code === 'CANCELLED')) {
          this.play.setPlayerSyncFailed(true);
        }
      }
    } finally {
      if (this.playerPollRead === read) {
        this.playerPollRead = null;
        this.schedulePlayerPoll();
      }
    }
  }

  private publishDetail(detail: AssignmentDetail): void {
    if (detail.status !== 'assigned') { this.briefingPresentation = null; }
    this.detail = detail;
    this.items = this.items.map((item: AssignmentSummary) => item.id === detail.id ? detail : item);
    const serverTime: number = Date.parse(detail.serverTime);
    if (Number.isFinite(serverTime)) {
      this.serverOffset = serverTime - Date.now();
    }
    this.tick();
  }

  private clearDetail(): void {
    this.briefingPresentation = null;
    this.detail = new AssignmentDetail();
  }

  setBriefingPolling(id: string): void {
    if (id === this.briefingAssignmentId) { return; }
    this.briefingAssignmentId = id;
    if (id !== this.openingId) { this.cancelAssignmentRead(); }
    this.scheduleBriefingPoll();
    this.updatePlayerPolling();
  }

  stopBriefingSync(): void {
    this.briefingAssignmentId = '';
    this.cancelAssignmentRead();
    this.updatePlayerPolling();
  }

  private canPollBriefing(): boolean {
    return this.gate === 'home' && !this.securityBusy && !this.securityUnconfirmed &&
      this.briefingAssignmentId.length > 0 && this.detail.id === this.briefingAssignmentId &&
      this.detail.player === this.player.id && this.detail.status === 'assigned' &&
      !this.play.visible && !this.play.starting && !this.play.retryEntry;
  }

  private cancelAssignmentRead(): void {
    clearTimeout(this.briefingPollTimer);
    this.briefingPollTimer = -1;
    const read: ReadCancellation | null = this.detailRead;
    this.detailRead = null;
    this.openingId = '';
    this.detailBusy = false;
    read?.cancel();
  }

  private scheduleBriefingPoll(): void {
    if (this.briefingPollTimer !== -1 || this.detailRead !== null || !this.canPollBriefing()) { return; }
    this.briefingPollTimer = setTimeout(() => {
      this.briefingPollTimer = -1;
      if (this.canPollBriefing()) { void this.readAssignment(this.briefingAssignmentId, true); }
    }, ASSIGNMENT_SYNC_INTERVAL_MS);
  }

  async enterAssignment(id: string): Promise<void> {
    if (this.detail.id !== id || this.detail.player !== this.player.id || this.detail.status !== 'assigned' ||
      this.gate !== 'home' || this.securityBusy || this.securityUnconfirmed || this.detailBusy ||
      this.play.visible || this.play.starting) {
      return;
    }
    this.cancelAssignmentRead();
    this.interruptPlayerPoll();
    await this.play.enter(id, this.detail.clueIds);
    this.scheduleBriefingPoll();
    this.schedulePlayerPoll();
  }

  async openAssignment(id: string): Promise<void> {
    if (this.gate !== 'home' || this.securityBusy || this.securityUnconfirmed || id.length === 0 ||
      this.play.starting || this.play.retryEntry || this.play.visible || (this.detailBusy && id === this.openingId)) {
      return;
    }
    this.cancelAssignmentRead();
    await this.readAssignment(id, false);
  }

  private async readAssignment(id: string, quiet: boolean): Promise<void> {
    const generation: number = this.generation;
    const playerId: string = this.player.id;
    const read: ReadCancellation = new ReadCancellation();
    this.detailRead = read;
    this.openingId = id;
    this.detailBusy = !quiet;
    this.detailError = '';
    if (this.detail.id !== id) { this.clearDetail(); }
    try {
      const snapshot: GameplaySnapshot = await this.repository.gameplay(id, read);
      if (!this.isAssignmentReadCurrent(generation, read)) { return; }
      if (snapshot.detail.id !== id || snapshot.detail.player !== playerId) {
        throw new GameFailure('CONTRACT_ERROR', '服务返回的场次身份不一致。');
      }
      if (!quiet && snapshot.detail.status === 'assigned') { this.lobbyUnread.acknowledgeAssignments([id]); }
      this.play.setAssignmentSyncFailed(false);
      if (!this.play.restoreFromBriefing(snapshot)) {
        if (snapshot.detail.status === 'assigned') { this.briefingPresentation = snapshot.presentation; }
        this.publishDetail(snapshot.detail);
      }
    } catch (error) {
      if (this.isAssignmentReadCurrent(generation, read)) { this.acceptAssignmentError(id, error as Object); }
    } finally {
      if (this.isAssignmentReadCurrent(generation, read)) {
        this.detailRead = null;
        this.openingId = '';
        this.detailBusy = false;
        this.scheduleBriefingPoll();
        this.updatePlayerPolling();
      }
    }
  }

  private isAssignmentReadCurrent(generation: number, read: ReadCancellation): boolean {
    return this.detailRead === read && generation === this.generation && this.gate === 'home';
  }

  private acceptAssignmentError(id: string, error: Object): void {
    if (error instanceof GameFailure && error.code === 'CANCELLED') { return; }
    if (this.sessionExpired(error) || (error instanceof GameFailure &&
      (error.code === 'ACCOUNT_DISABLED' || error.code === 'PASSWORD_CHANGE_REQUIRED'))) {
      this.rejectPlayerSession(error);
      return;
    }
    if (this.detail.id === id && this.briefingAssignmentId === id && this.play.transientRefreshFailure(error)) {
      this.play.setAssignmentSyncFailed(true);
      return;
    }
    this.play.setAssignmentSyncFailed(false);
    this.clearDetail();
    this.detailError = this.message(error);
  }

  tick(): void {
    this.now = Date.now() + this.serverOffset;
    this.play.tick();
  }

  attachPush(device: PushDevice): void { this.repository.attachPush?.(device); }

  retryPushRemoval(): void {
    if (this.gate === 'login' && !this.busy) { this.repository.retryPushRemoval?.(); }
  }

  pushSyncOwner(): string {
    if (this.gate !== 'home' || this.securityBusy || this.securityUnconfirmed || this.player.id.length === 0) {
      return '';
    }
    return `${this.generation}:${this.player.id}`;
  }

  async syncPush(force: boolean): Promise<PushStatus> {
    if (this.pushSyncOwner().length === 0) { return 'unknown'; }
    return await this.repository.syncPush?.(force) ?? 'unknown';
  }

  async matchesPushProfile(profileId: string): Promise<boolean> {
    if (this.gate !== 'home' || this.securityBusy || this.securityUnconfirmed) { return false; }
    return await this.repository.matchesPushProfile?.(profileId) ?? false;
  }

  /** Discard live account state and requests without forgetting the last saved login. */
  suspendSession(): void {
    if (this.gate === 'signout' || this.gate === 'signout-error') { return; }
    this.repository.suspendSession?.();
    this.gate = 'login';
    this.clearSessionState();
  }

  logout(): void {
    if (this.gate === 'signout') { return; }
    const clearing: Promise<void> = this.repository.logout();
    this.gate = this.mode === 'https' ? 'signout' : 'login';
    const generation: number = this.clearSessionState();
    void this.finishLogout(clearing, generation);
  }

  private clearSessionState(): number {
    const generation: number = ++this.generation;
    const restore: ReadCancellation | null = this.restoreRead;
    this.restoreRead = null;
    restore?.cancel();
    this.setLobbyPolling(false);
    this.setHomeFeedActive(false);
    this.lobbyHasList = false;
    this.stopBriefingSync();
    this.setGameplayPlayerPolling(false);
    this.play.reset();
    this.narrative.bindOwner('');
    this.starLetters.bindOwner('');
    this.journey.bindOwner('');
    this.rewards.bindOwner('');
    this.lobbyUnread.bindOwner('');
    this.pushSubscriptions.bindOwner('');
    this.onboardingSubscriptions.bindOwner('');
    this.profileRevision++;
    this.avatarRequest++;
    this.busy = false;
    this.error = '';
    this.errorCode = '';
    this.loginNetworkError = false;
    this.player = new Player();
    this.items = [];
    this.clearDetail();
    this.listBusy = false;
    this.detailBusy = false;
    this.listError = '';
    this.detailError = '';
    this.openingId = '';
    this.profileName = '';
    this.profileDirty = false;
    this.profileUpload = null;
    this.profilePreview = null;
    this.profileBusy = false;
    this.profileError = '';
    this.profileSaved = false;
    this.avatarImage = null;
    this.avatarBusy = false;
    this.avatarError = '';
    this.securityBusy = false;
    this.securityError = '';
    this.securitySaved = false;
    this.securityUnconfirmed = false;
    this.serverOffset = 0;
    this.now = Date.now();
    return generation;
  }

  private async finishLogout(clearing: Promise<void>, generation: number): Promise<void> {
    try {
      await clearing;
      if (generation === this.generation && this.gate === 'signout') { this.gate = 'login'; }
    } catch (error) {
      if (generation === this.generation) {
        this.gate = 'signout-error';
        this.error = this.message(error as Object);
        this.errorCode = error instanceof GameFailure ? error.code : 'UNKNOWN_ERROR';
      }
    }
  }
}
