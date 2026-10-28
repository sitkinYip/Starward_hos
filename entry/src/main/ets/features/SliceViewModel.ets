import { GameRepository } from '../business/GameRepository';
import { AssignmentDetail, AssignmentSummary, GameFailure, Player, validatePasswordChange } from '../business/models';
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
  @Trace now: number = Date.now();
  readonly mode: string;
  private readonly repository: GameRepository;
  private generation: number = 0;
  private detailRequest: number = 0;
  private openingId: string = '';
  private serverOffset: number = 0;

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
    this.player = player;
    this.gate = player.mustChangePassword ? 'password' : 'home';
    if (player.mustChangePassword) {
      this.items = [];
      this.detail = new AssignmentDetail();
      this.detailRequest++;
      this.openingId = '';
      this.detailBusy = false;
      this.listError = '';
      this.detailError = '';
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
    if (this.gate !== 'home' || this.listBusy) {
      return;
    }
    const generation: number = this.generation;
    this.listBusy = true;
    this.listError = '';
    this.tick();
    try {
      const player: Player = await this.repository.me();
      if (generation !== this.generation) {
        return;
      }
      this.acceptPlayer(player);
      if (this.gate !== 'home') {
        return;
      }
      const items: AssignmentSummary[] = await this.repository.assignments();
      if (generation !== this.generation || this.gate !== 'home') {
        return;
      }
      this.items = items;
    } catch (error) {
      if (generation === this.generation) {
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
    if (this.gate !== 'home' || id.length === 0 || (this.detailBusy && id === this.openingId)) {
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
    this.serverOffset = 0;
    this.now = Date.now();
  }
}
