import { describe, expect, it } from '@ohos/hypium';
import { GameFailure, Player } from '../main/ets/business/models';
import { HttpsGameRepository } from '../main/ets/data/HttpsGameRepository';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { HttpTransport, TransportRequest, TransportResponse } from '../main/ets/platform/HttpTransport';
import { ASSIGNMENT_JSON, PLAYER_JSON } from './Contract.test';

class StubTransport implements HttpTransport {
  requests: TransportRequest[] = [];
  replies: TransportResponse[] = [];
  failure: GameFailure | null = null;
  private pending: Promise<TransportResponse> | null = null;
  private resolvePending: (response: TransportResponse) => void = (_response: TransportResponse) => {};

  reply(status: number, body: string): void {
    const response: TransportResponse = new TransportResponse();
    response.status = status;
    response.body = body;
    this.replies.push(response);
  }

  deferNext(): void {
    this.pending = new Promise<TransportResponse>((resolve: (response: TransportResponse) => void) => {
      this.resolvePending = resolve;
    });
  }

  complete(status: number, body: string): void {
    const response: TransportResponse = new TransportResponse();
    response.status = status;
    response.body = body;
    this.resolvePending(response);
  }

  async send(request: TransportRequest): Promise<TransportResponse> {
    this.requests.push(request);
    if (this.failure !== null) {
      throw this.failure;
    }
    if (this.pending !== null) {
      const pending: Promise<TransportResponse> = this.pending;
      this.pending = null;
      return pending;
    }
    const response: TransportResponse | undefined = this.replies.shift();
    if (response === undefined) {
      throw new GameFailure('TEST_FIXTURE_MISSING', 'Missing test reply');
    }
    return response;
  }
}

async function rejectedCode<T>(task: Promise<T>): Promise<string> {
  try {
    await task;
    return 'RESOLVED';
  } catch (error) {
    return (error as GameFailure).code;
  }
}

function queueLogin(transport: StubTransport, token: string = 'test-token'): void {
  transport.reply(200, '{"token":"' + token + '","record":{"id":"playeralice"}}');
  transport.reply(200, PLAYER_JSON);
}

export default function repositoryTests(): void {
  describe('Repository', () => {
    it('normalizesIdentityAndCommitsOnlyValidatedPlayer', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueLogin(transport);
      const player: Player = await repository.login(' Alice ', 'Starward1234');
      expect(player.id).assertEqual('playeralice');
      expect(transport.requests[0].url).assertEqual('https://isolated.example/api/collections/game_players/auth-with-password');
      expect(transport.requests[0].body).assertContain('"identity":"alice"');
      expect(transport.requests[0].token).assertEqual('');
      expect(transport.requests[1].token).assertEqual('test-token');
      transport.reply(200, PLAYER_JSON);
      await repository.me();
      expect(transport.requests[2].token).assertEqual('test-token');
    });

    it('rejectsMismatchedPlayerBeforeHoldingCredentials', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      transport.reply(200, '{"token":"test-token","record":{"id":"different-player"}}');
      transport.reply(200, PLAYER_JSON);
      expect(await rejectedCode(repository.login('alice', 'Starward1234'))).assertEqual('CONTRACT_ERROR');
      expect(await rejectedCode(repository.me())).assertEqual('UNAUTHORIZED');
      expect(transport.requests.length).assertEqual(2);
    });

    it('neverAutomaticallyReplaysPasswordChange', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueLogin(transport);
      await repository.login('alice', 'Starward1234');
      transport.failure = new GameFailure('NETWORK_ERROR', 'connection dropped');
      expect(await rejectedCode(repository.changePassword('Starward1234', 'NewStarward1234', 'NewStarward1234'))).assertEqual('NETWORK_ERROR');
      expect(transport.requests.length).assertEqual(3);
      expect(transport.requests[2].url).assertEqual('https://isolated.example/api/questions/v1/me/change-password');
      expect(transport.requests[2].method).assertEqual('POST');
      expect(transport.requests[2].body).assertContain('"passwordConfirm":"NewStarward1234"');
    });

    it('rotatesTokenOnlyAfterSuccessfulPasswordResponse', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueLogin(transport);
      await repository.login('alice', 'Starward1234');
      transport.reply(200, '{"token":"rotated-token","player":' + PLAYER_JSON.replace('"mustChangePassword":true', '"mustChangePassword":false') + '}');
      const player: Player = await repository.changePassword('Starward1234', 'NewStarward1234', 'NewStarward1234');
      expect(player.mustChangePassword).assertFalse();
      transport.reply(200, PLAYER_JSON);
      await repository.me();
      expect(transport.requests[3].token).assertEqual('rotated-token');
    });

    it('logoutInvalidatesPendingLoginResponse', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      transport.deferNext();
      const login: Promise<Player> = repository.login('alice', 'Starward1234');
      repository.logout();
      transport.complete(200, '{"token":"test-token","record":{"id":"playeralice"}}');
      expect(await rejectedCode(login)).assertEqual('CANCELLED');
      expect(await rejectedCode(repository.me())).assertEqual('UNAUTHORIZED');
      expect(transport.requests.length).assertEqual(1);
    });

    it('oldUnauthorizedResponseCannotClearNewerSession', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueLogin(transport, 'first-token');
      await repository.login('alice', 'Starward1234');
      transport.deferNext();
      const stale: Promise<Player> = repository.me();
      queueLogin(transport, 'new-token');
      await repository.login('alice', 'Starward1234');
      transport.complete(401, '{}');
      expect(await rejectedCode(stale)).assertEqual('CANCELLED');
      transport.reply(200, PLAYER_JSON);
      expect((await repository.me()).id).assertEqual('playeralice');
      expect(transport.requests[5].token).assertEqual('new-token');
    });

    it('currentUnauthorizedResponseClearsSession', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueLogin(transport);
      await repository.login('alice', 'Starward1234');
      transport.reply(401, '{}');
      expect(await rejectedCode(repository.me())).assertEqual('UNAUTHORIZED');
      expect(await rejectedCode(repository.me())).assertEqual('UNAUTHORIZED');
      expect(transport.requests.length).assertEqual(3);
    });

    it('oldUnauthorizedResponseCannotClearRotatedPasswordToken', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueLogin(transport);
      await repository.login('alice', 'Starward1234');
      transport.deferNext();
      const stale: Promise<Player> = repository.me();
      transport.reply(200, '{"token":"rotated-token","player":' + PLAYER_JSON.replace('"mustChangePassword":true', '"mustChangePassword":false') + '}');
      await repository.changePassword('Starward1234', 'NewStarward1234', 'NewStarward1234');
      transport.complete(401, '{}');
      expect(await rejectedCode(stale)).assertEqual('CANCELLED');
      transport.reply(200, PLAYER_JSON.replace('"mustChangePassword":true', '"mustChangePassword":false'));
      expect((await repository.me()).mustChangePassword).assertFalse();
      expect(transport.requests[4].token).assertEqual('rotated-token');
    });

    it('refusesCrossAccountAssignments', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueLogin(transport);
      await repository.login('alice', 'Starward1234');
      transport.reply(200, '{"items":[' + ASSIGNMENT_JSON.replace('"player":"playeralice"', '"player":"other-player"') + ']}');
      expect(await rejectedCode(repository.assignments())).assertEqual('CONTRACT_ERROR');
      transport.reply(200, ASSIGNMENT_JSON.replace('"id":"assignment1"', '"id":"assignment2"'));
      expect(await rejectedCode(repository.assignment('assignment1'))).assertEqual('CONTRACT_ERROR');
    });

    it('mockRequiresFirstPasswordChangeAndUsesChangedPassword', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      expect((await repository.login(' Alice ', 'Starward1234')).mustChangePassword).assertTrue();
      expect(await rejectedCode(repository.assignments())).assertEqual('PASSWORD_CHANGE_REQUIRED');
      expect((await repository.changePassword('Starward1234', 'NewStarward1234', 'NewStarward1234')).mustChangePassword).assertFalse();
      expect((await repository.assignments()).length).assertEqual(1);
      repository.logout();
      expect(await rejectedCode(repository.login('alice', 'Starward1234'))).assertEqual('INVALID_CREDENTIALS');
      expect((await repository.login('alice', 'NewStarward1234')).mustChangePassword).assertFalse();
    });
  });
}
