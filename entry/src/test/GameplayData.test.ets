import { describe, expect, it } from '@ohos/hypium';
import { GameFailure } from '../main/ets/business/models';
import { ReadCancellation } from '../main/ets/business/ReadCancellation';
import { GameplaySnapshot } from '../main/ets/business/GameplayModels';
import { decodeGameplay } from '../main/ets/data/GameplayDecoder';
import { HttpsGameRepository } from '../main/ets/data/HttpsGameRepository';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { HttpTransport, TransportRequest, TransportResponse } from '../main/ets/platform/HttpTransport';
import { PLAYER_JSON } from './Contract.test';
import { GAMEPLAY_CHOICE_JSON, GAMEPLAY_STARTED_JSON, GAMEPLAY_TEXT_QUESTION_JSON,
  GAMEPLAY_UNSTARTED_JSON } from './fixtures/GameplayFixture';

class GameplayTransport implements HttpTransport {
  requests: TransportRequest[] = [];
  replies: TransportResponse[] = [];
  private pending: Promise<TransportResponse> | null = null;
  private resolvePending: (value: TransportResponse) => void = (_value: TransportResponse) => {};

  reply(status: number, body: string): void {
    const value: TransportResponse = new TransportResponse();
    value.status = status;
    value.body = body;
    this.replies.push(value);
  }

  deferNext(): void {
    this.pending = new Promise<TransportResponse>((resolve: (value: TransportResponse) => void) => {
      this.resolvePending = resolve;
    });
  }

  complete(body: string, status: number = 200): void {
    const value: TransportResponse = new TransportResponse();
    value.status = status;
    value.body = body;
    this.resolvePending(value);
  }

  async send(request: TransportRequest): Promise<TransportResponse> {
    this.requests.push(request);
    if (this.pending !== null) {
      const pending: Promise<TransportResponse> = this.pending;
      this.pending = null;
      return pending;
    }
    const value: TransportResponse | undefined = this.replies.shift();
    if (value === undefined) {
      throw new GameFailure('TEST_FIXTURE_MISSING', 'Missing gameplay test reply');
    }
    return value;
  }
}

function contractRejected(body: string): void {
  let code: string = '';
  try {
    decodeGameplay(body);
  } catch (error) {
    code = (error as GameFailure).code;
  }
  expect(code).assertEqual('CONTRACT_ERROR');
}

async function rejected<T>(task: Promise<T>): Promise<string> {
  try {
    await task;
    return 'RESOLVED';
  } catch (error) {
    return (error as GameFailure).code;
  }
}

async function login(repository: HttpsGameRepository, transport: GameplayTransport,
  token: string = 'gameplay-test-token'): Promise<void> {
  transport.reply(200, '{"token":"' + token + '","record":{"id":"playeralice"}}');
  transport.reply(200, PLAYER_JSON.replace('"mustChangePassword":true', '"mustChangePassword":false'));
  await repository.login('alice', 'test-password');
}

export default function gameplayDataTests(): void {
  describe('GameplayData', () => {
    it('cancelledReadCannotInvalidateTheSessionWithALateUnauthorizedReply', 0, async () => {
      const transport: GameplayTransport = new GameplayTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      await login(repository, transport);
      transport.deferNext();
      const cancellation: ReadCancellation = new ReadCancellation();
      const pending: Promise<GameplaySnapshot> = repository.gameplay('assignment1', cancellation);
      expect(transport.requests[2].cancellation === cancellation).assertTrue();
      cancellation.cancel();
      transport.complete('{"error":{"code":"UNAUTHORIZED","message":"旧请求失败"}}', 401);
      expect(await rejected(pending)).assertEqual('CANCELLED');
      transport.reply(200, GAMEPLAY_STARTED_JSON);
      await repository.gameplay('assignment1');
      expect(transport.requests[3].token).assertEqual('gameplay-test-token');
    });

    it('keepsUnstartedQuestionsNullAndDecodesTheVisibleTextQuestionAfterEntry', 0, () => {
      const before: GameplaySnapshot = decodeGameplay(GAMEPLAY_UNSTARTED_JSON);
      expect(before.levels.length).assertEqual(2);
      expect(before.levels[0].question).assertNull();
      expect(before.levels[1].question).assertNull();
      const started: GameplaySnapshot = decodeGameplay(GAMEPLAY_STARTED_JSON);
      expect(started.detail.status).assertEqual('active');
      expect(started.levels[0].question?.title).assertEqual('星辰之门');
      expect(started.levels[0].question?.content[0].hint).assertEqual('抬头看看');
      expect(started.levels[1].question).assertNull();
      expect(started.presentation.bgmMode).assertEqual('silent');
    });

    it('decodesTheAuthoritativeChoiceOptionsAndCompletedProgress', 0, () => {
      const snapshot: GameplaySnapshot = decodeGameplay(GAMEPLAY_CHOICE_JSON);
      expect(snapshot.detail.currentIndex).assertEqual(1);
      expect(snapshot.detail.completedLevels).assertEqual(1);
      expect(snapshot.levels[0].completedAt.length > 0).assertTrue();
      expect(snapshot.levels[1].question?.kind).assertEqual('choice');
      expect(snapshot.levels[1].question?.options[1].key).assertEqual('B');
      expect(snapshot.levels[1].question?.options[1].text).assertEqual('北极星');
    });

    it('rejectsMissingOrMalformedGameplayDataWithoutAnEmptySuccess', 0, () => {
      contractRejected(GAMEPLAY_STARTED_JSON.replace('"levels":[', '"otherLevels":['));
      contractRejected(GAMEPLAY_STARTED_JSON.replace('"totalLevels":2', '"totalLevels":1'));
      contractRejected(GAMEPLAY_STARTED_JSON.replace('"currentIndex":0', '"currentIndex":2'));
      contractRejected(GAMEPLAY_STARTED_JSON.replace('"locked":false', '"locked":"false"'));
      contractRejected(GAMEPLAY_STARTED_JSON.replace('"wrongCount":0', '"wrongCount":-1'));
      contractRejected(GAMEPLAY_STARTED_JSON.replace('"cooldownUntil":""', '"cooldownUntil":"invalid"'));
      contractRejected(GAMEPLAY_STARTED_JSON.replace('"id":"step1"', '"id":"step0"'));
    });

    it('rejectsLeakedFutureQuestionsAndMissingCurrentQuestions', 0, () => {
      contractRejected(GAMEPLAY_UNSTARTED_JSON.replace('"question":null', '"question":' + GAMEPLAY_TEXT_QUESTION_JSON));
      contractRejected(GAMEPLAY_STARTED_JSON.replace('"question":null', '"question":' + GAMEPLAY_TEXT_QUESTION_JSON));
      contractRejected(GAMEPLAY_STARTED_JSON.replace('"question":' + GAMEPLAY_TEXT_QUESTION_JSON, '"question":null'));
      contractRejected(GAMEPLAY_CHOICE_JSON.replace('"key":"B"', '"key":"A"'));
    });

    it('keepsOptionalEffectsAndPresentationFieldsDistinctFromInvalidTypes', 0, () => {
      const body: string = GAMEPLAY_STARTED_JSON.slice(0, -1) +
        ',"transitionEffects":[{"type":"clue","clueId":"clue0","autoPlay":false}]}';
      expect(decodeGameplay(body).transitionEffects[0].autoPlay).assertFalse();
      expect(decodeGameplay(body).transitionEffectsProvided).assertTrue();
      expect(decodeGameplay(GAMEPLAY_STARTED_JSON).transitionEffects.length).assertEqual(0);
      expect(decodeGameplay(GAMEPLAY_STARTED_JSON).transitionEffectsProvided).assertFalse();
      const empty: string = GAMEPLAY_STARTED_JSON.slice(0, -1) + ',"transitionEffects":[]}';
      expect(decodeGameplay(empty).transitionEffectsProvided).assertTrue();
      expect(decodeGameplay(empty).transitionEffects.length).assertEqual(0);
      expect(decodeGameplay(GAMEPLAY_STARTED_JSON).levels[0].presentationOverride.hideTitle).assertUndefined();
      contractRejected(body.replace('"autoPlay":false', '"autoPlay":"false"'));
      contractRejected(GAMEPLAY_STARTED_JSON.replace('"bgmMode":"silent"', '"bgmMode":"unknown"'));
    });

    it('startUsesTheCallerRequestIdAndRawAuthorizationWithoutAutomaticReplay', 0, async () => {
      const transport: GameplayTransport = new GameplayTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      await login(repository, transport);
      transport.reply(503, '{"error":{"code":"TEMPORARY","message":"重试"}}');
      expect(await rejected(repository.startAssignment('assignment1', 'same-command'))).assertEqual('TEMPORARY');
      expect(transport.requests.length).assertEqual(3);
      transport.reply(200, GAMEPLAY_STARTED_JSON);
      await repository.startAssignment('assignment1', 'same-command');
      expect(transport.requests.length).assertEqual(4);
      expect(transport.requests[2].body).assertEqual('{"requestId":"same-command"}');
      expect(transport.requests[3].body).assertEqual(transport.requests[2].body);
      expect(transport.requests[3].token).assertEqual('gameplay-test-token');
      expect(transport.requests[3].method).assertEqual('POST');
      expect(transport.requests[3].url).assertEqual('https://isolated.example/api/questions/v1/assignments/assignment1/start');
    });

    it('snapshotAndStartRejectAnotherPlayerOrAssignmentAndPreserveBusinessErrors', 0, async () => {
      const transport: GameplayTransport = new GameplayTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      await login(repository, transport);
      transport.reply(200, GAMEPLAY_STARTED_JSON.replace('"player":"playeralice"', '"player":"other"'));
      expect(await rejected(repository.gameplay('assignment1'))).assertEqual('CONTRACT_ERROR');
      transport.reply(200, GAMEPLAY_STARTED_JSON.replace('"id":"assignment1"', '"id":"other"'));
      expect(await rejected(repository.startAssignment('assignment1', 'command'))).assertEqual('CONTRACT_ERROR');
      transport.reply(200, GAMEPLAY_UNSTARTED_JSON);
      expect(await rejected(repository.startAssignment('assignment1', 'command'))).assertEqual('CONTRACT_ERROR');
      transport.reply(409, '{"error":{"code":"SESSION_OFFLINE","message":"该场次已下线"}}');
      expect(await rejected(repository.startAssignment('assignment1', 'command'))).assertEqual('SESSION_OFFLINE');
      expect(transport.requests[2].method).assertEqual('GET');
      expect(transport.requests[2].body).assertEqual('');
    });

    it('lateEntryResponseCannotReturnAfterLogoutOrCredentialRotation', 0, async () => {
      const transport: GameplayTransport = new GameplayTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      await login(repository, transport);
      transport.deferNext();
      const pending: Promise<GameplaySnapshot> = repository.startAssignment('assignment1', 'old-command');
      repository.logout();
      await login(repository, transport, 'new-test-token');
      transport.complete(GAMEPLAY_STARTED_JSON);
      expect(await rejected(pending)).assertEqual('CANCELLED');
      transport.reply(200, GAMEPLAY_STARTED_JSON);
      await repository.gameplay('assignment1');
      expect(transport.requests[5].token).assertEqual('new-test-token');
    });

    it('invalidCommandDoesNotSendAndDemoEntryDoesNotRecreateProgress', 0, async () => {
      const transport: GameplayTransport = new GameplayTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      await login(repository, transport);
      expect(await rejected(repository.startAssignment('assignment1', ' '))).assertEqual('VALIDATION_ERROR');
      expect(transport.requests.length).assertEqual(2);
      const demo: MockGameRepository = new MockGameRepository(0);
      await demo.login('alice', 'Starward1234');
      await demo.changePassword('Starward1234', 'NewStarward1234', 'NewStarward1234');
      const first: GameplaySnapshot = await demo.startAssignment('assignment1', 'same-demo-command');
      const again: GameplaySnapshot = await demo.startAssignment('assignment1', 'same-demo-command');
      expect(demo.mode).assertEqual('mock');
      expect(again.detail.startedAt).assertEqual(first.detail.startedAt);
      expect(again.detail.completedLevels).assertEqual(0);
      expect(again.levels[1].question).assertNull();
    });
  });
}
