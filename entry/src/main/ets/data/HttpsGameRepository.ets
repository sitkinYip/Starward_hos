import { GameRepository } from '../business/GameRepository';
import { AssignmentDetail, AssignmentSummary, GameFailure, Player, validatePasswordChange } from '../business/models';
import { HttpTransport, NativeHttpTransport, TransportRequest, TransportResponse } from '../platform/HttpTransport';
import { decodeApiFailure, decodeAssignment, decodeAssignments, decodeLogin, decodePassword, decodePlayer,
  LoginResult, PasswordResult } from './DtoDecoder';

class LoginCommand {
  identity: string;
  password: string;

  constructor(identity: string, password: string) {
    this.identity = identity;
    this.password = password;
  }
}

class PasswordCommand {
  oldPassword: string;
  password: string;
  passwordConfirm: string;

  constructor(oldPassword: string, password: string, passwordConfirm: string) {
    this.oldPassword = oldPassword;
    this.password = password;
    this.passwordConfirm = passwordConfirm;
  }
}

export class HttpsGameRepository implements GameRepository {
  readonly mode: string = 'https';
  private readonly baseUrl: string;
  private readonly transport: HttpTransport;
  private generation: number = 0;
  private token: string = '';
  private playerId: string = '';

  constructor(baseUrl: string, transport: HttpTransport = new NativeHttpTransport()) {
    const normalized: string = baseUrl.replace(/\/+$/, '');
    if (!/^https:\/\/[^\s/?#@]+(?::\d+)?$/.test(normalized)) {
      throw new GameFailure('CONFIG_ERROR', '请配置隔离环境的 HTTPS 服务地址。');
    }
    this.baseUrl = normalized;
    this.transport = transport;
  }

  private assertCurrent(generation: number): void {
    if (generation !== this.generation) {
      throw new GameFailure('CANCELLED', '账号已切换，本次请求已取消。');
    }
  }

  private requireSession(): number {
    if (this.token.length === 0 || this.playerId.length === 0) {
      throw new GameFailure('UNAUTHORIZED', '请重新登录。', 401);
    }
    return this.generation;
  }

  private async request(path: string, method: string, body: string, token: string,
    generation: number): Promise<string> {
    this.assertCurrent(generation);
    const request: TransportRequest = new TransportRequest();
    request.url = this.baseUrl + path;
    request.method = method;
    request.body = body;
    request.token = token;
    const response: TransportResponse = await this.transport.send(request);
    this.assertCurrent(generation);
    if (response.status < 200 || response.status >= 300) {
      if (response.status === 401) {
        this.logout();
      }
      throw decodeApiFailure(response.body, response.status);
    }
    return response.body;
  }

  async login(account: string, password: string): Promise<Player> {
    this.logout();
    const generation: number = this.generation;
    const command: LoginCommand = new LoginCommand(account.trim().toLowerCase(), password);
    const auth: LoginResult = decodeLogin(await this.request('/api/collections/game_players/auth-with-password',
      'POST', JSON.stringify(command), '', generation));
    const player: Player = decodePlayer(await this.request('/api/questions/v1/me', 'GET', '', auth.token, generation));
    this.assertCurrent(generation);
    if (player.id !== auth.playerId) {
      throw new GameFailure('CONTRACT_ERROR', '登录身份与玩家资料不一致，请重新登录。');
    }
    this.token = auth.token;
    this.playerId = player.id;
    return player;
  }

  async me(): Promise<Player> {
    const generation: number = this.requireSession();
    const player: Player = decodePlayer(await this.request('/api/questions/v1/me', 'GET', '', this.token, generation));
    if (player.id !== this.playerId) {
      throw new GameFailure('CONTRACT_ERROR', '服务返回的玩家身份不一致。');
    }
    return player;
  }

  async changePassword(oldPassword: string, password: string, confirmation: string): Promise<Player> {
    const generation: number = this.requireSession();
    const validation: string = validatePasswordChange(oldPassword, password, confirmation);
    if (validation.length > 0) {
      throw new GameFailure('VALIDATION_ERROR', validation);
    }
    const command: PasswordCommand = new PasswordCommand(oldPassword, password, confirmation);
    // Never replay password changes automatically: a lost response may already have changed the password.
    const result: PasswordResult = decodePassword(await this.request('/api/questions/v1/me/change-password',
      'POST', JSON.stringify(command), this.token, generation));
    this.assertCurrent(generation);
    if (result.player.id !== this.playerId) {
      throw new GameFailure('CONTRACT_ERROR', '服务返回的玩家身份不一致。');
    }
    // A refreshed credential is a new identity epoch. Old-token 401 responses must not clear it.
    this.generation++;
    this.token = result.token;
    return result.player;
  }

  async assignments(): Promise<AssignmentSummary[]> {
    const generation: number = this.requireSession();
    const items: AssignmentSummary[] = decodeAssignments(await this.request('/api/questions/v1/assignments',
      'GET', '', this.token, generation));
    for (let i: number = 0; i < items.length; i++) {
      if (items[i].player !== this.playerId) {
        throw new GameFailure('CONTRACT_ERROR', '服务返回的场次身份不一致。');
      }
    }
    return items;
  }

  async assignment(id: string): Promise<AssignmentDetail> {
    const generation: number = this.requireSession();
    const detail: AssignmentDetail = decodeAssignment(await this.request('/api/questions/v1/assignments/' +
      encodeURIComponent(id), 'GET', '', this.token, generation));
    if (detail.id !== id || detail.player !== this.playerId) {
      throw new GameFailure('CONTRACT_ERROR', '服务返回的场次身份不一致。');
    }
    return detail;
  }

  logout(): void {
    this.generation++;
    this.token = '';
    this.playerId = '';
  }
}
