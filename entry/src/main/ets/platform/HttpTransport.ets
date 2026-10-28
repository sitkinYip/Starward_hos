import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { GameFailure } from '../business/models';

export class TransportRequest {
  url: string = '';
  method: string = 'GET';
  token: string = '';
  body: string = '';
}

export class TransportResponse {
  status: number = 0;
  body: string = '';
}

export interface HttpTransport {
  send(request: TransportRequest): Promise<TransportResponse>;
}

export class NativeHttpTransport implements HttpTransport {
  private readonly caData: string;
  private readonly timeoutMs: number;
  private readonly reuseConnections: boolean;

  constructor(caData: string = '', timeoutMs: number = 15000, reuseConnections: boolean = true) {
    this.caData = caData;
    this.timeoutMs = timeoutMs;
    this.reuseConnections = reuseConnections;
  }

  async send(request: TransportRequest): Promise<TransportResponse> {
    const task: http.HttpRequest = http.createHttp();
    const headers: Record<string, string> = { 'Accept': 'application/json' };
    if (request.token.length > 0) {
      headers['Authorization'] = request.token;
    }
    if (request.body.length > 0) {
      headers['Content-Type'] = 'application/json';
    }
    try {
      const result: http.HttpResponse = await task.request(request.url, {
        method: request.method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
        header: headers,
        body: request.body,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        connectTimeout: this.timeoutMs,
        readTimeout: this.timeoutMs,
        caData: this.caData.length > 0 ? this.caData : undefined,
        maxLimit: 5 * 1024 * 1024,
        maxRedirects: 0,
        remoteValidation: 'system',
        enablePartialChain: false,
        reuseConnections: this.reuseConnections
      });
      const response: TransportResponse = new TransportResponse();
      response.status = result.responseCode;
      if (typeof result.result !== 'string') {
        throw new GameFailure('CONTRACT_ERROR', '服务返回了不兼容的数据，请稍后重试。');
      }
      response.body = result.result as string;
      return response;
    } catch (error) {
      if (error instanceof GameFailure) {
        throw error;
      }
      const nativeCode: number = (error as BusinessError).code;
      if (nativeCode === 2300058 || nativeCode === 2300060 || nativeCode === 2300077) {
        throw new GameFailure('TLS_ERROR', '安全连接验证失败，请检查测试环境证书。');
      }
      if (nativeCode === 2300028) {
        throw new GameFailure('TIMEOUT', '连接等待超时，请稍后重试');
      }
      throw new GameFailure('NETWORK_ERROR', '连接中断，请检查网络后重试。');
    } finally {
      task.destroy();
    }
  }
}
