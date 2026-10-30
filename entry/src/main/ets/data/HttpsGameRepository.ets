import { GameRepository } from '../business/GameRepository';
import { AssignmentDetail, AssignmentSummary, AvatarImage, AvatarUpload, avatarMimeType, GameFailure, Player,
  validateAvatarUpload, validateDisplayName, validatePasswordChange } from '../business/models';
import { HttpTransport, NativeHttpTransport, TransportPart, TransportRequest, TransportResponse } from '../platform/HttpTransport';
import { decodeApiFailure, decodeAssignment, decodeAssignments, decodeFileToken, decodeLogin, decodePassword, decodePlayer,
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

class ProfileCommand {
  displayName: string;

  constructor(displayName: string) {
    this.displayName = displayName;
  }
}

export class HttpsGameRepository implements GameRepository {
  readonly mode: string = 'https';
  private readonly baseUrl: string;
  private readonly transport: HttpTransport;
  private generation: number = 0;
  private token: string = '';
  private playerId: string = '';
  private avatarName: string = '';
  private avatarRevision: number = 0;
  private profileRevision: number = 0;
  private fileToken: string = '';
  private fileTokenExpires: number = 0;

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

  private clearFileToken(): void {
    this.fileToken = '';
    this.fileTokenExpires = 0;
  }

  private rememberAvatar(player: Player, invalidate: boolean = false): void {
    if (player.avatar !== this.avatarName || invalidate) {
      this.avatarName = player.avatar;
      this.avatarRevision++;
      this.clearFileToken();
    }
  }

  private assertAvatar(generation: number, revision: number): void {
    this.assertCurrent(generation);
    if (revision !== this.avatarRevision) {
      throw new GameFailure('CANCELLED', '头像已更新，本次请求已取消。');
    }
  }

  private async send(request: TransportRequest, generation: number): Promise<TransportResponse> {
    this.assertCurrent(generation);
    const response: TransportResponse = await this.transport.send(request);
    this.assertCurrent(generation);
    return response;
  }

  private rejectResponse(response: TransportResponse): void {
    if (response.status < 200 || response.status >= 300) {
      if (response.status === 401) {
        this.logout();
      }
      throw decodeApiFailure(response.body, response.status);
    }
  }

  private async request(path: string, method: string, body: string, token: string,
    generation: number): Promise<string> {
    const request: TransportRequest = new TransportRequest();
    request.url = this.baseUrl + path;
    request.method = method;
    request.body = body;
    request.token = token;
    const response: TransportResponse = await this.send(request, generation);
    this.rejectResponse(response);
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
    this.rememberAvatar(player);
    return player;
  }

  async me(): Promise<Player> {
    const generation: number = this.requireSession();
    const revision: number = this.profileRevision;
    const player: Player = decodePlayer(await this.request('/api/questions/v1/me', 'GET', '', this.token, generation));
    if (revision !== this.profileRevision) {
      throw new GameFailure('CANCELLED', '资料已更新，本次同步已取消。');
    }
    if (player.id !== this.playerId) {
      throw new GameFailure('CONTRACT_ERROR', '服务返回的玩家身份不一致。');
    }
    this.rememberAvatar(player);
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
    this.rememberAvatar(result.player, true);
    return result.player;
  }

  async updateProfile(displayName: string, avatar: AvatarUpload | null = null): Promise<Player> {
    const generation: number = this.requireSession();
    const validation: string = validateDisplayName(displayName);
    if (validation.length > 0) {
      throw new GameFailure('VALIDATION_ERROR', validation);
    }
    if (avatar !== null) {
      const avatarValidation: string = validateAvatarUpload(avatar);
      if (avatarValidation.length > 0) {
        throw new GameFailure('VALIDATION_ERROR', avatarValidation);
      }
    }
    const revision: number = ++this.profileRevision;
    const request: TransportRequest = new TransportRequest();
    request.url = this.baseUrl + '/api/questions/v1/me/profile';
    request.method = 'PATCH';
    request.token = this.token;
    if (avatar === null) {
      request.body = JSON.stringify(new ProfileCommand(displayName.trim()));
    } else {
      const name: TransportPart = new TransportPart();
      name.name = 'displayName';
      name.contentType = 'text/plain; charset=utf-8';
      name.data = displayName.trim();
      const photo: TransportPart = new TransportPart();
      photo.name = 'avatar';
      photo.contentType = avatar.mimeType;
      photo.filename = avatar.filename;
      photo.data = avatar.data;
      request.multipart = [name, photo];
    }
    // Profile writes, including uploaded bytes, are submitted once per explicit user action.
    const response: TransportResponse = await this.send(request, generation);
    if (revision !== this.profileRevision) {
      throw new GameFailure('CANCELLED', '资料已更新，本次请求已取消。');
    }
    this.rejectResponse(response);
    const player: Player = decodePlayer(response.body);
    if (player.id !== this.playerId) {
      throw new GameFailure('CONTRACT_ERROR', '服务返回的玩家身份不一致。');
    }
    this.rememberAvatar(player, avatar !== null);
    return player;
  }

  private async avatarToken(generation: number, revision: number, forceRefresh: boolean): Promise<string> {
    this.assertAvatar(generation, revision);
    if (forceRefresh) {
      this.clearFileToken();
    }
    if (this.fileToken.length > 0 && this.fileTokenExpires > Date.now()) {
      return this.fileToken;
    }
    const token: string = decodeFileToken(await this.request('/api/files/token', 'POST', '{}',
      this.token, generation));
    this.assertAvatar(generation, revision);
    this.fileToken = token;
    this.fileTokenExpires = Date.now() + 60000;
    return token;
  }

  private async avatarResponse(token: string, generation: number, revision: number): Promise<TransportResponse> {
    this.assertAvatar(generation, revision);
    const request: TransportRequest = new TransportRequest();
    request.url = this.baseUrl + '/api/files/game_players/' + encodeURIComponent(this.playerId) + '/' +
      encodeURIComponent(this.avatarName) + '?token=' + encodeURIComponent(token);
    request.binary = true;
    // The protected file is authorized by its short-lived file token, never a public UI URL.
    const response: TransportResponse = await this.send(request, generation);
    this.assertAvatar(generation, revision);
    return response;
  }

  async avatar(forceRefresh: boolean = false): Promise<AvatarImage | null> {
    const generation: number = this.requireSession();
    const revision: number = this.avatarRevision;
    if (this.avatarName.length === 0) {
      return null;
    }
    let token: string = await this.avatarToken(generation, revision, forceRefresh);
    let response: TransportResponse = await this.avatarResponse(token, generation, revision);
    // A stale file token can look like a missing/forbidden protected file. Refresh only once.
    if (response.status === 401 || response.status === 403 || response.status === 404) {
      token = await this.avatarToken(generation, revision, true);
      response = await this.avatarResponse(token, generation, revision);
    }
    if (response.status < 200 || response.status >= 300) {
      throw new GameFailure('AVATAR_FETCH_FAILED', '头像加载失败，请重试。', response.status);
    }
    const mimeType: string = avatarMimeType(response.data);
    if (response.data.byteLength > 2 * 1024 * 1024 || mimeType.length === 0 ||
      response.contentType !== mimeType) {
      throw new GameFailure('CONTRACT_ERROR', '服务返回了不兼容的头像，请重试。');
    }
    const result: AvatarImage = new AvatarImage();
    result.data = response.data;
    result.mimeType = mimeType;
    return result;
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
    this.avatarName = '';
    this.avatarRevision++;
    this.profileRevision++;
    this.clearFileToken();
  }
}
