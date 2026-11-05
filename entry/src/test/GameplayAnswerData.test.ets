import { describe, expect, it } from '@ohos/hypium';
import { GameFailure, Player } from '../main/ets/business/models';
import { GameplayAnswerResult } from '../main/ets/business/GameplayModels';
import { decodeGameplayAnswer } from '../main/ets/data/GameplayDecoder';
import { HttpsGameRepository } from '../main/ets/data/HttpsGameRepository';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { HttpTransport, TransportRequest, TransportResponse } from '../main/ets/platform/HttpTransport';
import { GAMEPLAY_CANCELLED_STARTED_JSON, GAMEPLAY_COMPLETED_JSON,
  GAMEPLAY_PLAYER_100_JSON, GAMEPLAY_PLAYER_50_JSON, GAMEPLAY_PLAYER_JSON, GAMEPLAY_STARTED_JSON,
  gameplayAnswerFixture } from './fixtures/GameplayFixture';

class AnswerTransport implements HttpTransport {
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

  complete(body: string): void {
    const value: TransportResponse = new TransportResponse();
    value.status = 200;
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
      throw new GameFailure('TEST_FIXTURE_MISSING', 'Missing answer test reply');
    }
    return value;
  }
}

async function login(repository: HttpsGameRepository, transport: AnswerTransport,
  token: string = 'answer-test-token'): Promise<void> {
  transport.reply(200, '{"token":"' + token + '","record":{"id":"playeralice"}}');
  transport.reply(200, GAMEPLAY_PLAYER_JSON);
  await repository.login('alice', 'test-password');
}

async function rejected<T>(task: Promise<T>): Promise<string> {
  try {
    await task;
    return 'RESOLVED';
  } catch (error) {
    return (error as GameFailure).code;
  }
}

function contractRejected(body: string): void {
  let code: string = '';
  try {
    decodeGameplayAnswer(body);
  } catch (error) {
    code = (error as GameFailure).code;
  }
  expect(code).assertEqual('CONTRACT_ERROR');
}

async function demoReady(repository: MockGameRepository): Promise<void> {
  await repository.login('alice', 'Starward1234');
  await repository.changePassword('Starward1234', 'NewStarward1234', 'NewStarward1234');
  await repository.startAssignment('assignment1', 'demo-start');
}

export default function gameplayAnswerDataTests(): void {
  describe('GameplayAnswerData', () => {
    it('keepsHistoricalOutcomeSeparateFromFreshAuthoritativePlayerAndProgress', 0, () => {
      const body: string = gameplayAnswerFixture('incorrect', GAMEPLAY_COMPLETED_JSON,
        GAMEPLAY_PLAYER_100_JSON.replace('远航者', '服务端新昵称'), 0);
      const result: GameplayAnswerResult = decodeGameplayAnswer(body);
      expect(result.result).assertEqual('incorrect');
      expect(result.xpDelta).assertEqual(0);
      expect(result.assignment.detail.status).assertEqual('completed');
      expect(result.assignment.detail.completedLevels).assertEqual(2);
      expect(result.player.totalXp).assertEqual(100);
      expect(result.player.displayName).assertEqual('服务端新昵称');
      const already: GameplayAnswerResult = decodeGameplayAnswer(gameplayAnswerFixture('already_completed',
        GAMEPLAY_COMPLETED_JSON, GAMEPLAY_PLAYER_100_JSON, 0));
      expect(already.result).assertEqual('already_completed');
      expect(already.effects.length).assertEqual(0);
    });

    it('rejectsMissingOrMalformedAnswerFactsInsteadOfAnEmptySuccess', 0, () => {
      const body: string = gameplayAnswerFixture('correct');
      contractRejected(body.replace('"result":"correct"', '"result":"success"'));
      contractRejected(body.replace('"xpDelta":50', '"xpDelta":-1'));
      contractRejected(body.replace('"rewardIds":[]', '"rewardIds":[null]'));
      contractRejected(body.replace('"rewardIds":[]', '"rewardIds":[""]'));
      contractRejected(body.replace('"effects":[]', '"effects":null'));
      contractRejected(body.replace('"player":{', '"missingPlayer":{'));
      contractRejected(body.replace('"totalXp":50', '"totalXp":"50"'));
      contractRejected(body.replace('"assignment":{', '"missingAssignment":{'));
      const effects: string = body.replace('"effects":[]',
        '"effects":[{"type":"clue","clueId":"effect0","autoPlay":false}]');
      expect(decodeGameplayAnswer(effects).effects[0].autoPlay).assertFalse();
      expect(decodeGameplayAnswer(effects.replace(',"effects":[{"type":"clue","clueId":"effect0","autoPlay":false}]', '')).effects.length).assertEqual(0);
    });

    it('explicitRetryPreservesRawAnswerLevelRequestIdAndCredential', 0, async () => {
      const transport: AnswerTransport = new AnswerTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      await login(repository, transport);
      const rawAnswer: string = '  星辰大海\n ';
      transport.reply(503, '{"error":{"code":"TEMPORARY","message":"暂时不可用"}}');
      expect(await rejected(repository.answerAssignment('assignment1', 'step0', rawAnswer, 'frozen-answer'))).assertEqual('TEMPORARY');
      expect(transport.requests.length).assertEqual(3);
      transport.reply(200, gameplayAnswerFixture('correct'));
      const result: GameplayAnswerResult = await repository.answerAssignment('assignment1', 'step0', rawAnswer, 'frozen-answer');
      expect(result.result).assertEqual('correct');
      expect(transport.requests.length).assertEqual(4);
      expect(transport.requests[3].url).assertEqual('https://isolated.example/api/questions/v1/assignments/assignment1/answers');
      expect(transport.requests[3].method).assertEqual('POST');
      expect(transport.requests[3].body).assertEqual('{"sessionLevelId":"step0","answer":"  星辰大海\\n ","requestId":"frozen-answer"}');
      expect(transport.requests[3].body).assertEqual(transport.requests[2].body);
      expect(transport.requests[3].token).assertEqual('answer-test-token');
    });

    it('http200IncorrectDoesNotBecomeACorrectResultAndBusinessErrorsArePreserved', 0, async () => {
      const transport: AnswerTransport = new AnswerTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      await login(repository, transport);
      transport.reply(200, gameplayAnswerFixture('incorrect', GAMEPLAY_STARTED_JSON, GAMEPLAY_PLAYER_JSON, 0));
      const result: GameplayAnswerResult = await repository.answerAssignment('assignment1', 'step0', '错误答案', 'incorrect-command');
      expect(result.result).assertEqual('incorrect');
      expect(result.assignment.detail.completedLevels).assertEqual(0);
      expect(result.player.totalXp).assertEqual(0);
      transport.reply(409, '{"error":{"code":"COOLDOWN","message":"请等待冷却结束"}}');
      expect(await rejected(repository.answerAssignment('assignment1', 'step0', '相同答案', 'cooldown-command'))).assertEqual('COOLDOWN');
      transport.reply(429, '{"error":{"code":"RATE_LIMITED","message":"请稍后再试"}}');
      expect(await rejected(repository.answerAssignment('assignment1', 'step0', '相同答案', 'rate-command'))).assertEqual('RATE_LIMITED');
      expect(transport.requests.length).assertEqual(5);
    });

    it('bindsThePlayerAssignmentAndSessionLevelRatherThanAQuestionId', 0, async () => {
      const transport: AnswerTransport = new AnswerTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      await login(repository, transport);
      transport.reply(200, gameplayAnswerFixture('correct').replace('"player":"playeralice"', '"player":"other"'));
      expect(await rejected(repository.answerAssignment('assignment1', 'step0', '答案', 'owner'))).assertEqual('CONTRACT_ERROR');
      transport.reply(200, gameplayAnswerFixture('correct').replace('"id":"playeralice"', '"id":"other"'));
      expect(await rejected(repository.answerAssignment('assignment1', 'step0', '答案', 'player'))).assertEqual('CONTRACT_ERROR');
      transport.reply(200, gameplayAnswerFixture('correct').replace('"id":"assignment1"', '"id":"other"'));
      expect(await rejected(repository.answerAssignment('assignment1', 'step0', '答案', 'assignment'))).assertEqual('CONTRACT_ERROR');
      transport.reply(200, gameplayAnswerFixture('correct'));
      expect(await rejected(repository.answerAssignment('assignment1', 'question0', '答案', 'question-id'))).assertEqual('CONTRACT_ERROR');
    });

    it('lateAnswerCannotChangeTheNewAccountOrAvatarCache', 0, async () => {
      const transport: AnswerTransport = new AnswerTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      await login(repository, transport);
      transport.deferNext();
      const oldAnswer: Promise<GameplayAnswerResult> = repository.answerAssignment('assignment1', 'step0', '旧答案', 'old-command');
      repository.logout();
      await login(repository, transport, 'new-account-token');
      transport.complete(gameplayAnswerFixture('correct').replace('"avatar":""', '"avatar":"old-avatar.png"'));
      expect(await rejected(oldAnswer)).assertEqual('CANCELLED');
      expect(await repository.avatar()).assertNull();
      transport.reply(200, gameplayAnswerFixture('incorrect', GAMEPLAY_STARTED_JSON, GAMEPLAY_PLAYER_JSON, 0));
      await repository.answerAssignment('assignment1', 'step0', '新答案', 'new-command');
      expect(transport.requests[5].token).assertEqual('new-account-token');
    });

    it('anAcceptedAnswerInvalidatesEarlierPlayerReadsAndProfileResponses', 0, async () => {
      const transport: AnswerTransport = new AnswerTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      await login(repository, transport);
      transport.deferNext();
      const staleMe: Promise<Player> = repository.me();
      transport.reply(200, gameplayAnswerFixture('correct'));
      await repository.answerAssignment('assignment1', 'step0', '星辰大海', 'answer-before-read');
      transport.complete(GAMEPLAY_PLAYER_JSON);
      expect(await rejected(staleMe)).assertEqual('CANCELLED');
      transport.deferNext();
      const staleProfile: Promise<Player> = repository.updateProfile('旧回复里的昵称');
      transport.reply(200, gameplayAnswerFixture('already_completed', GAMEPLAY_COMPLETED_JSON, GAMEPLAY_PLAYER_100_JSON, 0));
      await repository.answerAssignment('assignment1', 'step0', '星辰大海', 'another-answer');
      transport.complete(GAMEPLAY_PLAYER_JSON);
      expect(await rejected(staleProfile)).assertEqual('CANCELLED');
      transport.reply(200, GAMEPLAY_PLAYER_100_JSON);
      expect((await repository.me()).totalXp).assertEqual(100);
    });

    it('validatesTrimmedLimitsButNeverRewritesTheSentRawPayload', 0, async () => {
      const transport: AnswerTransport = new AnswerTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      await login(repository, transport);
      expect(await rejected(repository.answerAssignment('assignment1', 'step0', ' ', 'empty'))).assertEqual('VALIDATION_ERROR');
      expect(await rejected(repository.answerAssignment('assignment1', 's'.repeat(31), '答案', 'long-level'))).assertEqual('VALIDATION_ERROR');
      expect(await rejected(repository.answerAssignment('assignment1', 'step0', '答'.repeat(4001), 'long-answer'))).assertEqual('VALIDATION_ERROR');
      expect(await rejected(repository.answerAssignment('assignment1', 'step0', '答案', 'r'.repeat(101)))).assertEqual('VALIDATION_ERROR');
      expect(transport.requests.length).assertEqual(2);
      const rawAnswer: string = ' '.repeat(2001) + '星辰大海' + ' '.repeat(2001);
      transport.reply(200, gameplayAnswerFixture('correct'));
      await repository.answerAssignment('assignment1', ' step0 ', rawAnswer, 'padded');
      expect(transport.requests[2].body).assertContain('"sessionLevelId":" step0 "');
      expect(transport.requests[2].body).assertContain(JSON.stringify(rawAnswer));
    });

    it('demoReceiptsNeverDoubleXpOrWrongCountAndReturnFreshCompletionFacts', 0, async () => {
      const repository: MockGameRepository = new MockGameRepository(0);
      await demoReady(repository);
      const textWrong: GameplayAnswerResult = await repository.answerAssignment('assignment1', 'step0', '错误', 'text-wrong');
      expect(textWrong.result).assertEqual('incorrect');
      expect(textWrong.assignment.levels[0].wrongCount).assertEqual(0);
      expect(await rejected(repository.answerAssignment('assignment1', 'step0', '星辰大海', 'text-wrong'))).assertEqual('IDEMPOTENCY_CONFLICT');
      const first: GameplayAnswerResult = await repository.answerAssignment('assignment1', 'step0', ' 星辰大海 ', 'text-correct');
      expect(first.result).assertEqual('correct');
      expect(first.player.totalXp).assertEqual(50);
      expect(first.assignment.detail.currentIndex).assertEqual(1);
      const repeated: GameplayAnswerResult = await repository.answerAssignment('assignment1', 'step0', ' 星辰大海 ', 'text-correct');
      expect(repeated.xpDelta).assertEqual(50);
      expect(repeated.player.totalXp).assertEqual(50);
      const wrong: GameplayAnswerResult = await repository.answerAssignment('assignment1', 'step1', 'A', 'choice-wrong');
      expect(wrong.assignment.levels[1].wrongCount).assertEqual(1);
      const repeatedWrong: GameplayAnswerResult = await repository.answerAssignment('assignment1', 'step1', 'A', 'choice-wrong');
      expect(repeatedWrong.assignment.levels[1].wrongCount).assertEqual(1);
      const final: GameplayAnswerResult = await repository.answerAssignment('assignment1', 'step1', 'B', 'choice-correct');
      expect(final.assignment.detail.status).assertEqual('completed');
      expect(final.assignment.detail.completedLevels).assertEqual(2);
      expect(final.player.totalXp).assertEqual(100);
      expect(final.player.level.order).assertEqual(2);
      const replay: GameplayAnswerResult = await repository.answerAssignment('assignment1', 'step1', 'A', 'choice-wrong');
      expect(replay.result).assertEqual('incorrect');
      expect(replay.assignment.detail.status).assertEqual('completed');
      expect(replay.player.totalXp).assertEqual(100);
      const completed: GameplayAnswerResult = await repository.answerAssignment('assignment1', 'step0', '星辰大海', 'new-completed-command');
      expect(completed.result).assertEqual('already_completed');
      expect(completed.xpDelta).assertEqual(0);
    });

    it('successfulReceiptsMayCarryTheLatestCancelledSnapshot', 0, async () => {
      const transport: AnswerTransport = new AnswerTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      await login(repository, transport);
      transport.reply(200, GAMEPLAY_CANCELLED_STARTED_JSON);
      expect((await repository.startAssignment('assignment1', 'old-start')).detail.status).assertEqual('cancelled');
      transport.reply(200, gameplayAnswerFixture('correct', GAMEPLAY_CANCELLED_STARTED_JSON, GAMEPLAY_PLAYER_100_JSON, 50));
      const result: GameplayAnswerResult = await repository.answerAssignment('assignment1', 'step0', '原答案', 'old-receipt');
      expect(result.result).assertEqual('correct');
      expect(result.assignment.detail.status).assertEqual('cancelled');
      expect(result.assignment.levels[0].question).assertNull();
      const demo: MockGameRepository = new MockGameRepository(0);
      await demoReady(demo);
      await demo.answerAssignment('assignment1', 'step0', '星辰大海', 'demo-old-answer');
      demo.fixture.status = 'cancelled';
      expect((await demo.startAssignment('assignment1', 'demo-start')).detail.status).assertEqual('cancelled');
      expect((await demo.answerAssignment('assignment1', 'step0', '星辰大海', 'demo-old-answer')).assignment.detail.status).assertEqual('cancelled');
    });
  });
}
