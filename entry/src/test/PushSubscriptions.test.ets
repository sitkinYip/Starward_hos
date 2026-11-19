import { describe, expect, it } from '@ohos/hypium';
import { AssignmentSummary, GameFailure } from '../main/ets/business/models';
import { PushSubscription, PushSubscriptionCommand, PushSubscriptionItem,
  PushSubscriptionList } from '../main/ets/business/PushSubscription';
import { ReadCancellation } from '../main/ets/business/ReadCancellation';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { HttpsGameRepository } from '../main/ets/data/HttpsGameRepository';
import { decodePushSubscription, decodePushSubscriptions } from '../main/ets/data/PushSubscriptionDecoder';
import { PushSubscriptionsViewModel } from '../main/ets/features/PushSubscriptionsViewModel';
import { HttpTransport, TransportRequest, TransportResponse } from '../main/ets/platform/HttpTransport';
import { ProductionTransport } from '../main/ets/platform/ProductionTransport';
import { PRODUCTION_API_ORIGIN } from '../main/ets/platform/AppEnvironment';
import { PLAYER_JSON } from './Contract.test';

function scene(id: string): AssignmentSummary {
  const result: AssignmentSummary = new AssignmentSummary();
  result.id = id;
  result.title = `场次 ${id}`;
  return result;
}

function saved(id: string, subscribed: boolean, pushEnabled: boolean, revision: number): PushSubscriptionItem {
  const result: PushSubscriptionItem = new PushSubscriptionItem();
  result.assignmentId = id;
  result.title = `场次 ${id}`;
  result.subscribed = subscribed;
  result.pushEnabled = pushEnabled;
  result.revision = revision;
  return result;
}

async function turn(): Promise<void> {
  await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 0); });
}

class SubscriptionRepository extends MockGameRepository {
  summaries: AssignmentSummary[] = [scene('one'), scene('two')];
  list: PushSubscriptionList = new PushSubscriptionList();
  reads: number = 0;
  readError: GameFailure | null = null;
  writeError: GameFailure | null = null;
  writes: PushSubscriptionCommand[] = [];
  writeIds: string[] = [];
  deferredWrite: ((value: PushSubscription) => void) | null = null;
  holdWrite: boolean = false;
  lastCancellation: ReadCancellation | undefined;
  deferredList: ((value: PushSubscriptionList) => void) | null = null;
  holdRead: boolean = false;
  historicalReceipt: PushSubscription | null = null;

  async assignments(): Promise<AssignmentSummary[]> { return this.summaries; }

  async pushSubscriptions(cancellation?: ReadCancellation): Promise<PushSubscriptionList> {
    this.reads++;
    this.lastCancellation = cancellation;
    if (this.readError !== null) { throw this.readError; }
    if (this.holdRead) {
      this.holdRead = false;
      return new Promise<PushSubscriptionList>((resolve) => { this.deferredList = resolve; });
    }
    return this.list;
  }

  async updatePushSubscription(id: string, command: PushSubscriptionCommand): Promise<PushSubscription> {
    this.writeIds.push(id);
    this.writes.push(command);
    if (this.historicalReceipt !== null) { return this.historicalReceipt; }
    if (this.writeError !== null) { throw this.writeError; }
    if (this.holdWrite) {
      this.holdWrite = false;
      return new Promise<PushSubscription>((resolve) => { this.deferredWrite = resolve; });
    }
    const result: PushSubscriptionItem = saved(id, command.subscribed, command.pushEnabled, command.expectedRevision + 1);
    this.list.items = this.list.items.filter((item: PushSubscriptionItem) => item.assignmentId !== id).concat([result]);
    return result;
  }
}

class SubscriptionTransport implements HttpTransport {
  requests: TransportRequest[] = [];
  bodies: string[] = [];
  async send(request: TransportRequest): Promise<TransportResponse> {
    this.requests.push(request);
    const response: TransportResponse = new TransportResponse();
    response.status = 200;
    response.body = this.bodies.shift() ?? '{}';
    return response;
  }
}

export default function pushSubscriptionsTests(): void {
  describe('PushSubscriptions', () => {
    it('joinsDefaultOffOnlyAfterBothServerReadsAndConfirmsConsentSeparately', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => 'request');
      model.bindOwner('owner');
      model.setActive(true);
      await turn();
      expect(model.loaded).assertTrue();
      expect(model.items.length).assertEqual(2);
      expect(model.item('one')?.pushEnabled).assertFalse();
      expect(await model.subscribe('one')).assertTrue();
      expect(repository.writes.length).assertEqual(1);
      expect(repository.writes[0].subscribed).assertTrue();
      expect(repository.writes[0].pushEnabled).assertFalse();
      expect(model.confirmationId).assertEqual('one');
      expect(await model.confirmNotifications('one')).assertTrue();
      expect(repository.writes[1].pushEnabled).assertTrue();
      expect(repository.writes[1].expectedRevision).assertEqual(1);
      expect(model.item('one')?.pushEnabled).assertTrue();
      expect(await model.unsubscribe('one')).assertTrue();
      expect(model.item('one')?.subscribed).assertFalse();
      expect(model.item('one')?.pushEnabled).assertFalse();
      expect(model.item('two')?.revision).assertEqual(0);
      model.setActive(false);
    });

    it('decliningOrClosingDoesNotAuthorizePushAndCanBeEnabledLater', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => 'request');
      model.bindOwner('owner');
      model.setActive(true);
      await turn();
      await model.subscribe('one');
      model.dismissConfirmation();
      expect(await model.confirmNotifications('one')).assertFalse();
      expect(repository.writes.length).assertEqual(1);
      expect(model.item('one')?.subscribed).assertTrue();
      expect(model.item('one')?.pushEnabled).assertFalse();
      model.requestNotifications('one');
      expect(model.confirmationId).assertEqual('one');
      model.setActive(false);
      expect(model.confirmationId).assertEqual('');
      expect(repository.writes.length).assertEqual(1);
    });

    it('keepsTheSameCommandForUncertainWriteAndBlocksCompetingChanges', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      let identities: number = 0;
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => `write-${++identities}`);
      model.bindOwner('owner');
      await model.refresh();
      repository.writeError = new GameFailure('NETWORK_ERROR', '连接中断');
      expect(await model.subscribe('one')).assertFalse();
      expect(model.item('one')?.subscribed).assertFalse();
      expect(model.pendingId).assertEqual('one');
      expect(await model.subscribe('two')).assertFalse();
      repository.writeError = null;
      expect(await model.retry()).assertTrue();
      expect(identities).assertEqual(1);
      expect(repository.writes.length).assertEqual(2);
      expect(repository.writes[0] === repository.writes[1]).assertTrue();
      expect(model.item('one')?.subscribed).assertTrue();
      expect(model.item('one')?.pushEnabled).assertFalse();
      expect(model.pendingId).assertEqual('');
    });

    it('failedListDoesNotInventDefaultSubscriptionsAndConflictReloadsAuthority', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      repository.readError = new GameFailure('NETWORK_ERROR', '读取失败');
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => 'request');
      model.bindOwner('owner');
      await model.refresh();
      expect(model.loaded).assertFalse();
      expect(model.items.length).assertEqual(0);
      expect(await model.subscribe('one')).assertFalse();
      repository.readError = null;
      await model.refresh();
      repository.list.items = [saved('one', true, true, 4)];
      repository.writeError = new GameFailure('PUSH_SUBSCRIPTION_CONFLICT', '订阅已更新', 409);
      expect(await model.subscribe('one')).assertFalse();
      await turn();
      expect(model.pendingId).assertEqual('');
      expect(model.item('one')?.revision).assertEqual(4);
      expect(model.item('one')?.pushEnabled).assertTrue();
      expect(repository.writes.length).assertEqual(1);
    });

    it('ignoresOldOwnerReceiptsAndCancelsBackgroundReads', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => 'request');
      model.bindOwner('first');
      await model.refresh();
      repository.holdWrite = true;
      const write: Promise<boolean> = model.subscribe('one');
      model.bindOwner('second');
      repository.deferredWrite?.(saved('one', true, false, 1));
      expect(await write).assertFalse();
      expect(model.items.length).assertEqual(0);
      expect(model.confirmationId).assertEqual('');
      repository.holdRead = true;
      model.setActive(true);
      await turn();
      model.setActive(false);
      expect(repository.lastCancellation?.cancelled).assertTrue();
      repository.deferredList?.(repository.list);
      await turn();
      expect(model.loaded).assertFalse();
      expect(model.items.length).assertEqual(0);
    });

    it('sessionFailureIsForwardedAndNoNewConsentCanSurviveSignOut', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      let rejected: boolean = false;
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository,
        () => { rejected = true; model.bindOwner(''); }, () => 'request');
      model.bindOwner('owner');
      await model.refresh();
      repository.writeError = new GameFailure('AUTH_REQUIRED', '请登录', 401);
      expect(await model.subscribe('one')).assertFalse();
      expect(rejected).assertTrue();
      expect(model.pendingId).assertEqual('');
      expect(model.items.length).assertEqual(0);
      expect(await model.retry()).assertFalse();
    });

    it('preservesHistoricalCancellationAndKeepsAnOfflineSceneErrorLocal', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      repository.list.items = [saved('historical', true, true, 3)];
      let rejected: boolean = false;
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository,
        () => { rejected = true; }, () => 'request');
      model.bindOwner('owner');
      await model.refresh();
      expect(model.item('historical')?.available).assertFalse();
      expect(await model.subscribe('historical')).assertFalse();
      expect(await model.unsubscribe('historical')).assertTrue();
      expect(model.item('historical')).assertNull();
      repository.writeError = new GameFailure('SESSION_OFFLINE', '场次已下线', 403);
      expect(await model.subscribe('one')).assertFalse();
      expect(rejected).assertFalse();
      expect(model.writeError).assertEqual('场次已下线');
      expect(model.pendingId).assertEqual('');
    });

    it('neverRestoresAnOldReceiptAfterAnotherDeviceCancelledAndRequiresFreshAuthority', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => 'original');
      model.bindOwner('owner');
      model.setActive(true);
      await turn();
      repository.writeError = new GameFailure('NETWORK_ERROR', '响应丢失');
      expect(await model.subscribe('one')).assertFalse();
      repository.writeError = null;
      repository.list.items = [saved('one', false, false, 3)];
      repository.historicalReceipt = saved('one', true, false, 1);
      expect(await model.retry()).assertTrue();
      expect(model.item('one')?.revision).assertEqual(3);
      expect(model.item('one')?.subscribed).assertFalse();
      expect(model.confirmationId).assertEqual('');
      expect(repository.writes[0] === repository.writes[1]).assertTrue();
      repository.historicalReceipt = null;
      repository.readError = new GameFailure('NETWORK_ERROR', '回源中断');
      expect(await model.subscribe('two')).assertTrue();
      expect(model.items.length).assertEqual(0);
      expect(model.loaded).assertFalse();
      expect(model.needsSync).assertTrue();
      expect(model.confirmationId).assertEqual('');
      expect(await model.subscribe('one')).assertFalse();
      repository.readError = null;
      await model.refresh();
      expect(model.needsSync).assertFalse();
      expect(model.item('two')?.subscribed).assertTrue();
      expect(model.item('two')?.pushEnabled).assertFalse();
      expect(model.confirmationId).assertEqual('two');
      model.setActive(false);
    });

    it('strictlyDecodesIdentityBooleansRevisionsAndDuplicateRows', 0, () => {
      const body: string = '{"assignmentId":"one","subscribed":true,"pushEnabled":false,"revision":1}';
      expect(decodePushSubscription(body, 'one').subscribed).assertTrue();
      let failures: number = 0;
      const invalid: string[] = [body.replace('"one"', '"other"'), body.replace('"revision":1', '"revision":-1'),
        body.replace('"subscribed":true', '"subscribed":false').replace('"pushEnabled":false', '"pushEnabled":true'),
        body.replace('"revision":1', '"revision":"1"')];
      invalid.forEach((value: string) => { try { decodePushSubscription(value, 'one'); } catch { failures++; } });
      expect(failures).assertEqual(4);
      const row: string = body.replace('"revision":1', '"revision":1,"title":"测试场次"');
      let duplicateRejected: boolean = false;
      try { decodePushSubscriptions(`{"items":[${row},${row}],"subscriptionApproved":false}`); } catch {
        duplicateRejected = true;
      }
      expect(duplicateRejected).assertTrue();
      expect(decodePushSubscriptions('{"items":[],"subscriptionApproved":false}').items.length).assertEqual(0);
    });

    it('sendsAuthenticatedPutAndKeepsTheProductionReadOnlyBoundary', 0, async () => {
      const transport: SubscriptionTransport = new SubscriptionTransport();
      transport.bodies = ['{"token":"synthetic-token","record":{"id":"playeralice"}}', PLAYER_JSON,
        '{"items":[],"subscriptionApproved":false}',
        '{"assignmentId":"one","subscribed":true,"pushEnabled":false,"revision":1}'];
      const repository: HttpsGameRepository = new HttpsGameRepository('https://test.invalid', transport);
      await repository.login('synthetic', 'synthetic-password');
      await repository.pushSubscriptions();
      const command: PushSubscriptionCommand = new PushSubscriptionCommand('request', true, false, 0);
      await repository.updatePushSubscription('one', command);
      const request: TransportRequest = transport.requests[transport.requests.length - 1];
      expect(request.method).assertEqual('PUT');
      expect(request.token).assertEqual('synthetic-token');
      expect(request.url).assertEqual('https://test.invalid/api/questions/v1/assignments/one/push-subscription');
      expect(request.body).assertEqual(JSON.stringify(command));
      const production: SubscriptionTransport = new SubscriptionTransport();
      const write: TransportRequest = new TransportRequest();
      write.url = PRODUCTION_API_ORIGIN + '/api/questions/v1/assignments/one/push-subscription';
      write.method = 'PUT';
      write.body = JSON.stringify(command);
      let blocked: boolean = false;
      try { await new ProductionTransport(production, true).send(write); } catch (error) {
        blocked = error instanceof GameFailure && error.code === 'PRODUCTION_READ_ONLY';
      }
      expect(blocked).assertTrue();
      expect(production.requests.length).assertEqual(0);
      await new ProductionTransport(production, false).send(write);
      expect(production.requests.length).assertEqual(1);
      write.url = PRODUCTION_API_ORIGIN + '/api/questions/v1/assignments/one/other';
      let invalidPut: boolean = false;
      try { await new ProductionTransport(production, false).send(write); } catch { invalidPut = true; }
      expect(invalidPut).assertTrue();
    });
  });
}
