import { GameRepository } from '../business/GameRepository';
import { AssignmentDetail, AssignmentSummary, GameFailure, Player, Rank, validatePasswordChange } from '../business/models';
import { decodeAssignment } from './DtoDecoder';

export function sampleAssignment(): AssignmentDetail {
  const value: AssignmentDetail = new AssignmentDetail();
  value.id = 'assignment1';
  value.player = 'playeralice';
  value.session = 'session1';
  value.title = '星辰探险';
  value.description = '解开谜题，发现惊喜。';
  value.minLevel = 1;
  value.totalLevels = 2;
  value.serverTime = new Date().toISOString();
  return value;
}

export class MockGameRepository implements GameRepository {
  readonly mode: string = 'mock';
  delayMs: number;
  nextFailure: GameFailure | null = null;
  calls: string[] = [];
  emptyAssignments: boolean = false;
  fixture: AssignmentDetail = sampleAssignment();
  private generation: number = 0;
  private authenticated: boolean = false;
  private currentPassword: string = 'Starward1234';
  private mustChange: boolean = true;

  constructor(delayMs: number = 160) {
    this.delayMs = delayMs;
  }

  private player(): Player {
    const player: Player = new Player();
    player.id = 'playeralice';
    player.account = 'alice';
    player.displayName = '远航者';
    player.mustChangePassword = this.mustChange;
    const level: Rank = new Rank();
    level.id = 'rank1';
    level.name = '初见';
    level.order = 1;
    player.level = level;
    const next: Rank = new Rank();
    next.id = 'rank2';
    next.name = '同行';
    next.order = 2;
    next.minTotalXp = 100;
    player.nextLevel = next;
    return player;
  }

  private assertCurrent(generation: number): void {
    if (generation !== this.generation) {
      throw new GameFailure('CANCELLED', '账号已切换，本次请求已取消。');
    }
  }

  private requireSession(): number {
    if (!this.authenticated) {
      throw new GameFailure('UNAUTHORIZED', '请重新登录。', 401);
    }
    return this.generation;
  }

  private async pause(operation: string, generation: number): Promise<void> {
    this.calls.push(operation);
    const failure: GameFailure | null = this.nextFailure;
    this.nextFailure = null;
    await new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, this.delayMs);
    });
    this.assertCurrent(generation);
    if (failure !== null) {
      if (failure.status === 401) {
        this.logout();
      }
      throw failure;
    }
  }

  async login(account: string, password: string): Promise<Player> {
    this.logout();
    const generation: number = this.generation;
    await this.pause('login', generation);
    if (account.trim().toLowerCase() !== 'alice' || password !== this.currentPassword) {
      throw new GameFailure('INVALID_CREDENTIALS', '账号或密码不正确', 400);
    }
    this.authenticated = true;
    return this.player();
  }

  async me(): Promise<Player> {
    const generation: number = this.requireSession();
    await this.pause('me', generation);
    return this.player();
  }

  async changePassword(oldPassword: string, password: string, confirmation: string): Promise<Player> {
    const generation: number = this.requireSession();
    const validation: string = validatePasswordChange(oldPassword, password, confirmation);
    if (validation.length > 0) {
      throw new GameFailure('VALIDATION_ERROR', validation);
    }
    await this.pause('changePassword', generation);
    if (oldPassword !== this.currentPassword) {
      throw new GameFailure('INVALID_PASSWORD', '当前密码不正确，请重新输入。', 400);
    }
    this.currentPassword = password;
    this.mustChange = false;
    this.generation++;
    return this.player();
  }

  private ensureChanged(): void {
    if (this.mustChange) {
      throw new GameFailure('PASSWORD_CHANGE_REQUIRED', '首次登录，请先修改密码', 403);
    }
  }

  async assignments(): Promise<AssignmentSummary[]> {
    const generation: number = this.requireSession();
    this.ensureChanged();
    await this.pause('assignments', generation);
    if (this.emptyAssignments) {
      return [];
    }
    return [decodeAssignment(JSON.stringify(this.fixture))];
  }

  async assignment(id: string): Promise<AssignmentDetail> {
    const generation: number = this.requireSession();
    this.ensureChanged();
    await this.pause('assignment', generation);
    if (id !== this.fixture.id) {
      throw new GameFailure('NOT_FOUND', '这段旅程暂时无法访问。', 404);
    }
    const detail: AssignmentDetail = decodeAssignment(JSON.stringify(this.fixture));
    detail.serverTime = new Date().toISOString();
    return detail;
  }

  logout(): void {
    this.generation++;
    this.authenticated = false;
  }
}
