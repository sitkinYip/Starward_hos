import { describe, expect, it } from '@ohos/hypium';
import { AvatarImage, AvatarUpload, GameFailure, Player } from '../main/ets/business/models';
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

  replyImage(status: number, data: ArrayBuffer, contentType: string = 'image/png'): void {
    const response: TransportResponse = new TransportResponse();
    response.status = status;
    response.data = data;
    response.contentType = contentType;
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

  completeImage(status: number, data: ArrayBuffer, contentType: string = 'image/png'): void {
    const response: TransportResponse = new TransportResponse();
    response.status = status;
    response.data = data;
    response.contentType = contentType;
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

async function nextTurn(): Promise<void> {
  await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 0); });
}

function queueLogin(transport: StubTransport, token: string = 'test-token'): void {
  transport.reply(200, '{"token":"' + token + '","record":{"id":"playeralice"}}');
  transport.reply(200, PLAYER_JSON);
}

const AVATAR_PLAYER_JSON: string = PLAYER_JSON.replace('"avatar":""', '"avatar":"portrait.png"');

function pngBytes(): ArrayBuffer {
  return new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10, 0]).buffer as ArrayBuffer;
}

function uploadPng(): AvatarUpload {
  const value: AvatarUpload = new AvatarUpload();
  value.filename = 'portrait.png';
  value.mimeType = 'image/png';
  value.data = pngBytes();
  return value;
}

function queueAvatarLogin(transport: StubTransport): void {
  transport.reply(200, '{"token":"test-token","record":{"id":"playeralice"}}');
  transport.reply(200, AVATAR_PLAYER_JSON);
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

    it('profileWritesValidatedTrimmedNameAsAuthenticatedJsonPatch', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueLogin(transport);
      await repository.login('alice', 'Starward1234');
      expect(await rejectedCode(repository.updateProfile('   '))).assertEqual('VALIDATION_ERROR');
      expect(await rejectedCode(repository.updateProfile('星'.repeat(41)))).assertEqual('VALIDATION_ERROR');
      expect(transport.requests.length).assertEqual(2);
      transport.reply(200, PLAYER_JSON.replace('"displayName":"Alice"', '"displayName":"新的旅人"'));
      expect((await repository.updateProfile(' 新的旅人 ')).displayName).assertEqual('新的旅人');
      const request: TransportRequest = transport.requests[2];
      expect(request.method).assertEqual('PATCH');
      expect(request.url).assertEqual('https://isolated.example/api/questions/v1/me/profile');
      expect(request.body).assertEqual('{"displayName":"新的旅人"}');
      expect(request.token).assertEqual('test-token');
      expect(request.multipart.length).assertEqual(0);
    });

    it('profileAvatarUsesSeparateMultipartFieldsAndRejectsWrongIdentity', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueLogin(transport);
      await repository.login('alice', 'Starward1234');
      const upload: AvatarUpload = uploadPng();
      transport.reply(200, AVATAR_PLAYER_JSON);
      expect((await repository.updateProfile(' Alice ', upload)).avatar).assertEqual('portrait.png');
      const request: TransportRequest = transport.requests[2];
      expect(request.body).assertEqual('');
      expect(request.multipart.length).assertEqual(2);
      expect(request.multipart[0].name).assertEqual('displayName');
      expect(request.multipart[0].data).assertEqual('Alice');
      expect(request.multipart[1].name).assertEqual('avatar');
      expect(request.multipart[1].filename).assertEqual('portrait.png');
      expect((request.multipart[1].data as ArrayBuffer).byteLength).assertEqual(upload.data.byteLength);
      transport.reply(200, PLAYER_JSON.replace('"id":"playeralice"', '"id":"other-player"'));
      expect(await rejectedCode(repository.updateProfile('Another name'))).assertEqual('CONTRACT_ERROR');
    });

    it('profileWriteFailureDoesNotReplayOrCommitAfterLogout', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueLogin(transport);
      await repository.login('alice', 'Starward1234');
      transport.reply(503, '{"error":{"code":"UPSTREAM_UNAVAILABLE","message":"暂时不可用"}}');
      expect(await rejectedCode(repository.updateProfile('New name'))).assertEqual('UPSTREAM_UNAVAILABLE');
      expect(transport.requests.length).assertEqual(3);
      transport.deferNext();
      const pending: Promise<Player> = repository.updateProfile('Late name');
      repository.logout();
      transport.complete(200, AVATAR_PLAYER_JSON);
      expect(await rejectedCode(pending)).assertEqual('CANCELLED');
      expect(await rejectedCode(repository.avatar())).assertEqual('UNAUTHORIZED');
    });

    it('avatarFetchUsesProtectedBytesAndReusesOnlyCurrentFileToken', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueLogin(transport);
      await repository.login('alice', 'Starward1234');
      expect(await repository.avatar()).assertNull();
      expect(transport.requests.length).assertEqual(2);
      transport.reply(200, AVATAR_PLAYER_JSON);
      await repository.me();
      transport.reply(200, '{"token":"file-token"}');
      transport.replyImage(200, pngBytes());
      const image: AvatarImage | null = await repository.avatar();
      expect(image?.mimeType).assertEqual('image/png');
      expect(image?.data.byteLength).assertEqual(9);
      expect(transport.requests[3].url).assertEqual('https://isolated.example/api/files/token');
      expect(transport.requests[3].token).assertEqual('test-token');
      expect(transport.requests[4].binary).assertTrue();
      expect(transport.requests[4].token).assertEqual('');
      expect(transport.requests[4].url).assertContain('/portrait.png?token=file-token');
      transport.replyImage(200, pngBytes());
      await repository.avatar();
      expect(transport.requests.length).assertEqual(6);
    });

    it('expiredFileTokenRefreshesOnceWithoutLoggingOutMainSession', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueAvatarLogin(transport);
      await repository.login('alice', 'Starward1234');
      transport.reply(200, '{"token":"expired-file-token"}');
      transport.replyImage(404, new ArrayBuffer(0));
      transport.reply(200, '{"token":"fresh-file-token"}');
      transport.replyImage(200, pngBytes());
      expect((await repository.avatar())?.mimeType).assertEqual('image/png');
      expect(transport.requests.length).assertEqual(6);
      expect(transport.requests[5].url).assertContain('token=fresh-file-token');
      transport.replyImage(403, new ArrayBuffer(0));
      transport.reply(200, '{"token":"still-invalid-file-token"}');
      transport.replyImage(403, new ArrayBuffer(0));
      expect(await rejectedCode(repository.avatar())).assertEqual('AVATAR_FETCH_FAILED');
      expect(transport.requests.length).assertEqual(9);
      transport.reply(200, AVATAR_PLAYER_JSON);
      expect((await repository.me()).id).assertEqual('playeralice');
    });

    it('avatarNeverAcceptsMalformedTokenOrHtmlAsAnEmptySuccess', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueAvatarLogin(transport);
      await repository.login('alice', 'Starward1234');
      transport.reply(200, '{"token":""}');
      expect(await rejectedCode(repository.avatar())).assertEqual('CONTRACT_ERROR');
      transport.reply(200, '{"token":"file-token"}');
      transport.replyImage(200, pngBytes(), 'text/html');
      expect(await rejectedCode(repository.avatar())).assertEqual('CONTRACT_ERROR');
      transport.replyImage(200, new Uint8Array([60, 104, 116, 109, 108]).buffer as ArrayBuffer, 'image/png');
      expect(await rejectedCode(repository.avatar())).assertEqual('CONTRACT_ERROR');
    });

    it('avatarOldFileResponseCannotReturnAfterAccountOrAvatarChanges', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueAvatarLogin(transport);
      await repository.login('alice', 'Starward1234');
      transport.reply(200, '{"token":"file-token"}');
      transport.replyImage(200, pngBytes());
      await repository.avatar();
      transport.deferNext();
      const oldAvatar: Promise<AvatarImage | null> = repository.avatar();
      await nextTurn();
      transport.reply(200, AVATAR_PLAYER_JSON.replace('portrait.png', 'new.png'));
      await repository.updateProfile('Alice', uploadPng());
      transport.completeImage(200, pngBytes());
      expect(await rejectedCode(oldAvatar)).assertEqual('CANCELLED');
      transport.reply(200, '{"token":"new-file-token"}');
      transport.replyImage(200, pngBytes());
      await repository.avatar();
      transport.deferNext();
      const oldAccount: Promise<AvatarImage | null> = repository.avatar();
      await nextTurn();
      repository.logout();
      transport.completeImage(200, pngBytes());
      expect(await rejectedCode(oldAccount)).assertEqual('CANCELLED');
    });

    it('avatarTokenAuthenticationFailureClearsMainSession', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueAvatarLogin(transport);
      await repository.login('alice', 'Starward1234');
      transport.reply(401, '{}');
      expect(await rejectedCode(repository.avatar())).assertEqual('UNAUTHORIZED');
      expect(await rejectedCode(repository.me())).assertEqual('UNAUTHORIZED');
    });

    it('stalePlayerReadCannotRestoreThePreviousAvatarAfterProfileSave', 0, async () => {
      const transport: StubTransport = new StubTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      queueAvatarLogin(transport);
      await repository.login('alice', 'Starward1234');
      transport.deferNext();
      const stale: Promise<Player> = repository.me();
      transport.reply(200, AVATAR_PLAYER_JSON.replace('portrait.png', 'new.png'));
      await repository.updateProfile('Alice', uploadPng());
      transport.complete(200, AVATAR_PLAYER_JSON);
      expect(await rejectedCode(stale)).assertEqual('CANCELLED');
      transport.reply(200, '{"token":"file-token"}');
      transport.replyImage(200, pngBytes());
      await repository.avatar();
      expect(transport.requests[5].url).assertContain('/new.png?token=');
    });

    it('mockProfilePersistsOnlyInThisDemoRepositoryAndRejectsLateWrite', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      await repository.login('alice', 'Starward1234');
      await repository.changePassword('Starward1234', 'NewStarward1234', 'NewStarward1234');
      expect((await repository.updateProfile(' 新旅人 ', uploadPng())).displayName).assertEqual('新旅人');
      expect((await repository.avatar())?.mimeType).assertEqual('image/png');
      repository.logout();
      expect((await repository.login('alice', 'NewStarward1234')).displayName).assertEqual('新旅人');
      const pending: Promise<Player> = repository.updateProfile('不应保存');
      repository.logout();
      expect(await rejectedCode(pending)).assertEqual('CANCELLED');
      expect((await repository.login('alice', 'NewStarward1234')).displayName).assertEqual('新旅人');
    });
  });
}
