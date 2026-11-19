import { GameRepository } from '../business/GameRepository';
import { GameFailure } from '../business/models';
import { JourneyPushSubscription, PERSONAL_JOURNEY_SCOPE, PushSubscriptionCommand } from '../business/PushSubscription';
import { ReadCancellation } from '../business/ReadCancellation';
import { createRequestIdentity } from '../platform/RequestIdentity';

@ObservedV2
export class PushSubscriptionsViewModel {
  @Trace subscription: JourneyPushSubscription | null = null;
  @Trace loaded: boolean = false;
  @Trace busy: boolean = false;
  @Trace error: string = '';
  @Trace writeError: string = '';
  @Trace pending: boolean = false;
  @Trace saving: boolean = false;
  @Trace confirmationRequested: boolean = false;
  @Trace needsSync: boolean = false;
  private owner: string = '';
  private generation: number = 0;
  private activation: number = 0;
  private active: boolean = false;
  private read: ReadCancellation | null = null;
  private command: PushSubscriptionCommand | null = null;
  private confirmationAfterRead: boolean = false;
  private readonly repository: GameRepository;
  private readonly rejectSession: (error: Object) => void;
  private readonly identity: () => string;

  constructor(repository: GameRepository, rejectSession: (error: Object) => void,
    identity: () => string = createRequestIdentity) {
    this.repository = repository;
    this.rejectSession = rejectSession;
    this.identity = identity;
  }

  bindOwner(owner: string): void {
    if (owner === this.owner) { return; }
    this.owner = owner;
    this.generation++;
    this.cancelRead();
    this.subscription = null;
    this.loaded = false;
    this.error = '';
    this.writeError = '';
    this.command = null;
    this.pending = false;
    this.saving = false;
    this.confirmationRequested = false;
    this.confirmationAfterRead = false;
    this.needsSync = false;
    this.active = false;
  }

  setActive(active: boolean): void {
    if (active === this.active) { return; }
    this.active = active;
    this.activation++;
    if (!active) {
      this.cancelRead();
      this.confirmationRequested = false;
      this.confirmationAfterRead = false;
    } else if (this.owner.length > 0 && this.command === null) {
      void this.refresh();
    }
  }

  private cancelRead(): void {
    this.read?.cancel();
    this.read = null;
    this.busy = false;
  }

  private sessionFailure(error: Object): boolean {
    return error instanceof GameFailure && (error.status === 401 || error.code === 'PASSWORD_CHANGE_REQUIRED' ||
      error.code === 'ACCOUNT_DISABLED');
  }

  private message(error: Object): string {
    return error instanceof Error && error.message.length > 0 ? error.message : '暂时无法同步订阅，请重试。';
  }

  async refresh(): Promise<void> {
    if (this.owner.length === 0 || !this.active || this.busy || this.command !== null) { return; }
    if (this.repository.journeyPushSubscription === undefined) {
      this.error = '当前版本暂不支持旅途订阅。';
      return;
    }
    const generation: number = this.generation;
    const read: ReadCancellation = new ReadCancellation();
    this.read = read;
    this.busy = true;
    this.error = '';
    try {
      // The new account scope is authoritative. Former scene consent is never read or widened.
      const current: JourneyPushSubscription = await this.repository.journeyPushSubscription(read);
      if (generation !== this.generation || this.read !== read || read.cancelled) { return; }
      this.subscription = current;
      this.loaded = true;
      if (this.needsSync) { this.writeError = ''; }
      this.needsSync = false;
      if (this.confirmationAfterRead) {
        if (this.active && current.subscribed && !current.pushEnabled) { this.confirmationRequested = true; }
        this.confirmationAfterRead = false;
        this.writeError = '';
      }
    } catch (error) {
      if (generation === this.generation && this.read === read && !read.cancelled) {
        if (this.sessionFailure(error as Object)) { this.rejectSession(error as Object); return; }
        this.error = this.message(error as Object);
      }
    } finally {
      if (generation === this.generation && this.read === read) {
        this.read = null;
        this.busy = false;
      }
    }
  }

  dismissConfirmation(): void { this.confirmationRequested = false; }

  async subscribe(): Promise<boolean> {
    const current: JourneyPushSubscription | null = this.subscription;
    if (current === null || current.subscribed) { return false; }
    return this.begin(current, true, false);
  }

  requestNotifications(): void {
    if (this.active && !this.busy && !this.saving && !this.needsSync && this.error.length === 0 && this.command === null &&
      this.subscription?.subscribed && !this.subscription.pushEnabled) { this.confirmationRequested = true; }
  }

  async confirmNotifications(): Promise<boolean> {
    if (!this.confirmationRequested || !this.active || this.busy || this.saving || this.needsSync ||
      this.error.length > 0 || this.command !== null) { return false; }
    this.confirmationRequested = false;
    const current: JourneyPushSubscription | null = this.subscription;
    return current !== null && current.subscribed && !current.pushEnabled ? this.begin(current, true, true) : false;
  }

  async unsubscribe(): Promise<boolean> {
    const current: JourneyPushSubscription | null = this.subscription;
    if (current === null || !current.subscribed) { return false; }
    this.confirmationRequested = false;
    return this.begin(current, false, false);
  }

  private async begin(current: JourneyPushSubscription, subscribed: boolean, pushEnabled: boolean): Promise<boolean> {
    if (this.owner.length === 0 || !this.active || this.busy || this.saving || this.needsSync || this.error.length > 0 ||
      this.command !== null || this.repository.updateJourneyPushSubscription === undefined) { return false; }
    this.cancelRead();
    this.command = new PushSubscriptionCommand(this.identity(), subscribed, pushEnabled, current.revision);
    this.pending = true;
    return this.retry();
  }

  async retry(): Promise<boolean> {
    const command: PushSubscriptionCommand | null = this.command;
    if (command === null || !this.active || this.saving || this.owner.length === 0 ||
      this.repository.updateJourneyPushSubscription === undefined) { return false; }
    const generation: number = this.generation;
    const activation: number = this.activation;
    this.saving = true;
    this.writeError = '';
    try {
      const receipt: JourneyPushSubscription = await this.repository.updateJourneyPushSubscription(command);
      if (generation !== this.generation || this.command !== command) { return false; }
      if (receipt.scope !== PERSONAL_JOURNEY_SCOPE || receipt.subscribed !== command.subscribed ||
        receipt.pushEnabled !== command.pushEnabled || receipt.revision < command.expectedRevision) {
        throw new GameFailure('CONTRACT_ERROR', '订阅结果尚未确认，请重试确认。');
      }
      this.command = null;
      this.pending = false;
      // A command receipt can predate another device's update. Only a fresh GET may publish current state.
      this.needsSync = true;
      this.subscription = null;
      this.loaded = false;
      this.confirmationAfterRead = this.active && activation === this.activation && receipt.subscribed && !receipt.pushEnabled;
      if (this.active) { await this.refresh(); }
      if (generation !== this.generation) { return false; }
      if (this.needsSync) { this.writeError = '操作已保存，当前订阅状态尚未同步，请重新读取。'; }
      return true;
    } catch (error) {
      if (generation !== this.generation || this.command !== command) { return false; }
      if (this.sessionFailure(error as Object)) { this.rejectSession(error as Object); return false; }
      this.writeError = this.message(error as Object);
      if (error instanceof GameFailure && error.status >= 400 && error.status < 500 &&
        error.status !== 408 && error.status !== 429) {
        this.command = null;
        this.pending = false;
        void this.refresh();
      }
      return false;
    } finally {
      if (generation === this.generation) { this.saving = false; }
    }
  }
}
