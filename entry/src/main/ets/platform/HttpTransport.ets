import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { GameFailure } from '../business/models';

export class TransportRequest {
  url: string = '';
  method: string = 'GET';
  token: string = '';
  body: string = '';
  multipart: TransportPart[] = [];
  binary: boolean = false;
}

export class TransportPart {
  name: string = '';
  contentType: string = '';
  filename: string = '';
  data: string | ArrayBuffer = '';
}

export class TransportResponse {
  status: number = 0;
  body: string = '';
  data: ArrayBuffer = new ArrayBuffer(0);
  contentType: string = '';
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
    const headers: Record<string, string> = {
      'Accept': request.binary ? 'image/jpeg,image/png,image/webp' : 'application/json'
    };
    if (request.token.length > 0) {
      headers['Authorization'] = request.token;
    }
    const form: http.MultiFormData[] = [];
    if (request.multipart.length > 0) {
      headers['Content-Type'] = 'multipart/form-data';
      request.multipart.forEach((part: TransportPart) => {
        form.push({ name: part.name, contentType: part.contentType,
          remoteFileName: part.filename.length > 0 ? part.filename : undefined, data: part.data });
      });
    } else if (request.body.length > 0) {
      headers['Content-Type'] = 'application/json';
    }
    try {
      const result: http.HttpResponse = await task.request(request.url, {
        method: request.method === 'PATCH' ? http.RequestMethod.PATCH :
          request.method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
        header: headers,
        body: form.length > 0 ? undefined : request.body,
        multiFormDataList: form.length > 0 ? form : undefined,
        expectDataType: request.binary ? http.HttpDataType.ARRAY_BUFFER : http.HttpDataType.STRING,
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
      const responseHeaders: Record<string, Object> = result.header as Record<string, Object>;
      Object.keys(responseHeaders).forEach((name: string) => {
        const value: Object = responseHeaders[name];
        if (name.toLowerCase() === 'content-type' && typeof value === 'string') {
          response.contentType = (value as string).split(';')[0].trim().toLowerCase();
        }
      });
      if (request.binary && result.result instanceof ArrayBuffer) {
        response.data = result.result;
      } else if (!request.binary && typeof result.result === 'string') {
        response.body = result.result as string;
      } else {
        throw new GameFailure('CONTRACT_ERROR', '服务返回了不兼容的数据，请稍后重试。');
      }
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
