import { GameRepository } from '../business/GameRepository';
import { CredentialStore, isRestoredSessionInvalid, SavedSession } from '../business/CredentialStore';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GameplayAnswerResult, GameplayLevel, GameplaySnapshot } from '../business/GameplayModels';
import { NarrativeContent } from '../business/NarrativeModels';
import { decodeGameplay, decodeGameplayAnswer } from './GameplayDecoder';
import { decodeNarrative } from './NarrativeDecoder';
import { AssignmentDetail, AssignmentSummary, AvatarImage, AvatarUpload, avatarMimeType, GameFailure, Player,
  validateAvatarUpload, validateDisplayName, validatePasswordChange } from '../business/models';
import { HttpTransport, NativeHttpTransport, TransportPart, TransportRequest, TransportResponse } from '../platform/HttpTransport';
import { ReadCancellation } from '../business/ReadCancellation';
import { GameNotification } from '../business/GameNotification';
import { GameReward } from '../business/GameReward';
import { decodeApiFailure, decodeAssignment, decodeAssignments, decodeFileToken, decodeLogin, decodePassword, decodePlayer,
  decodeNotificationReceipt, decodeNotifications, decodeRewards, LoginResult, PasswordResult } from './DtoDecoder';

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

class StartCommand {
  requestId: string;

  constructor(requestId: string) {
    this.requestId = requestId;
  }
}

class AnswerCommand {
  sessionLevelId: string;
  answer: string;
  requestId: string;

  constructor(sessionLevelId: string, rawAnswer: string, requestId: string) {
    this.sessionLevelId = sessionLevelId;
    this.answer = rawAnswer;
    this.requestId = requestId;
  }
}

export class HttpsGameRepository implements GameRepository {
  readonly mode: string = 'https';
  private readonly baseUrl: string;
  private readonly transport: HttpTransport;
  private readonly probeBoundary: boolean;
  private readonly credentials: CredentialStore | null;
  private credentialOperation: Promise<void> = Promise.resolve();
  private generation: number = 0;
  private passwordChangeGeneration: number = -1;
  private token: string = '';
  private playerId: string = '';
  private avatarName: string = '';
  private avatarRevision: number = 0;
  private profileRevision: number = 0;
  private fileToken: string = '';
  private fileTokenExpires: number = 0;

  constructor(baseUrl: string, transport: HttpTransport = new NativeHttpTransport(), probeBoundary: boolean = false,
    credentials: CredentialStore | null = null) {
    const normalized: string = baseUrl.replace(/\/+$/, '');
    if (!/^https:\/\/[^\s/?#@]+(?::\d+)?$/.test(normalized)) {
      throw new GameFailure('CONFIG_ERROR', '请配置隔离环境的 HTTPS 服务地址。');
    }
    this.baseUrl = normalized;
    this.transport = transport;
    this.probeBoundary = probeBoundary;
    this.credentials = credentials;
  }

  private assertCurrent(generation: number): void {
    if (generation !== this.generation) {
      throw new GameFailure('CANCELLED', '账号已切换，本次请求已取消。');
    }
  }

  private requireSession(): number {
    if (this.passwordChangeGeneration !== -1) {
      throw new GameFailure('CANCELLED', '正在修改密码，请稍后再试。');
    }
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
    if (this.probeBoundary && request.method === 'POST' && request.url.endsWith('/start')) {
      // Isolated-build evidence only: no URL, record ID, answer, body or credential is logged.
      hilog.info(0x0000, 'StarwardGameBoundary', 'operation=start received=%{public}d sessionCurrent=%{public}s',
        response.status, (generation === this.generation).toString());
    } else if (this.probeBoundary && request.method === 'POST' && request.url.endsWith('/answers')) {
      hilog.info(0x0000, 'StarwardGameBoundary', 'operation=answer received=%{public}d sessionCurrent=%{public}s',
        response.status, (generation === this.generation).toString());
    }
    this.assertCurrent(generation);
    return response;
  }

  private rejectResponse(response: TransportResponse, clearUnauthorized: boolean = true): void {
    if (response.status === 401 && clearUnauthorized) {
      // Invalidate memory immediately. The caller handles the 401 without waiting for the asset service.
      void this.logout().catch(() => {
        // The sign-out flow waits for durable deletion and offers a retry if it fails.
      });
    }
    throw decodeApiFailure(response.body, response.status);
  }

  private async request(path: string, method: string, body: string, token: string,
    generation: number, cancellation?: ReadCancellation, clearUnauthorized: boolean = true): Promise<string> {
    const request: TransportRequest = new TransportRequest();
    request.url = this.baseUrl + path;
    request.method = method;
    request.body = body;
    request.token = token;
    request.cancellation = cancellation;
    const response: TransportResponse = await this.send(request, generation);
    this.assertCurrent(generation);
    if (cancellation?.cancelled) { throw new GameFailure('CANCELLED', '场次读取已取消。'); }
    if (response.status < 200 || response.status >= 300) {
      this.rejectResponse(response, clearUnauthorized);
    }
    return response.body;
  }

  private accessCredential<T>(action: () => Promise<T>): Promise<T> {
    const pending: Promise<T> = this.credentialOperation.then(action);
    // Clear must run after any in-flight operation, including a read discarding a damaged record.
    this.credentialOperation = pending.then(() => {}, () => {});
    return pending;
  }

  private async clearCredential(): Promise<void> {
    const store: CredentialStore | null = this.credentials;
    if (store === null) { return; }
    try {
      await this.accessCredential(() => store.clear());
    } catch (error) {
      const locked: boolean = error instanceof GameFailure && error.code === 'SESSION_STORAGE_LOCKED';
      throw new GameFailure('CREDENTIAL_CLEAR_ERROR', locked ? '未能清除本机登录记录，请解锁设备后重试。' :
        '未能清除本机登录记录，请重试。');
    }
  }

  private async saveCredential(session: SavedSession, generation: number): Promise<void> {
    const store: CredentialStore | null = this.credentials;
    if (store === null) { return; }
    try {
      await this.accessCredential(() => {
        this.assertCurrent(generation);
        return store.save(session);
      });
    } catch (_) {
      this.assertCurrent(generation);
      // A storage error can be returned after the write took effect.
      await this.clearCredential();
      this.assertCurrent(generation);
      throw new GameFailure('CREDENTIAL_SAVE_ERROR', '无法保存本机登录状态，请重试。');
    }
    this.assertCurrent(generation);
  }

  private acceptSession(session: SavedSession, player: Player): void {
    this.token = session.token;
    this.playerId = session.playerId;
    this.rememberAvatar(player);
  }

  async restoreSession(cancellation?: ReadCancellation): Promise<Player | null> {
    const store: CredentialStore | null = this.credentials;
    if (store === null) { return null; }
    this.resetSession();
    const generation: number = this.generation;
    let saved: SavedSession | null;
    try {
      saved = await this.accessCredential(() => {
        this.assertCurrent(generation);
        return store.read();
      });
    } catch (error) {
      this.assertCurrent(generation);
      const locked: boolean = error instanceof GameFailure && error.code === 'SESSION_STORAGE_LOCKED';
      throw new GameFailure('CREDENTIAL_READ_ERROR', locked ? '请解锁设备后重试恢复登录。' :
        '未能读取本机登录状态，请重试。');
    }
    this.assertCurrent(generation);
    if (saved === null) { return null; }

    let player: Player;
    try {
      if (saved.token.length === 0 || saved.playerId.length === 0) {
        throw new GameFailure('SAVED_SESSION_MISMATCH', '本机登录记录无效，请重新登录。', 401);
      }
      const response: string = await this.request('/api/questions/v1/me', 'GET', '', saved.token,
        generation, cancellation, false);
      this.assertCurrent(generation);
      player = decodePlayer(response);
      if (player.id !== saved.playerId) {
        throw new GameFailure('SAVED_SESSION_MISMATCH', '本机登录记录无效，请重新登录。', 401);
      }
    } catch (error) {
      this.assertCurrent(generation);
      if (isRestoredSessionInvalid(error as Object)) {
        await this.logout();
      }
      throw error as Error;
    }
    this.acceptSession(saved, player);
    return player;
  }

  async login(account: string, password: string): Promise<Player> {
    this.resetSession();
    const generation: number = this.generation;
    if (this.credentials !== null) {
      await this.clearCredential();
      this.assertCurrent(generation);
    }
    const command: LoginCommand = new LoginCommand(account.trim().toLowerCase(), password);
    const auth: LoginResult = decodeLogin(await this.request('/api/collections/game_players/auth-with-password',
      'POST', JSON.stringify(command), '', generation));
    const player: Player = decodePlayer(await this.request('/api/questions/v1/me', 'GET', '', auth.token, generation));
    this.assertCurrent(generation);
    if (player.id !== auth.playerId) {
      throw new GameFailure('CONTRACT_ERROR', '登录身份与玩家资料不一致，请重新登录。');
    }
    const session: SavedSession = new SavedSession(auth.token, player.id);
    if (this.credentials !== null) { await this.saveCredential(session, generation); }
    this.assertCurrent(generation);
    this.acceptSession(session, player);
    return player;
  }

  async me(cancellation?: ReadCancellation): Promise<Player> {
    const generation: number = this.requireSession();
    const revision: number = this.profileRevision;
    const player: Player = decodePlayer(await this.request('/api/questions/v1/me', 'GET', '', this.token, generation,
      cancellation));
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
    this.requireSession();
    const validation: string = validatePasswordChange(oldPassword, password, confirmation);
    if (validation.length > 0) {
      throw new GameFailure('VALIDATION_ERROR', validation);
    }
    const command: PasswordCommand = new PasswordCommand(oldPassword, password, confirmation);
    const owner: string = this.playerId;
    // Reserve the epoch before the POST. The server can invalidate the old token well before the reply arrives.
    const generation: number = ++this.generation;
    this.passwordChangeGeneration = generation;
    // Never replay password changes automatically: a lost response may already have changed the password.
    try {
      const result: PasswordResult = decodePassword(await this.request('/api/questions/v1/me/change-password',
        'POST', JSON.stringify(command), this.token, generation));
      this.assertCurrent(generation);
      if (result.player.id !== owner) {
        throw new GameFailure('CONTRACT_ERROR', '服务返回的玩家身份不一致。');
      }
      if (this.credentials !== null) {
        try {
          await this.saveCredential(new SavedSession(result.token, result.player.id), generation);
        } catch (error) {
          this.assertCurrent(generation);
          this.resetSession();
          if (error instanceof GameFailure && error.code === 'CREDENTIAL_CLEAR_ERROR') {
            throw new GameFailure('CREDENTIAL_CLEAR_ERROR', '密码已修改。请重试清除登录记录，再用新密码登录。');
          }
          throw new GameFailure('PASSWORD_CHANGED_SESSION_NOT_SAVED',
            '密码已修改，但未能保存登录状态。请使用新密码重新登录。');
        }
      }
      this.assertCurrent(generation);
      this.token = result.token;
      this.rememberAvatar(result.player, true);
      return result.player;
    } finally {
      if (this.passwordChangeGeneration === generation && this.generation === generation && this.playerId === owner) {
        this.passwordChangeGeneration = -1;
      }
    }
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
    if (response.status < 200 || response.status >= 300) { this.rejectResponse(response); }
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

  async assignments(cancellation?: ReadCancellation): Promise<AssignmentSummary[]> {
    const generation: number = this.requireSession();
    const items: AssignmentSummary[] = decodeAssignments(await this.request('/api/questions/v1/assignments',
      'GET', '', this.token, generation, cancellation));
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

  private acceptGameplay(body: string, id: string, generation: number): GameplaySnapshot {
    const snapshot: GameplaySnapshot = decodeGameplay(body);
    this.assertCurrent(generation);
    if (snapshot.detail.id !== id || snapshot.detail.player !== this.playerId) {
      throw new GameFailure('CONTRACT_ERROR', '服务返回的场次身份不一致。');
    }
    return snapshot;
  }

  async startAssignment(id: string, requestId: string): Promise<GameplaySnapshot> {
    const generation: number = this.requireSession();
    if (id.length === 0 || requestId.trim().length === 0 || requestId.length > 100) {
      throw new GameFailure('VALIDATION_ERROR', '无法确认本次入场请求，请返回后重试。');
    }
    const command: StartCommand = new StartCommand(requestId);
    // The caller owns one account-bound command identity, including explicit retries.
    // A network error does not generate another ID or automatically replay this write.
    const body: string = await this.request('/api/questions/v1/assignments/' + encodeURIComponent(id) +
      '/start', 'POST', JSON.stringify(command), this.token, generation);
    const snapshot: GameplaySnapshot = this.acceptGameplay(body, id, generation);
    if (snapshot.detail.startedAt.length === 0 ||
      (snapshot.detail.status !== 'active' && snapshot.detail.status !== 'completed' &&
        snapshot.detail.status !== 'cancelled')) {
      throw new GameFailure('CONTRACT_ERROR', '服务尚未确认本次入场，请重试确认结果。');
    }
    return snapshot;
  }

  async gameplay(id: string, cancellation?: ReadCancellation): Promise<GameplaySnapshot> {
    const generation: number = this.requireSession();
    if (id.length === 0) {
      throw new GameFailure('VALIDATION_ERROR', '缺少场次，请返回后重试。');
    }
    const body: string = await this.request('/api/questions/v1/assignments/' + encodeURIComponent(id),
      'GET', '', this.token, generation, cancellation);
    return this.acceptGameplay(body, id, generation);
  }

  async narrative(assignmentId: string, contentId: string, cancellation?: ReadCancellation): Promise<NarrativeContent> {
    const generation: number = this.requireSession();
    const routeId: RegExp = /^[A-Za-z0-9_-]{1,100}$/;
    if (!routeId.test(assignmentId) || !routeId.test(contentId)) {
      throw new GameFailure('VALIDATION_ERROR', '缺少有效的场次或剧情，请返回后重试。');
    }
    const body: string = await this.request('/api/questions/v1/assignments/' + encodeURIComponent(assignmentId) +
      '/narratives/' + encodeURIComponent(contentId), 'GET', '', this.token, generation, cancellation);
    this.assertCurrent(generation);
    if (cancellation?.cancelled) { throw new GameFailure('CANCELLED', '剧情读取已取消。'); }
    const content: NarrativeContent = decodeNarrative(body);
    if (content.id !== contentId) {
      throw new GameFailure('CONTRACT_ERROR', '服务返回的剧情身份不一致。');
    }
    return content;
  }

  async notifications(cancellation?: ReadCancellation): Promise<GameNotification[]> {
    const generation: number = this.requireSession();
    return decodeNotifications(await this.request('/api/questions/v1/notifications', 'GET', '', this.token,
      generation, cancellation));
  }

  async rewards(cancellation?: ReadCancellation): Promise<GameReward[]> {
    const generation: number = this.requireSession();
    const playerId: string = this.playerId;
    const body: string = await this.request('/api/questions/v1/rewards', 'GET', '', this.token, generation, cancellation);
    return decodeRewards(body, playerId);
  }

  async readNotification(id: string): Promise<string> {
    const generation: number = this.requireSession();
    return decodeNotificationReceipt(await this.request(`/api/questions/v1/notifications/${encodeURIComponent(id)}/read`,
      'POST', '{}', this.token, generation));
  }

  async answerAssignment(id: string, sessionLevelId: string, rawAnswer: string,
    requestId: string): Promise<GameplayAnswerResult> {
    const generation: number = this.requireSession();
    if (id.length === 0 || sessionLevelId.trim().length === 0 || sessionLevelId.trim().length > 30 ||
      requestId.trim().length === 0 || requestId.trim().length > 100 ||
      rawAnswer.trim().length === 0 || rawAnswer.trim().length > 4000) {
      throw new GameFailure('VALIDATION_ERROR', '请填写有效答案后再提交。');
    }
    const command: AnswerCommand = new AnswerCommand(sessionLevelId, rawAnswer, requestId);
    const body: string = await this.request('/api/questions/v1/assignments/' + encodeURIComponent(id) +
      '/answers', 'POST', JSON.stringify(command), this.token, generation);
    const result: GameplayAnswerResult = decodeGameplayAnswer(body);
    this.assertCurrent(generation);
    if (result.assignment.detail.id !== id || result.assignment.detail.player !== this.playerId ||
      result.player.id !== this.playerId ||
      !result.assignment.levels.some((level: GameplayLevel) => level.id === sessionLevelId.trim())) {
      throw new GameFailure('CONTRACT_ERROR', '服务返回的答题身份或关卡不一致。');
    }
    // The answer's complete player snapshot supersedes older profile/XP reads.
    this.profileRevision++;
    this.rememberAvatar(result.player);
    return result;
  }

  private resetSession(): void {
    this.generation++;
    this.passwordChangeGeneration = -1;
    this.token = '';
    this.playerId = '';
    this.avatarName = '';
    this.avatarRevision++;
    this.profileRevision++;
    this.clearFileToken();
  }

  suspendSession(): void {
    this.resetSession();
  }

  async logout(): Promise<void> {
    this.suspendSession();
    await this.clearCredential();
  }
}
