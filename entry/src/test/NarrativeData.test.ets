import { describe, expect, it } from '@ohos/hypium';
import { NarrativeContent } from '../main/ets/business/NarrativeModels';
import { ReadCancellation } from '../main/ets/business/ReadCancellation';
import { GameFailure } from '../main/ets/business/models';
import { decodeNarrative } from '../main/ets/data/NarrativeDecoder';
import { HttpsGameRepository } from '../main/ets/data/HttpsGameRepository';
import { HttpTransport, TransportRequest, TransportResponse } from '../main/ets/platform/HttpTransport';
import { PLAYER_JSON } from './Contract.test';

const letterJson: string = '{"id":"letter01","kind":"letter","title":"给旅人的信","payload":{' +
  '"variant":"magic","description":"约定","from":"旅人","hintText":"开启这封信",' +
  '"paragraphs":[{"content":"第一页\\n\\n继续","align":"top","delayMs":6000},' +
  '{"content":"另一页","align":"right","audioUrl":"https://media.example.org/speech.mp3"}],' +
  '"backgroundImages":["https://media.example.org/stars.png","http://media.example.org/sky.png"],' +
  '"pageBackgroundUrl":"/assets/paper.webp","mainAudioUrl":"https://media.example.org/theme.mp3","typingSpeedMs":15}}';
const blessJson: string = '{"id":"bless01","kind":"bless","title":"一些祝愿","payload":{' +
  '"from":"星海","mainAudioUrl":"https://media.example.org/music.mp3",' +
  '"phrases":[{"text":"第一句","durationMs":7200,"audioUrl":"https://media.example.org/opening.mp3"},' +
  '{"text":"第二句"}],"closingLines":[{"text":"片尾第一句","durationMs":0,"audioUrl":"/assets/end.mp3"},' +
  '{"text":"片尾第二句","audioUrl":"http://media.example.org/insecure.mp3"}]}}';

class NarrativeTransport implements HttpTransport {
  requests: TransportRequest[] = [];
  private replies: TransportResponse[] = [];
  private pending: Promise<TransportResponse> | null = null;
  private resolvePending: (response: TransportResponse) => void = (_response: TransportResponse) => {};

  private response(status: number, body: string): TransportResponse {
    const response: TransportResponse = new TransportResponse();
    response.status = status;
    response.body = body;
    return response;
  }

  reply(status: number, body: string): void {
    this.replies.push(this.response(status, body));
  }

  defer(): void {
    this.pending = new Promise<TransportResponse>((resolve: (response: TransportResponse) => void) => {
      this.resolvePending = resolve;
    });
  }

  complete(status: number, body: string): void {
    this.resolvePending(this.response(status, body));
  }

  async send(request: TransportRequest): Promise<TransportResponse> {
    this.requests.push(request);
    if (this.pending !== null) {
      const pending: Promise<TransportResponse> = this.pending;
      this.pending = null;
      return pending;
    }
    const reply: TransportResponse | undefined = this.replies.shift();
    if (reply === undefined) { throw new GameFailure('TEST_FIXTURE_MISSING', 'Missing narrative test response'); }
    return reply;
  }
}

function invalid(body: string): void {
  let code: string = '';
  try { decodeNarrative(body); } catch (error) { code = (error as GameFailure).code; }
  expect(code).assertEqual('CONTRACT_ERROR');
}

async function rejected(task: Promise<NarrativeContent>): Promise<string> {
  try { await task; return ''; } catch (error) { return (error as GameFailure).code; }
}

async function login(repository: HttpsGameRepository, transport: NarrativeTransport, token: string): Promise<void> {
  transport.reply(200, '{"token":"' + token + '","record":{"id":"playeralice"}}');
  transport.reply(200, PLAYER_JSON.replace('"mustChangePassword":true', '"mustChangePassword":false'));
  await repository.login('alice', 'test-password');
}

export default function narrativeDataTests(): void {
  describe('NarrativeData', () => {
    it('keepsAuthoredTextOrderAlignmentAndSupportedMediaSyntax', 0, () => {
      const value: NarrativeContent = decodeNarrative(letterJson);
      expect(value.kind).assertEqual('letter');
      expect(value.title).assertEqual('给旅人的信');
      expect(value.letter?.variant).assertEqual('magic');
      expect(value.letter?.from).assertEqual('旅人');
      expect(value.letter?.hintText).assertEqual('开启这封信');
      expect(value.letter?.paragraphs[0].content).assertEqual('第一页\n\n继续');
      expect(value.letter?.paragraphs[0].align).assertEqual('top');
      expect(value.letter?.paragraphs[0].delayMs).assertEqual(6000);
      expect(value.letter?.paragraphs[1].audioUrl).assertEqual('https://media.example.org/speech.mp3');
      expect(value.letter?.backgroundImages.join('|')).assertEqual('https://media.example.org/stars.png|');
      expect(value.letter?.pageBackgroundUrl).assertEqual('/assets/paper.webp');
      expect(value.letter?.typingSpeedMs).assertEqual(15);
    });

    it('supportsOmittedLegacyPresentationFieldsAndIsolatesUnsupportedMedia', 0, () => {
      const body: string = '{"id":"letter01","kind":"letter","title":"旧信纸","payload":{' +
        '"variant":"classical","paragraphs":[{"content":"旧段落"}],"pageBackgroundUrl":"//media.example.org/n.png",' +
        '"mainAudioUrl":"https://user@media.example.org/song.mp3"}}';
      const value: NarrativeContent = decodeNarrative(body);
      expect(value.letter?.hintText).assertEqual('点击开启信件');
      expect(value.letter?.description).assertEqual('');
      expect(value.letter?.paragraphs[0].align).assertEqual('left');
      expect(value.letter?.paragraphs[0].delayMs).assertEqual(0);
      expect(value.letter?.typingSpeedMs).assertEqual(60);
      expect(value.letter?.backgroundImages.length).assertEqual(0);
      expect(value.letter?.pageBackgroundUrl).assertEqual('');
      expect(value.letter?.mainAudioUrl).assertEqual('');
    });

    it('keepsBlessingPhrasesAndClosingLinesInOrderWithTheirOwnAudioAndTiming', 0, () => {
      const value: NarrativeContent = decodeNarrative(blessJson);
      expect(value.kind).assertEqual('bless');
      expect(value.letter).assertNull();
      expect(value.hasPresentation()).assertTrue();
      expect(value.bless?.from).assertEqual('星海');
      expect(value.bless?.mainAudioUrl).assertEqual('https://media.example.org/music.mp3');
      expect(value.bless?.phrases.length).assertEqual(2);
      expect(value.bless?.phrases[0].text).assertEqual('第一句');
      expect(value.bless?.phrases[0].durationMs).assertEqual(7200);
      expect(value.bless?.phrases[0].audioUrl).assertEqual('https://media.example.org/opening.mp3');
      expect(value.bless?.phrases[1].durationMs).assertEqual(3000);
      expect(value.bless?.phrases[1].audioUrl).assertEqual('');
      expect(value.bless?.closingLines.length).assertEqual(2);
      expect(value.bless?.closingLines[0].text).assertEqual('片尾第一句');
      expect(value.bless?.closingLines[0].durationMs).assertEqual(0);
      expect(value.bless?.closingLines[0].audioUrl).assertEqual('/assets/end.mp3');
      expect(value.bless?.closingLines[1].audioUrl).assertEqual('');
    });

    it('defaultsOmittedBlessingFieldsAndRejectsUnsupportedShapes', 0, () => {
      const bless: NarrativeContent = decodeNarrative('{"id":"bless01","kind":"bless","title":"一些祝愿",' +
        '"payload":{"phrases":[{"text":"星光照亮前路"}]}}');
      expect(bless.bless?.closingLines.length).assertEqual(0);
      expect(bless.bless?.mainAudioUrl).assertEqual('');
      expect(bless.bless?.from).assertEqual('');
      invalid(blessJson.replace(':7200', ':-1'));
      invalid(blessJson.replace('"片尾第一句"', '42'));
      invalid(letterJson.replace('"top"', '"vertical"'));
      invalid(letterJson.replace('"magic"', '"unknown"'));
      invalid(letterJson.replace(':6000', ':-1'));
      invalid('{"id":"letter01","kind":"letter","title":"无内容","payload":{"variant":"modern","paragraphs":[]}}');
      invalid('{"id":"bless01","kind":"bless","title":"无内容","payload":{"phrases":[]}}');
      invalid('{"id":"known01","kind":"other","title":"未知内容","payload":{}}');
    });

    it('usesExactAuthenticatedReadAndRejectsDifferentResponseIdentityWithoutWriting', 0, async () => {
      const transport: NarrativeTransport = new NarrativeTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      await login(repository, transport, 'narrative-test-token');
      const cancellation: ReadCancellation = new ReadCancellation();
      transport.reply(200, letterJson);
      expect((await repository.narrative('assignment1', 'letter01', cancellation)).id).assertEqual('letter01');
      const request: TransportRequest = transport.requests[2];
      expect(request.url).assertEqual('https://isolated.example/api/questions/v1/assignments/assignment1/narratives/letter01');
      expect(request.method).assertEqual('GET');
      expect(request.body).assertEqual('');
      expect(request.token).assertEqual('narrative-test-token');
      expect(request.cancellation === cancellation).assertTrue();
      expect(await rejected(repository.narrative('..', 'letter01'))).assertEqual('VALIDATION_ERROR');
      expect(transport.requests.length).assertEqual(3);
      transport.reply(200, letterJson.replace('letter01', 'letter02'));
      expect(await rejected(repository.narrative('assignment1', 'letter01'))).assertEqual('CONTRACT_ERROR');
    });

    it('preservesDenialAndTransientFailureAndAllowsExplicitRetry', 0, async () => {
      const transport: NarrativeTransport = new NarrativeTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      expect(await rejected(repository.narrative('assignment1', 'letter01'))).assertEqual('UNAUTHORIZED');
      expect(transport.requests.length).assertEqual(0);
      await login(repository, transport, 'narrative-test-token');
      transport.reply(404, '{"error":{"code":"NOT_FOUND","message":"内容尚未解锁"}}');
      expect(await rejected(repository.narrative('assignment1', 'letter01'))).assertEqual('NOT_FOUND');
      transport.reply(503, '{"error":{"code":"NETWORK_ERROR","message":"暂时无法连接"}}');
      expect(await rejected(repository.narrative('assignment1', 'letter01'))).assertEqual('NETWORK_ERROR');
      expect(transport.requests.length).assertEqual(4);
      transport.reply(200, letterJson);
      expect((await repository.narrative('assignment1', 'letter01')).id).assertEqual('letter01');
      expect(transport.requests.length).assertEqual(5);
      expect(transport.requests[4].url).assertEqual(transport.requests[3].url);
    });

    it('doesNotExposeAnOldAccountsReplyOrClearNewSessionOnCancelled401', 0, async () => {
      const transport: NarrativeTransport = new NarrativeTransport();
      const repository: HttpsGameRepository = new HttpsGameRepository('https://isolated.example', transport);
      await login(repository, transport, 'narrative-old-token');
      transport.defer();
      const old: Promise<NarrativeContent> = repository.narrative('assignment1', 'letter01');
      await login(repository, transport, 'narrative-new-token');
      transport.complete(200, letterJson);
      expect(await rejected(old)).assertEqual('CANCELLED');
      transport.defer();
      const cancellation: ReadCancellation = new ReadCancellation();
      const pending: Promise<NarrativeContent> = repository.narrative('assignment1', 'letter01', cancellation);
      cancellation.cancel();
      transport.complete(401, '{"error":{"code":"UNAUTHORIZED","message":"旧请求失败"}}');
      expect(await rejected(pending)).assertEqual('CANCELLED');
      transport.reply(200, letterJson);
      expect((await repository.narrative('assignment1', 'letter01')).id).assertEqual('letter01');
      expect(transport.requests[6].token).assertEqual('narrative-new-token');
    });
  });
}
