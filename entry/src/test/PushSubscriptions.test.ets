import { describe, expect, it } from '@ohos/hypium';
import { AssignmentSummary, GameFailure } from '../main/ets/business/models';
import { JourneyPushSubscription, PERSONAL_JOURNEY_SCOPE, PushSubscriptionCommand } from '../main/ets/business/PushSubscription';
import { ReadCancellation } from '../main/ets/business/ReadCancellation';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { HttpsGameRepository } from '../main/ets/data/HttpsGameRepository';
import { decodeJourneyPushSubscription } from '../main/ets/data/PushSubscriptionDecoder';
import { PushSubscriptionsViewModel } from '../main/ets/features/PushSubscriptionsViewModel';
import { HttpTransport, TransportRequest, TransportResponse } from '../main/ets/platform/HttpTransport';
import { ProductionTransport } from '../main/ets/platform/ProductionTransport';
import { PRODUCTION_API_ORIGIN } from '../main/ets/platform/AppEnvironment';
import { PLAYER_JSON } from './Contract.test';

function saved(subscribed: boolean, pushEnabled: boolean, revision: number): JourneyPushSubscription {
  const result: JourneyPushSubscription = new JourneyPushSubscription();
  result.subscribed = subscribed;
  result.pushEnabled = pushEnabled;
  result.revision = revision;
  return result;
}

async function turn(): Promise<void> {
  await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 0); });
}

class SubscriptionRepository extends MockGameRepository {
  current: JourneyPushSubscription = saved(false, false, 0);
  assignmentReads: number = 0;
  reads: number = 0;
  readError: GameFailure | null = null;
  writeError: GameFailure | null = null;
  writes: PushSubscriptionCommand[] = [];
  deferredWrite: ((value: JourneyPushSubscription) => void) | null = null;
  holdWrite: boolean = false;
  lastCancellation: ReadCancellation | undefined;
  deferredRead: ((value: JourneyPushSubscription) => void) | null = null;
  holdRead: boolean = false;
  historicalReceipt: JourneyPushSubscription | null = null;

  async assignments(): Promise<AssignmentSummary[]> {
    this.assignmentReads++;
    throw new GameFailure('LEGACY_SCOPE_MUST_NOT_BE_READ', '旧场次不决定账号订阅');
  }

  async journeyPushSubscription(cancellation?: ReadCancellation): Promise<JourneyPushSubscription> {
    this.reads++;
    this.lastCancellation = cancellation;
    if (this.readError !== null) { throw this.readError; }
    if (this.holdRead) {
      this.holdRead = false;
      return new Promise<JourneyPushSubscription>((resolve) => { this.deferredRead = resolve; });
    }
    return this.current;
  }

  async updateJourneyPushSubscription(command: PushSubscriptionCommand): Promise<JourneyPushSubscription> {
    this.writes.push(command);
    if (this.historicalReceipt !== null) { return this.historicalReceipt; }
    if (this.writeError !== null) { throw this.writeError; }
    if (this.holdWrite) {
      this.holdWrite = false;
      return new Promise<JourneyPushSubscription>((resolve) => { this.deferredWrite = resolve; });
    }
    this.current = saved(command.subscribed, command.pushEnabled, command.expectedRevision + 1);
    return this.current;
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
    it('usesOnlyExplicitAccountConsentAndConfirmsNotificationsSeparately', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => 'request');
      model.bindOwner('owner');
      model.setActive(true);
      await turn();
      expect(model.loaded).assertTrue();
      expect(model.subscription?.scope).assertEqual(PERSONAL_JOURNEY_SCOPE);
      expect(model.subscription?.subscriptionApproved).assertFalse();
      expect(model.subscription?.subscribed).assertFalse();
      expect(model.subscription?.pushEnabled).assertFalse();
      expect(repository.assignmentReads).assertEqual(0);
      expect(await model.subscribe()).assertTrue();
      expect(repository.writes.length).assertEqual(1);
      expect(repository.writes[0].scope).assertEqual(PERSONAL_JOURNEY_SCOPE);
      expect(repository.writes[0].subscribed).assertTrue();
      expect(repository.writes[0].pushEnabled).assertFalse();
      expect(model.confirmationRequested).assertTrue();
      expect(await model.confirmNotifications()).assertTrue();
      expect(repository.writes[1].pushEnabled).assertTrue();
      expect(repository.writes[1].expectedRevision).assertEqual(1);
      expect(model.subscription?.pushEnabled).assertTrue();
      expect(await model.unsubscribe()).assertTrue();
      expect(model.subscription?.subscribed).assertFalse();
      expect(model.subscription?.pushEnabled).assertFalse();
      expect(repository.reads).assertEqual(4);
      expect(repository.assignmentReads).assertEqual(0);
      model.setActive(false);
    });

    it('decliningOrClosingDoesNotAuthorizeAndRevisitDoesNotOpenConsentAgain', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => 'request');
      model.bindOwner('owner');
      model.setActive(true);
      await turn();
      await model.subscribe();
      model.dismissConfirmation();
      expect(await model.confirmNotifications()).assertFalse();
      expect(repository.writes.length).assertEqual(1);
      expect(model.subscription?.subscribed).assertTrue();
      expect(model.subscription?.pushEnabled).assertFalse();
      model.requestNotifications();
      expect(model.confirmationRequested).assertTrue();
      model.setActive(false);
      expect(model.confirmationRequested).assertFalse();
      model.setActive(true);
      await turn();
      expect(model.confirmationRequested).assertFalse();
      expect(repository.writes.length).assertEqual(1);
      model.setActive(false);
    });

    it('keepsTheSameScopedCommandForUncertainWriteAndBlocksCompetingChanges', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      let identities: number = 0;
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => `write-${++identities}`);
      model.bindOwner('owner');
      model.setActive(true);
      await turn();
      repository.writeError = new GameFailure('NETWORK_ERROR', '连接中断');
      expect(await model.subscribe()).assertFalse();
      expect(model.subscription?.subscribed).assertFalse();
      expect(model.pending).assertTrue();
      expect(await model.subscribe()).assertFalse();
      expect(await model.unsubscribe()).assertFalse();
      model.requestNotifications();
      expect(model.confirmationRequested).assertFalse();
      repository.writeError = null;
      expect(await model.retry()).assertTrue();
      expect(identities).assertEqual(1);
      expect(repository.writes.length).assertEqual(2);
      expect(repository.writes[0] === repository.writes[1]).assertTrue();
      expect(repository.writes[1].scope).assertEqual(PERSONAL_JOURNEY_SCOPE);
      expect(model.subscription?.subscribed).assertTrue();
      expect(model.subscription?.pushEnabled).assertFalse();
      expect(model.pending).assertFalse();
      model.setActive(false);
    });

    it('failedReadNeverInventsOffAndConflictReloadsTheCurrentAccountChoice', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      repository.readError = new GameFailure('NETWORK_ERROR', '读取失败');
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => 'request');
      model.bindOwner('owner');
      model.setActive(true);
      await turn();
      expect(model.loaded).assertFalse();
      expect(model.subscription).assertNull();
      expect(await model.subscribe()).assertFalse();
      repository.readError = null;
      await model.refresh();
      repository.current = saved(true, true, 4);
      repository.writeError = new GameFailure('PUSH_JOURNEY_SUBSCRIPTION_CONFLICT', '订阅已更新', 409);
      expect(await model.subscribe()).assertFalse();
      await turn();
      expect(model.pending).assertFalse();
      expect(model.subscription?.revision).assertEqual(4);
      expect(model.subscription?.pushEnabled).assertTrue();
      expect(model.confirmationRequested).assertFalse();
      expect(repository.writes.length).assertEqual(1);
      model.setActive(false);
    });

    it('ignoresOldOwnerReceiptsAndCancelsBackgroundReads', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => 'request');
      model.bindOwner('first');
      model.setActive(true);
      await turn();
      repository.holdWrite = true;
      const write: Promise<boolean> = model.subscribe();
      model.bindOwner('second');
      repository.deferredWrite?.(saved(true, false, 1));
      expect(await write).assertFalse();
      expect(model.subscription).assertNull();
      expect(model.confirmationRequested).assertFalse();
      repository.holdRead = true;
      model.setActive(true);
      await turn();
      model.setActive(false);
      expect(repository.lastCancellation?.cancelled).assertTrue();
      repository.deferredRead?.(repository.current);
      await turn();
      expect(model.loaded).assertFalse();
      expect(model.subscription).assertNull();
    });

    it('sessionFailureIsForwardedAndSignOutDiscardsThePendingCommand', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      let rejected: boolean = false;
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository,
        () => { rejected = true; model.bindOwner(''); }, () => 'request');
      model.bindOwner('owner');
      model.setActive(true);
      await turn();
      repository.writeError = new GameFailure('AUTH_REQUIRED', '请登录', 401);
      expect(await model.subscribe()).assertFalse();
      expect(rejected).assertTrue();
      expect(model.pending).assertFalse();
      expect(model.subscription).assertNull();
      expect(await model.retry()).assertFalse();
      expect(model.confirmationRequested).assertFalse();
    });

    it('staleReadFailureDisablesChangesUntilAuthorityIsReadAgain', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      repository.current = saved(true, true, 3);
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => 'request');
      model.bindOwner('owner');
      model.setActive(true);
      await turn();
      repository.readError = new GameFailure('NETWORK_ERROR', '同步失败');
      await model.refresh();
      expect(model.subscription?.pushEnabled).assertTrue();
      expect(await model.unsubscribe()).assertFalse();
      expect(repository.writes.length).assertEqual(0);
      repository.readError = null;
      repository.current = saved(false, false, 4);
      await model.refresh();
      expect(model.error).assertEqual('');
      expect(model.subscription?.revision).assertEqual(4);
      expect(model.subscription?.subscribed).assertFalse();
      model.setActive(false);
    });

    it('neverPublishesAnOldReceiptAndRecoversAfterTheAuthoritativeReadFails', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => 'original');
      model.bindOwner('owner');
      model.setActive(true);
      await turn();
      repository.writeError = new GameFailure('NETWORK_ERROR', '响应丢失');
      expect(await model.subscribe()).assertFalse();
      repository.writeError = null;
      repository.current = saved(false, false, 3);
      repository.historicalReceipt = saved(true, false, 1);
      expect(await model.retry()).assertTrue();
      expect(model.subscription?.revision).assertEqual(3);
      expect(model.subscription?.subscribed).assertFalse();
      expect(model.confirmationRequested).assertFalse();
      expect(repository.writes[0] === repository.writes[1]).assertTrue();
      repository.historicalReceipt = null;
      repository.readError = new GameFailure('NETWORK_ERROR', '回源中断');
      expect(await model.subscribe()).assertTrue();
      expect(model.subscription).assertNull();
      expect(model.loaded).assertFalse();
      expect(model.needsSync).assertTrue();
      expect(model.confirmationRequested).assertFalse();
      expect(await model.subscribe()).assertFalse();
      repository.readError = null;
      await model.refresh();
      expect(model.needsSync).assertFalse();
      expect(model.subscription?.subscribed).assertTrue();
      expect(model.subscription?.pushEnabled).assertFalse();
      expect(model.confirmationRequested).assertTrue();
      model.setActive(false);
    });

    it('allowsEqualRevisionReceiptsButStillRequiresCurrentServerState', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => 'request');
      model.bindOwner('owner');
      model.setActive(true);
      await turn();
      repository.historicalReceipt = saved(true, false, 0);
      repository.current = saved(false, false, 3);
      expect(await model.subscribe()).assertTrue();
      expect(model.pending).assertFalse();
      expect(model.subscription?.revision).assertEqual(3);
      expect(model.subscription?.subscribed).assertFalse();
      expect(model.confirmationRequested).assertFalse();
      model.setActive(false);
    });

    it('backgroundWriteCompletionCannotReopenConsentOnTheNextVisit', 0, async () => {
      const repository: SubscriptionRepository = new SubscriptionRepository();
      const model: PushSubscriptionsViewModel = new PushSubscriptionsViewModel(repository, () => {}, () => 'request');
      model.bindOwner('owner');
      model.setActive(true);
      await turn();
      repository.holdWrite = true;
      const write: Promise<boolean> = model.subscribe();
      model.setActive(false);
      repository.current = saved(true, false, 1);
      repository.deferredWrite?.(repository.current);
      expect(await write).assertTrue();
      expect(model.needsSync).assertTrue();
      expect(repository.reads).assertEqual(1);
      expect(model.subscription).assertNull();
      expect(await model.retry()).assertFalse();
      model.setActive(true);
      await turn();
      expect(model.needsSync).assertFalse();
      expect(model.subscription?.subscribed).assertTrue();
      expect(model.subscription?.pushEnabled).assertFalse();
      expect(model.confirmationRequested).assertFalse();
      await model.unsubscribe();
      repository.holdWrite = true;
      const resumedWrite: Promise<boolean> = model.subscribe();
      model.setActive(false);
      model.setActive(true);
      repository.current = saved(true, false, 3);
      repository.deferredWrite?.(repository.current);
      expect(await resumedWrite).assertTrue();
      expect(model.subscription?.subscribed).assertTrue();
      expect(model.confirmationRequested).assertFalse();
      model.setActive(false);
    });

    it('strictlyDecodesTheNewScopeAndRejectsFormerSceneConsent', 0, () => {
      const body: string = JSON.stringify(saved(true, false, 1));
      expect(decodeJourneyPushSubscription(body).subscribed).assertTrue();
      expect(decodeJourneyPushSubscription(body.replace('"subscriptionApproved":false',
        '"subscriptionApproved":true')).subscriptionApproved).assertTrue();
      let failures: number = 0;
      const invalid: string[] = [body.replace(PERSONAL_JOURNEY_SCOPE, 'other_scope'),
        body.replace('"revision":1', '"revision":-1'), body.replace('"revision":1', '"revision":1.5'),
        body.replace('"revision":1', '"revision":9007199254740992'), body.replace('"revision":1', '"revision":"1"'),
        body.replace('"subscribed":true', '"subscribed":false').replace('"pushEnabled":false', '"pushEnabled":true'),
        body.replace('"subscriptionApproved":false', '"subscriptionApproved":"false"'),
        '{"assignmentId":"former-scene","subscribed":true,"pushEnabled":true,"revision":3}',
        '{"items":[],"subscriptionApproved":false}', 'null', '[]', '{}'];
      invalid.forEach((value: string) => { try { decodeJourneyPushSubscription(value); } catch { failures++; } });
      expect(failures).assertEqual(invalid.length);
      expect(decodeJourneyPushSubscription(JSON.stringify(saved(false, false, 0))).pushEnabled).assertFalse();
    });

    it('usesOnlyTheAuthenticatedAccountRouteAndPreservesProductionReadOnly', 0, async () => {
      const transport: SubscriptionTransport = new SubscriptionTransport();
      transport.bodies = ['{"token":"synthetic-token","record":{"id":"playeralice"}}', PLAYER_JSON,
        JSON.stringify(saved(false, false, 0)), JSON.stringify(saved(true, false, 1))];
      const repository: HttpsGameRepository = new HttpsGameRepository('https://test.invalid', transport);
      await repository.login('synthetic', 'synthetic-password');
      await repository.journeyPushSubscription();
      const command: PushSubscriptionCommand = new PushSubscriptionCommand('request', true, false, 0);
      await repository.updateJourneyPushSubscription(command);
      const request: TransportRequest = transport.requests[transport.requests.length - 1];
      expect(request.method).assertEqual('PUT');
      expect(request.token).assertEqual('synthetic-token');
      expect(request.url).assertEqual('https://test.invalid/api/questions/v1/me/push/journey-subscription');
      expect(request.body).assertEqual(JSON.stringify(command));
      expect(transport.requests[transport.requests.length - 2].url).assertEqual(request.url);
      expect(JSON.parse(request.body)['scope']).assertEqual(PERSONAL_JOURNEY_SCOPE);
      const production: SubscriptionTransport = new SubscriptionTransport();
      const write: TransportRequest = new TransportRequest();
      write.url = PRODUCTION_API_ORIGIN + '/api/questions/v1/me/push/journey-subscription';
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
      write.url = PRODUCTION_API_ORIGIN + '/api/questions/v1/assignments/former-scene/push-subscription';
      let legacyBlocked: boolean = false;
      try { await new ProductionTransport(production, false).send(write); } catch { legacyBlocked = true; }
      expect(legacyBlocked).assertTrue();
    });
  });
}
