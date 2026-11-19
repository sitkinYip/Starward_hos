import { PushBindingApi, PushRegistrationReceipt } from '../business/PushRegistration';
import { HttpTransport, TransportRequest, TransportResponse } from '../platform/HttpTransport';

const PUSH_PATH: string = '/api/questions/v1';

class PushRegistrationCommand {
  readonly installationId: string;
  readonly token: string;
  readonly profileId: string;

  constructor(installationId: string, token: string, profileId: string) {
    this.installationId = installationId;
    this.token = token;
    this.profileId = profileId;
  }
}

class PushUnregisterCommand {
  readonly installationId: string;
  constructor(installationId: string) { this.installationId = installationId; }
}

class PushRevokeCommand {
  readonly installationId: string;
  readonly revokeTicket: string;
  constructor(installationId: string, revokeTicket: string) {
    this.installationId = installationId;
    this.revokeTicket = revokeTicket;
  }
}

/** Holds the initiating session, so late cleanup cannot run with a different player's token. */
export class PushBindingClient implements PushBindingApi {
  private readonly origin: string;
  private readonly transport: HttpTransport;
  private readonly authorization: string;

  constructor(origin: string, transport: HttpTransport, authorization: string) {
    this.origin = origin;
    this.transport = transport;
    this.authorization = authorization;
  }

  private async post(path: string, body: string, token: string): Promise<Record<string, Object>> {
    const request: TransportRequest = new TransportRequest();
    request.url = this.origin + PUSH_PATH + path;
    request.method = 'POST';
    request.token = token;
    request.body = body;
    const response: TransportResponse = await this.transport.send(request);
    if (response.status < 200 || response.status > 299) { throw new Error('Push endpoint unavailable'); }
    return JSON.parse(response.body) as Record<string, Object>;
  }

  async register(installationId: string, token: string, profileId: string): Promise<PushRegistrationReceipt> {
    const body = await this.post('/me/push/register',
      JSON.stringify(new PushRegistrationCommand(installationId, token, profileId)), this.authorization);
    const ticket: Object = body['revokeTicket'];
    if (body['registered'] === false && ticket === undefined) {
      return new PushRegistrationReceipt(false);
    }
    if (body['registered'] !== true || typeof ticket !== 'string' || !/^[A-Za-z0-9_-]{32,384}$/.test(ticket as string)) {
      throw new Error('Invalid Push registration receipt');
    }
    return new PushRegistrationReceipt(true, ticket as string);
  }

  async unregister(installationId: string): Promise<void> {
    if (this.authorization.length === 0) { throw new Error('Push session unavailable'); }
    const body = await this.post('/me/push/unregister',
      JSON.stringify(new PushUnregisterCommand(installationId)), this.authorization);
    if (body['registered'] !== false) { throw new Error('Invalid Push unlink receipt'); }
  }

  async revoke(installationId: string, ticket: string): Promise<void> {
    const body = await this.post('/push/revoke', JSON.stringify(new PushRevokeCommand(installationId, ticket)), '');
    if (body['registered'] !== false) { throw new Error('Invalid Push revoke receipt'); }
  }
}
