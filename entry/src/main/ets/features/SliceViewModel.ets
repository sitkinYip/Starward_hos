import { GameRepository } from '../business/GameRepository';
import { AssignmentDetail, AssignmentSummary, AvatarImage, AvatarUpload, GameFailure, Player,
  validateDisplayName, validatePasswordChange } from '../business/models';
import { MockGameRepository } from '../data/MockGameRepository';

@ObservedV2
export class SliceViewModel {
  @Trace gate: string = 'login';
  @Trace busy: boolean = false;
  @Trace error: string = '';
  @Trace errorCode: string = '';
  @Trace player: Player = new Player();
  @Trace items: AssignmentSummary[] = [];
  @Trace detail: AssignmentDetail = new AssignmentDetail();
  @Trace listBusy: boolean = false;
  @Trace detailBusy: boolean = false;
  @Trace listError: string = '';
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
  private readonly repository: GameRepository;
  private generation: number = 0;
  private detailRequest: number = 0;
  private openingId: string = '';
  private serverOffset: number = 0;
  private profileDirty: boolean = false;
  private profileRevision: number = 0;
  private avatarRequest: number = 0;

  constructor(repository: GameRepository = new MockGameRepository()) {
    this.repository = repository;
    this.mode = repository.mode;
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
      error.status === 404 || error.status === 410 || error.code === 'SESSION_OFFLINE');
  }

  private passwordMessage(error: Object): string {
    if (error instanceof GameFailure && (error.code === 'NETWORK_ERROR' ||
      error.code === 'TIMEOUT' || error.code === 'CONTRACT_ERROR' || error.status >= 500)) {
      return '密码修改结果尚未确认。请退出登录，尝试使用新密码登录确认结果。';
    }
    return this.message(error);
  }

  private fatalDetail(error: Object): boolean {
    return error instanceof GameFailure &&
      (error.status === 403 || error.status === 404 || error.status === 410 || error.code === 'SESSION_OFFLINE');
  }

  private acceptPlayer(player: Player): void {
    const identityChanged: boolean = this.player.id !== player.id;
    const avatarChanged: boolean = identityChanged || this.player.avatar !== player.avatar;
    this.player = player;
    if (identityChanged || !this.profileDirty) {
      this.profileName = player.displayName;
    }
    this.gate = player.mustChangePassword ? 'password' : 'home';
    if (avatarChanged) {
      this.avatarRequest++;
      this.avatarImage = null;
      this.avatarBusy = false;
      this.avatarError = '';
    }
    if (player.mustChangePassword) {
      this.items = [];
      this.detail = new AssignmentDetail();
      this.detailRequest++;
      this.openingId = '';
      this.detailBusy = false;
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
    this.securityBusy = true;
    this.securityError = '';
    this.securitySaved = false;
    try {
      const player: Player = await this.repository.changePassword(oldPassword, password, confirmation);
      if (generation !== this.generation) {
        return;
      }
      generation = ++this.generation;
      this.detailRequest++;
      this.listBusy = false;
      this.detailBusy = false;
      this.openingId = '';
      this.avatarRequest++;
      this.avatarBusy = false;
      this.acceptPlayer(player);
      this.securitySaved = true;
      this.securitySuccessRevision++;
    } catch (error) {
      if (generation === this.generation) {
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
      }
    }
  }

  async login(account: string, password: string): Promise<void> {
    if (this.busy || this.gate !== 'login') {
      return;
    }
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
      this.acceptPlayer(player);
      if (!player.mustChangePassword) {
        await this.refresh();
      }
    } catch (error) {
      if (generation === this.generation) {
        this.error = this.message(error as Object);
        this.errorCode = error instanceof GameFailure ? error.code : 'UNKNOWN_ERROR';
      }
    } finally {
      if (generation === this.generation) {
        this.busy = false;
      }
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
      this.detailRequest++;
      this.listBusy = false;
      this.detailBusy = false;
      this.openingId = '';
      this.acceptPlayer(player);
      if (!player.mustChangePassword) {
        await this.refresh();
      }
    } catch (error) {
      if (generation === this.generation) {
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

  async refresh(): Promise<void> {
    if (this.gate !== 'home' || this.listBusy || this.profileBusy || this.securityBusy || this.securityUnconfirmed) {
      return;
    }
    const generation: number = this.generation;
    const profileRevision: number = this.profileRevision;
    this.listBusy = true;
    this.listError = '';
    this.tick();
    try {
      const player: Player = await this.repository.me();
      if (generation !== this.generation || profileRevision !== this.profileRevision) {
        return;
      }
      this.acceptPlayer(player);
      if (this.gate !== 'home') {
        return;
      }
      const items: AssignmentSummary[] = await this.repository.assignments();
      if (generation !== this.generation || this.gate !== 'home' || profileRevision !== this.profileRevision) {
        return;
      }
      this.items = items;
    } catch (error) {
      if (generation === this.generation && profileRevision === this.profileRevision) {
        const message: string = this.message(error as Object);
        if (this.fatalPlayer(error as Object)) {
          this.logout();
          this.error = message;
          this.errorCode = error instanceof GameFailure ? error.code : 'UNKNOWN_ERROR';
        } else {
          this.listError = message;
        }
      }
    } finally {
      if (generation === this.generation) {
        this.listBusy = false;
      }
    }
  }

  async openAssignment(id: string): Promise<void> {
    if (this.gate !== 'home' || this.securityUnconfirmed || id.length === 0 || (this.detailBusy && id === this.openingId)) {
      return;
    }
    const generation: number = this.generation;
    const request: number = ++this.detailRequest;
    this.openingId = id;
    this.detailBusy = true;
    this.detailError = '';
    if (this.detail.id !== id) {
      this.detail = new AssignmentDetail();
    }
    try {
      const detail: AssignmentDetail = await this.repository.assignment(id);
      if (generation !== this.generation || request !== this.detailRequest || this.gate !== 'home') {
        return;
      }
      this.detail = detail;
      const serverTime: number = Date.parse(detail.serverTime);
      if (Number.isFinite(serverTime)) {
        this.serverOffset = serverTime - Date.now();
      }
      this.tick();
    } catch (error) {
      if (generation === this.generation && request === this.detailRequest) {
        const message: string = this.message(error as Object);
        if (this.sessionExpired(error as Object)) {
          this.logout();
          this.error = message;
          this.errorCode = error instanceof GameFailure ? error.code : 'UNKNOWN_ERROR';
        } else {
          if (this.fatalDetail(error as Object)) {
            this.detail = new AssignmentDetail();
          }
          this.detailError = message;
        }
      }
    } finally {
      if (generation === this.generation && request === this.detailRequest) {
        this.detailBusy = false;
        this.openingId = '';
      }
    }
  }

  tick(): void {
    this.now = Date.now() + this.serverOffset;
  }

  logout(): void {
    this.generation++;
    this.detailRequest++;
    this.profileRevision++;
    this.avatarRequest++;
    this.repository.logout();
    this.gate = 'login';
    this.busy = false;
    this.error = '';
    this.errorCode = '';
    this.player = new Player();
    this.items = [];
    this.detail = new AssignmentDetail();
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
  }
}
