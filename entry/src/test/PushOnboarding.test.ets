import { describe, expect, it } from '@ohos/hypium';
import { PushOnboardingStore } from '../main/ets/business/PushOnboarding';
import { JourneyPushSubscription, PushSubscriptionCommand } from '../main/ets/business/PushSubscription';
import { ReadCancellation } from '../main/ets/business/ReadCancellation';
import { GameFailure } from '../main/ets/business/models';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { PushOnboardingViewModel } from '../main/ets/features/PushOnboardingViewModel';
import { PushSubscriptionsViewModel } from '../main/ets/features/PushSubscriptionsViewModel';

function choice(subscribed: boolean, pushEnabled: boolean, revision: number): JourneyPushSubscription {
  const result: JourneyPushSubscription = new JourneyPushSubscription();
  result.subscribed = subscribed;
  result.pushEnabled = pushEnabled;
  result.revision = revision;
  return result;
}

async function settle(): Promise<void> {
  await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 0); });
}

class OnboardingStore implements PushOnboardingStore {
  prompted: string[] = [];
  claims: string[] = [];
  failRead: boolean = false;
  failClaim: boolean = false;
  refuseClaim: boolean = false;
  onClaim: () => void = () => {};

  wasPrompted(owner: string): boolean {
    if (this.failRead) { throw new Error('合成的持久记录读取失败'); }
    return this.prompted.includes(owner);
  }

  claim(owner: string): boolean {
    this.claims.push(owner);
    this.onClaim();
    if (this.failClaim) { throw new Error('合成的持久记录写入失败'); }
    if (this.refuseClaim || this.prompted.includes(owner)) { return false; }
    this.prompted.push(owner);
    return true;
  }
}

class OnboardingRepository extends MockGameRepository {
  current: JourneyPushSubscription = choice(false, false, 0);
  reads: number = 0;
  writes: PushSubscriptionCommand[] = [];
  readError: GameFailure | null = null;
  writeError: GameFailure | null = null;
  receiptOverride: JourneyPushSubscription | null = null;
  failReadAfterWrite: boolean = false;
  holdRead: boolean = false;
  holdWrite: boolean = false;
  cancellations: ReadCancellation[] = [];
  deferredRead: ((value: JourneyPushSubscription) => void) | null = null;
  deferredWrite: ((value: JourneyPushSubscription) => void) | null = null;

  async journeyPushSubscription(cancellation?: ReadCancellation): Promise<JourneyPushSubscription> {
    this.reads++;
    if (cancellation !== undefined) { this.cancellations.push(cancellation); }
    if (this.readError !== null) { throw this.readError; }
    if (this.holdRead) {
      this.holdRead = false;
      return new Promise<JourneyPushSubscription>((resolve: (value: JourneyPushSubscription) => void) => {
        this.deferredRead = resolve;
      });
    }
    return this.current;
  }

  async updateJourneyPushSubscription(command: PushSubscriptionCommand): Promise<JourneyPushSubscription> {
    this.writes.push(command);
    if (this.writeError !== null) { throw this.writeError; }
    if (this.receiptOverride !== null) { return this.receiptOverride; }
    if (this.holdWrite) {
      this.holdWrite = false;
      return new Promise<JourneyPushSubscription>((resolve: (value: JourneyPushSubscription) => void) => {
        this.deferredWrite = resolve;
      });
    }
    this.current = choice(command.subscribed, command.pushEnabled, command.expectedRevision + 1);
    if (this.failReadAfterWrite) { this.readError = new GameFailure('NETWORK_ERROR', '合成的回源失败'); }
    return this.current;
  }
}

class OnboardingFixture {
  readonly repository: OnboardingRepository;
  readonly store: OnboardingStore;
  readonly source: PushSubscriptionsViewModel;
  readonly model: PushOnboardingViewModel;
  identities: number = 0;

  constructor(store: OnboardingStore = new OnboardingStore()) {
    this.repository = new OnboardingRepository();
    this.store = store;
    this.source = new PushSubscriptionsViewModel(this.repository, () => {}, () => `onboarding-${++this.identities}`);
    this.model = new PushOnboardingViewModel(this.source, this.store);
  }

  bind(owner: string): void {
    this.source.bindOwner(owner);
    this.model.bindOwner(owner);
  }

  async open(owner: string = 'first-owner'): Promise<void> {
    this.bind(owner);
    this.model.setEligible(true);
    await settle();
  }
}

export default function pushOnboardingTests(): void {
  describe('PushOnboarding', () => {
    it('doesNotOfferOrWriteBeforeAnEligibleAuthenticatedOwnerExists', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      fixture.model.setEligible(true);
      await settle();
      expect(fixture.model.phase).assertEqual('hidden');
      expect(fixture.repository.reads).assertEqual(0);
      fixture.model.setEligible(false);
      fixture.bind('first-owner');
      await settle();
      expect(fixture.model.phase).assertEqual('hidden');
      expect(fixture.repository.writes.length).assertEqual(0);
      expect(await fixture.model.acceptSubscription()).assertFalse();
      expect(await fixture.model.confirmNotifications()).assertFalse();
    });

    it('claimsDurablyBeforeOfferingAndNeverTreatsTheOfferAsConsent', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      let phaseAtClaim: string = '';
      fixture.store.onClaim = () => { phaseAtClaim = fixture.model.phase; };
      await fixture.open();
      expect(phaseAtClaim).assertEqual('hidden');
      expect(fixture.store.prompted.includes('first-owner')).assertTrue();
      expect(fixture.store.claims.length).assertEqual(1);
      expect(fixture.model.phase).assertEqual('subscription');
      expect(fixture.model.checking).assertFalse();
      expect(fixture.source.subscription?.subscribed).assertFalse();
      expect(fixture.source.subscription?.pushEnabled).assertFalse();
      expect(fixture.repository.writes.length).assertEqual(0);
      fixture.model.setEligible(false);
    });

    it('requiresTwoExplicitCommandsAndCurrentAuthorityBeforeTheNotificationEvent', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      await fixture.open();
      expect(await fixture.model.confirmNotifications()).assertFalse();
      expect(await fixture.model.acceptSubscription()).assertTrue();
      expect(fixture.repository.writes.length).assertEqual(1);
      expect(fixture.repository.writes[0].subscribed).assertTrue();
      expect(fixture.repository.writes[0].pushEnabled).assertFalse();
      expect(fixture.repository.writes[0].expectedRevision).assertEqual(0);
      expect(fixture.repository.reads).assertEqual(2);
      expect(fixture.model.phase).assertEqual('notifications');
      expect(fixture.model.notificationConsentRevision).assertEqual(0);
      expect(await fixture.model.confirmNotifications()).assertTrue();
      expect(fixture.repository.writes.length).assertEqual(2);
      expect(fixture.repository.writes[1].subscribed).assertTrue();
      expect(fixture.repository.writes[1].pushEnabled).assertTrue();
      expect(fixture.repository.writes[1].expectedRevision).assertEqual(1);
      expect(fixture.repository.reads).assertEqual(3);
      expect(fixture.model.phase).assertEqual('hidden');
      expect(fixture.model.notificationConsentRevision).assertEqual(1);
      expect(await fixture.model.confirmNotifications()).assertFalse();
      expect(fixture.model.notificationConsentRevision).assertEqual(1);
      fixture.model.setEligible(false);
    });

    it('dismissalWritesNoConsentAndDoesNotReofferOnReentryOrANewController', 0, async () => {
      const store: OnboardingStore = new OnboardingStore();
      const fixture: OnboardingFixture = new OnboardingFixture(store);
      await fixture.open();
      fixture.model.dismiss();
      expect(fixture.model.phase).assertEqual('hidden');
      expect(fixture.repository.writes.length).assertEqual(0);
      fixture.model.setEligible(false);
      fixture.model.setEligible(true);
      await settle();
      expect(fixture.model.phase).assertEqual('hidden');
      fixture.model.setEligible(false);
      const recreated: OnboardingFixture = new OnboardingFixture(store);
      await recreated.open();
      expect(recreated.model.phase).assertEqual('hidden');
      expect(recreated.repository.writes.length).assertEqual(0);
      expect(store.claims.length).assertEqual(1);
      recreated.model.setEligible(false);
    });

    it('closingTheNotificationStepKeepsSubscriptionWithoutEnablingPush', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      await fixture.open();
      await fixture.model.acceptSubscription();
      fixture.model.dismiss();
      expect(fixture.model.phase).assertEqual('hidden');
      expect(fixture.source.subscription?.subscribed).assertTrue();
      expect(fixture.source.subscription?.pushEnabled).assertFalse();
      expect(fixture.repository.writes.length).assertEqual(1);
      expect(fixture.model.notificationConsentRevision).assertEqual(0);
      expect(await fixture.model.confirmNotifications()).assertFalse();
      fixture.model.setEligible(false);
      fixture.model.setEligible(true);
      await settle();
      expect(fixture.model.phase).assertEqual('hidden');
      fixture.model.setEligible(false);
    });

    it('persistsPromptHistoryPerOwnerWithoutSuppressingAnotherOwner', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      await fixture.open('first-owner');
      fixture.model.dismiss();
      fixture.model.setEligible(false);
      await fixture.open('second-owner');
      expect(fixture.model.phase).assertEqual('subscription');
      expect(fixture.store.prompted.includes('first-owner')).assertTrue();
      expect(fixture.store.prompted.includes('second-owner')).assertTrue();
      expect(fixture.store.claims.length).assertEqual(2);
      fixture.model.setEligible(false);
      await fixture.open('first-owner');
      expect(fixture.model.phase).assertEqual('hidden');
      expect(fixture.repository.writes.length).assertEqual(0);
      fixture.model.setEligible(false);
    });

    it('skipsEveryExistingServerDecisionIncludingExplicitRefusal', 0, async () => {
      const existing: JourneyPushSubscription[] = [choice(false, false, 1), choice(true, false, 2), choice(true, true, 3)];
      for (const current of existing) {
        const fixture: OnboardingFixture = new OnboardingFixture();
        fixture.repository.current = current;
        await fixture.open();
        expect(fixture.model.phase).assertEqual('hidden');
        expect(fixture.repository.writes.length).assertEqual(0);
        expect(fixture.store.claims.length).assertEqual(0);
        fixture.model.setEligible(false);
      }
    });

    it('doesNotConvertAReadFailureIntoDefaultOffOrConsumeThePrompt', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      fixture.repository.readError = new GameFailure('NETWORK_ERROR', '合成的读取失败');
      await fixture.open();
      expect(fixture.model.phase).assertEqual('hidden');
      expect(fixture.source.subscription).assertNull();
      expect(fixture.source.loaded).assertFalse();
      expect(fixture.store.claims.length).assertEqual(0);
      expect(await fixture.model.acceptSubscription()).assertFalse();
      expect(fixture.repository.writes.length).assertEqual(0);
      fixture.model.setEligible(false);
    });

    it('failsClosedWhenPromptHistoryCannotBeRead', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      fixture.store.failRead = true;
      await fixture.open();
      expect(fixture.model.phase).assertEqual('hidden');
      expect(fixture.model.error).assertEqual('');
      expect(fixture.store.claims.length).assertEqual(0);
      expect(fixture.repository.writes.length).assertEqual(0);
      fixture.model.setEligible(false);
    });

    it('failsClosedWhenDurableClaimThrowsOrIsRefused', 0, async () => {
      for (const throws of [true, false]) {
        const fixture: OnboardingFixture = new OnboardingFixture();
        fixture.store.failClaim = throws;
        fixture.store.refuseClaim = !throws;
        await fixture.open();
        expect(fixture.model.phase).assertEqual('hidden');
        expect(fixture.model.error).assertEqual('');
        expect(fixture.store.prompted.length).assertEqual(0);
        expect(fixture.repository.writes.length).assertEqual(0);
        fixture.model.setEligible(false);
      }
    });

    it('cancelsBackgroundAuthorityReadsAndIgnoresTheirLateSuccess', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      fixture.repository.holdRead = true;
      fixture.bind('first-owner');
      fixture.model.setEligible(true);
      await settle();
      expect(fixture.model.checking).assertTrue();
      fixture.model.setEligible(false);
      expect(fixture.repository.cancellations[0].cancelled).assertTrue();
      fixture.repository.deferredRead?.(choice(false, false, 0));
      await settle();
      expect(fixture.model.phase).assertEqual('hidden');
      expect(fixture.store.claims.length).assertEqual(0);
      expect(fixture.model.checking).assertFalse();
    });

    it('oldOwnerReadCannotClaimOrReplaceTheNewOwnersOffer', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      fixture.repository.holdRead = true;
      fixture.bind('first-owner');
      fixture.model.setEligible(true);
      await settle();
      const oldRead: ((value: JourneyPushSubscription) => void) | null = fixture.repository.deferredRead;
      fixture.model.setEligible(false);
      await fixture.open('second-owner');
      expect(fixture.model.phase).assertEqual('subscription');
      oldRead?.(choice(true, true, 8));
      await settle();
      expect(fixture.model.phase).assertEqual('subscription');
      expect(fixture.store.prompted.includes('first-owner')).assertFalse();
      expect(fixture.store.prompted.includes('second-owner')).assertTrue();
      expect(fixture.source.subscription?.revision).assertEqual(0);
      fixture.model.setEligible(false);
    });

    it('oldActivationReadCannotOpenAnOfferAfterReactivation', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      fixture.repository.holdRead = true;
      fixture.bind('first-owner');
      fixture.model.setEligible(true);
      await settle();
      const oldRead: ((value: JourneyPushSubscription) => void) | null = fixture.repository.deferredRead;
      fixture.model.setEligible(false);
      fixture.repository.current = choice(false, false, 4);
      fixture.model.setEligible(true);
      await settle();
      oldRead?.(choice(false, false, 0));
      await settle();
      expect(fixture.model.phase).assertEqual('hidden');
      expect(fixture.store.claims.length).assertEqual(0);
      expect(fixture.source.subscription?.revision).assertEqual(4);
      fixture.model.setEligible(false);
    });

    it('uncertainSubscriptionWriteRequiresExplicitRetryOfTheSameCommand', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      await fixture.open();
      fixture.repository.writeError = new GameFailure('NETWORK_ERROR', '合成的响应丢失');
      expect(await fixture.model.acceptSubscription()).assertFalse();
      await settle();
      expect(fixture.repository.writes.length).assertEqual(1);
      expect(fixture.source.pending).assertTrue();
      expect(fixture.model.retryAvailable).assertTrue();
      expect(fixture.model.phase).assertEqual('subscription');
      expect(await fixture.model.acceptSubscription()).assertFalse();
      expect(await fixture.model.confirmNotifications()).assertFalse();
      expect(fixture.repository.writes.length).assertEqual(1);
      fixture.repository.writeError = null;
      expect(await fixture.model.retry()).assertTrue();
      expect(fixture.repository.writes.length).assertEqual(2);
      expect(fixture.repository.writes[0] === fixture.repository.writes[1]).assertTrue();
      expect(fixture.identities).assertEqual(1);
      expect(fixture.model.phase).assertEqual('notifications');
      expect(fixture.model.notificationConsentRevision).assertEqual(0);
      fixture.model.setEligible(false);
    });

    it('busyActionsCannotIssueConcurrentConsentCommands', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      await fixture.open();
      fixture.repository.holdWrite = true;
      const saving: Promise<boolean> = fixture.model.acceptSubscription();
      expect(fixture.model.busy).assertTrue();
      expect(await fixture.model.acceptSubscription()).assertFalse();
      expect(await fixture.model.confirmNotifications()).assertFalse();
      expect(await fixture.model.retry()).assertFalse();
      expect(fixture.repository.writes.length).assertEqual(1);
      fixture.repository.current = choice(true, false, 1);
      fixture.repository.deferredWrite?.(fixture.repository.current);
      expect(await saving).assertTrue();
      expect(fixture.model.busy).assertFalse();
      expect(fixture.model.phase).assertEqual('notifications');
      fixture.model.setEligible(false);
    });

    it('aDefiniteRejectionReturnsToExplicitConsentAfterAuthorityIsReloaded', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      await fixture.open();
      fixture.repository.writeError = new GameFailure('PUSH_REJECTED', '合成的明确拒绝', 400);
      expect(await fixture.model.acceptSubscription()).assertFalse();
      await settle();
      if (fixture.model.retryAvailable) { await fixture.model.retry(); }
      expect(fixture.model.phase).assertEqual('subscription');
      expect(fixture.model.retryAvailable).assertFalse();
      expect(fixture.model.error.length > 0).assertTrue();
      expect(fixture.repository.writes.length).assertEqual(1);
      fixture.repository.writeError = null;
      expect(await fixture.model.acceptSubscription()).assertTrue();
      expect(fixture.repository.writes.length).assertEqual(2);
      expect(fixture.identities).assertEqual(2);
      expect(fixture.repository.writes[0] === fixture.repository.writes[1]).assertFalse();
      expect(fixture.model.phase).assertEqual('notifications');
      fixture.model.setEligible(false);
    });

    it('aConflictingCancellationClosesInsteadOfOverwritingTheLatestChoice', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      await fixture.open();
      await fixture.model.acceptSubscription();
      fixture.repository.current = choice(false, false, 8);
      fixture.repository.writeError = new GameFailure('PUSH_JOURNEY_SUBSCRIPTION_CONFLICT', '合成的其他设备已取消', 409);
      expect(await fixture.model.confirmNotifications()).assertFalse();
      await settle();
      if (fixture.model.retryAvailable) { await fixture.model.retry(); }
      expect(fixture.model.phase).assertEqual('hidden');
      expect(fixture.model.notificationConsentRevision).assertEqual(0);
      expect(fixture.source.subscription?.revision).assertEqual(8);
      expect(fixture.source.subscription?.subscribed).assertFalse();
      expect(fixture.repository.writes.length).assertEqual(2);
      expect(await fixture.model.confirmNotifications()).assertFalse();
      fixture.model.setEligible(false);
    });

    it('savedSubscriptionWaitsForManualAuthorityReloadWithoutRepeatingTheWrite', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      await fixture.open();
      fixture.repository.failReadAfterWrite = true;
      await fixture.model.acceptSubscription();
      expect(fixture.source.subscription).assertNull();
      expect(fixture.source.needsSync).assertTrue();
      expect(fixture.model.phase).assertEqual('subscription');
      expect(fixture.model.retryAvailable).assertTrue();
      expect(await fixture.model.confirmNotifications()).assertFalse();
      expect(fixture.model.notificationConsentRevision).assertEqual(0);
      fixture.repository.failReadAfterWrite = false;
      fixture.repository.readError = null;
      expect(await fixture.model.retry()).assertTrue();
      expect(fixture.repository.writes.length).assertEqual(1);
      expect(fixture.model.phase).assertEqual('notifications');
      fixture.model.setEligible(false);
    });

    it('aHistoricalSubscribeReceiptCannotOverrideTheLatestServerDecision', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      await fixture.open();
      fixture.repository.receiptOverride = choice(true, false, 1);
      fixture.repository.current = choice(false, false, 7);
      await fixture.model.acceptSubscription();
      expect(fixture.source.subscription?.revision).assertEqual(7);
      expect(fixture.source.subscription?.subscribed).assertFalse();
      expect(fixture.model.phase).assertEqual('hidden');
      expect(fixture.model.notificationConsentRevision).assertEqual(0);
      expect(fixture.repository.writes.length).assertEqual(1);
      fixture.model.setEligible(false);
    });

    it('failedNotificationConfirmationEmitsNothingAndRetriesTheFrozenCommand', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      await fixture.open();
      await fixture.model.acceptSubscription();
      fixture.repository.writeError = new GameFailure('NETWORK_ERROR', '合成的通知确认失败');
      expect(await fixture.model.confirmNotifications()).assertFalse();
      await settle();
      expect(fixture.model.notificationConsentRevision).assertEqual(0);
      expect(fixture.model.phase).assertEqual('notifications');
      expect(fixture.model.retryAvailable).assertTrue();
      expect(fixture.repository.writes.length).assertEqual(2);
      fixture.repository.writeError = null;
      expect(await fixture.model.retry()).assertTrue();
      expect(fixture.repository.writes[1] === fixture.repository.writes[2]).assertTrue();
      expect(fixture.repository.writes[2].subscribed).assertTrue();
      expect(fixture.repository.writes[2].pushEnabled).assertTrue();
      expect(fixture.model.notificationConsentRevision).assertEqual(1);
      expect(fixture.model.phase).assertEqual('hidden');
      fixture.model.setEligible(false);
    });

    it('notificationWriteWithoutCurrentAuthorityDoesNotEmitUntilManualReload', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      await fixture.open();
      await fixture.model.acceptSubscription();
      fixture.repository.failReadAfterWrite = true;
      await fixture.model.confirmNotifications();
      expect(fixture.model.notificationConsentRevision).assertEqual(0);
      expect(fixture.source.needsSync).assertTrue();
      expect(fixture.model.retryAvailable).assertTrue();
      fixture.repository.failReadAfterWrite = false;
      fixture.repository.readError = null;
      expect(await fixture.model.retry()).assertTrue();
      expect(fixture.repository.writes.length).assertEqual(2);
      expect(fixture.model.notificationConsentRevision).assertEqual(1);
      expect(fixture.model.phase).assertEqual('hidden');
      expect(await fixture.model.retry()).assertFalse();
      expect(fixture.model.notificationConsentRevision).assertEqual(1);
      fixture.model.setEligible(false);
    });

    it('backgroundWriteCompletionCannotOpenNotificationsOrEmitConsent', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      await fixture.open();
      fixture.repository.holdWrite = true;
      const saving: Promise<boolean> = fixture.model.acceptSubscription();
      fixture.model.setEligible(false);
      fixture.repository.current = choice(true, false, 1);
      fixture.repository.deferredWrite?.(fixture.repository.current);
      await saving;
      expect(fixture.model.phase).assertEqual('hidden');
      expect(fixture.model.notificationConsentRevision).assertEqual(0);
      fixture.model.setEligible(true);
      await settle();
      expect(fixture.model.phase).assertEqual('hidden');
      expect(fixture.repository.writes.length).assertEqual(1);
      fixture.model.setEligible(false);
    });

    it('oldOwnerNotificationCompletionCannotEmitIntoAnotherAccount', 0, async () => {
      const fixture: OnboardingFixture = new OnboardingFixture();
      await fixture.open('first-owner');
      await fixture.model.acceptSubscription();
      fixture.repository.holdWrite = true;
      const saving: Promise<boolean> = fixture.model.confirmNotifications();
      fixture.model.setEligible(false);
      fixture.repository.current = choice(false, false, 0);
      await fixture.open('second-owner');
      fixture.repository.deferredWrite?.(choice(true, true, 2));
      expect(await saving).assertFalse();
      expect(fixture.model.notificationConsentRevision).assertEqual(0);
      expect(fixture.model.phase).assertEqual('subscription');
      expect(fixture.source.subscription?.subscribed).assertFalse();
      expect(fixture.source.subscription?.pushEnabled).assertFalse();
      fixture.model.setEligible(false);
    });
  });
}
