import { PushOnboardingPhase, PushOnboardingStore } from '../business/PushOnboarding';
import { JourneyPushSubscription } from '../business/PushSubscription';
import { PushSubscriptionsViewModel } from './PushSubscriptionsViewModel';

/** The host supplies the privacy, authentication, foreground and modal-availability gate. */
@ObservedV2
export class PushOnboardingViewModel {
  @Trace phase: PushOnboardingPhase = 'hidden';
  @Trace checking: boolean = false;
  @Trace busy: boolean = false;
  @Trace error: string = '';
  @Trace retryAvailable: boolean = false;
  @Trace subscriptionApproved: boolean = false;
  @Trace notificationConsentRevision: number = 0;
  private readonly subscriptions: PushSubscriptionsViewModel;
  private readonly store: PushOnboardingStore;
  private owner: string = '';
  private eligible: boolean = false;
  private epoch: number = 0;
  private actionAccepted: boolean = false;

  constructor(subscriptions: PushSubscriptionsViewModel, store: PushOnboardingStore) {
    this.subscriptions = subscriptions;
    this.store = store;
  }

  bindOwner(owner: string): void {
    if (owner === this.owner) { return; }
    this.dismiss();
    this.eligible = false;
    this.owner = owner;
    this.subscriptions.bindOwner(owner);
    this.subscriptionApproved = false;
  }

  setEligible(eligible: boolean): void {
    if (eligible === this.eligible) { return; }
    this.eligible = eligible;
    if (!eligible) { this.dismiss(); } else { void this.check(); }
  }

  private current(epoch: number): boolean {
    return epoch === this.epoch && this.eligible && this.owner.length > 0;
  }

  private async check(): Promise<void> {
    if (this.owner.length === 0 || !this.eligible) { return; }
    const epoch: number = ++this.epoch;
    try {
      if (this.store.wasPrompted(this.owner)) { return; }
      this.checking = true;
      this.subscriptions.setActive(true, false);
      await this.subscriptions.refresh();
      if (!this.current(epoch)) { return; }
      const current: JourneyPushSubscription | null = this.subscriptions.subscription;
      // A nonzero revision is an existing choice, including cancellation or declined notifications.
      if (this.subscriptions.error.length > 0 || !this.subscriptions.loaded || current === null ||
        current.revision !== 0 || current.subscribed || current.pushEnabled) { return; }
      if (!this.store.claim(this.owner) || !this.current(epoch)) { return; }
      this.subscriptionApproved = current.subscriptionApproved;
      this.phase = 'subscription';
    } catch {
      // Optional onboarding fails closed. Settings remains the explicit recovery path.
    } finally {
      if (epoch === this.epoch) {
        this.checking = false;
        if (this.phase === 'hidden') { this.subscriptions.setActive(false); }
      }
    }
  }

  dismiss(): void {
    this.epoch++;
    this.phase = 'hidden';
    this.checking = false;
    this.busy = false;
    this.error = '';
    this.retryAvailable = false;
    this.actionAccepted = false;
    this.subscriptions.dismissConfirmation();
    this.subscriptions.setActive(false);
  }

  private canAct(phase: PushOnboardingPhase): boolean {
    return this.eligible && this.owner.length > 0 && this.phase === phase && !this.busy &&
      !this.subscriptions.busy && !this.subscriptions.saving;
  }

  async acceptSubscription(): Promise<boolean> {
    if (!this.canAct('subscription') || this.retryAvailable) { return false; }
    return this.write('subscription');
  }

  async confirmNotifications(): Promise<boolean> {
    if (!this.canAct('notifications') || this.retryAvailable) { return false; }
    return this.write('notifications');
  }

  private async write(phase: PushOnboardingPhase): Promise<boolean> {
    const epoch: number = this.epoch;
    this.busy = true;
    this.error = '';
    let accepted: boolean = false;
    try {
      if (phase === 'subscription') {
        accepted = await this.subscriptions.subscribe();
      } else {
        this.subscriptions.requestNotifications();
        accepted = await this.subscriptions.confirmNotifications();
      }
      if (!this.current(epoch)) { return false; }
      this.actionAccepted = accepted;
      this.publish(phase);
      return accepted;
    } finally {
      if (epoch === this.epoch) { this.busy = false; }
    }
  }

  async retry(): Promise<boolean> {
    if (this.phase === 'hidden' || !this.canAct(this.phase) || !this.retryAvailable) { return false; }
    const epoch: number = this.epoch;
    const phase: PushOnboardingPhase = this.phase;
    this.busy = true;
    this.error = '';
    try {
      let accepted: boolean = this.actionAccepted;
      if (this.subscriptions.pending) {
        accepted = await this.subscriptions.retry();
      } else {
        await this.subscriptions.refresh();
      }
      if (!this.current(epoch)) { return false; }
      this.actionAccepted = accepted;
      this.publish(phase);
      return this.error.length === 0;
    } finally {
      if (epoch === this.epoch) { this.busy = false; }
    }
  }

  private publish(phase: PushOnboardingPhase): void {
    if (this.subscriptions.busy || this.subscriptions.pending || this.subscriptions.needsSync ||
      this.subscriptions.error.length > 0 ||
      !this.subscriptions.loaded || this.subscriptions.subscription === null) {
      this.error = this.subscriptions.writeError || this.subscriptions.error || '当前订阅状态尚未确认，请重试。';
      this.retryAvailable = true;
      return;
    }
    const current: JourneyPushSubscription = this.subscriptions.subscription;
    this.subscriptionApproved = current.subscriptionApproved;
    this.subscriptions.dismissConfirmation();
    this.error = '';
    this.retryAvailable = false;
    if (phase === 'subscription' && current.subscribed && !current.pushEnabled) {
      this.phase = 'notifications';
      this.actionAccepted = false;
    } else if (this.actionAccepted || current.pushEnabled || (!current.subscribed && current.revision > 0)) {
      if (phase === 'notifications' && this.actionAccepted && current.subscribed && current.pushEnabled) {
        this.notificationConsentRevision++;
      }
      this.dismiss();
    } else if (this.subscriptions.writeError.length > 0) {
      this.error = this.subscriptions.writeError;
      // A definite rejection has no frozen command. Another write needs a new, explicit consent action.
      this.retryAvailable = false;
    }
  }
}
