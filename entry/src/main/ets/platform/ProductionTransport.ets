import { hilog } from '@kit.PerformanceAnalysisKit';
import { GameFailure } from '../business/models';
import { PRODUCTION_API_ORIGIN } from './AppEnvironment';
import { HttpTransport, TransportRequest, TransportResponse } from './HttpTransport';

const PLAYER_AUTH_PATH: string = '/api/collections/game_players/auth-with-password';
const FILE_TOKEN_PATH: string = '/api/files/token';
const PLAYER_PATH: string = '/api/questions/v1/me';
const ASSIGNMENTS_PATH: string = '/api/questions/v1/assignments';

export class ProductionTransport implements HttpTransport {
  private readonly transport: HttpTransport;
  private readonly readOnly: boolean;
  private readonly tag: string;

  constructor(transport: HttpTransport, readOnly: boolean) {
    this.transport = transport;
    this.readOnly = readOnly;
    this.tag = readOnly ? 'StarwardProdRead' : 'StarwardProdApi';
  }

  private operation(path: string, request: TransportRequest): string {
    if (request.method === 'POST') {
      if (path === PLAYER_AUTH_PATH) { return 'login'; }
      if (path === FILE_TOKEN_PATH) { return 'file-token'; }
      if (/^\/api\/questions\/v1\/assignments\/[^/?#]+\/start$/.test(path)) { return 'start'; }
      if (/^\/api\/questions\/v1\/assignments\/[^/?#]+\/answers$/.test(path)) { return 'answer'; }
      return 'write';
    }
    if (request.method === 'PUT' && path === '/api/questions/v1/me/push/journey-subscription') {
      return 'journey-push-subscription';
    }
    if (request.method === 'PATCH' || request.method === 'PUT') { return 'write'; }
    if (path === PLAYER_PATH) { return request.token.length === 0 ? 'preflight' : 'player'; }
    if (path === ASSIGNMENTS_PATH) { return 'assignments'; }
    if (path.startsWith(ASSIGNMENTS_PATH + '/')) { return 'assignment'; }
    if (request.binary && path.startsWith('/api/files/')) { return 'protected-file'; }
    return 'read';
  }

  async send(request: TransportRequest): Promise<TransportResponse> {
    if (!request.url.startsWith(PRODUCTION_API_ORIGIN + '/')) {
      throw new GameFailure('CONFIG_ERROR', '生产联调请求的域名无效。');
    }
    const path: string = request.url.substring(PRODUCTION_API_ORIGIN.length);
    const subscriptionPut: boolean = request.method === 'PUT' &&
      path === '/api/questions/v1/me/push/journey-subscription';
    if (request.method !== 'GET' && request.method !== 'POST' && request.method !== 'PATCH' && !subscriptionPut) {
      throw new GameFailure('CONFIG_ERROR', '生产联调请求的方法无效。');
    }
    // Login and short-lived protected-file access do not change game progress or player data.
    const allowedPost: boolean = request.method === 'POST' && (path === PLAYER_AUTH_PATH || path === FILE_TOKEN_PATH);
    if (this.readOnly && request.method !== 'GET' && !allowedPost) {
      throw new GameFailure('PRODUCTION_READ_ONLY', '生产联调包仅支持读取，未向服务端提交此操作。');
    }
    const operation: string = this.operation(path, request);
    try {
      const response: TransportResponse = await this.transport.send(request);
      if (operation !== 'read') {
        hilog.info(0x0000, this.tag, 'operation=%{public}s status=%{public}d', operation, response.status);
      }
      return response;
    } catch (error) {
      const failure: GameFailure = error instanceof GameFailure ? error :
        new GameFailure('UNKNOWN_ERROR', '生产联调请求失败，请稍后重试。');
      hilog.warn(0x0000, this.tag, 'operation=%{public}s failure=%{public}s', operation, failure.code);
      throw failure;
    }
  }
}
