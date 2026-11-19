import { GameRepository } from '../business/GameRepository';
import { AssignmentSummary, GameFailure } from '../business/models';
import { PushSubscription, PushSubscriptionCommand, PushSubscriptionItem,
  PushSubscriptionList } from '../business/PushSubscription';
import { ReadCancellation } from '../business/ReadCancellation';
import { createRequestIdentity } from '../platform/RequestIdentity';

class PendingSubscription {
  readonly assignmentId: string;
  readonly command: PushSubscriptionCommand;
  constructor(assignmentId: string, command: PushSubscriptionCommand) {
    this.assignmentId = assignmentId;
    this.command = command;
  }
}

@ObservedV2
export class PushSubscriptionsViewModel {
  @Trace items: PushSubscriptionItem[] = [];
  @Trace loaded: boolean = false;
  @Trace busy: boolean = false;
  @Trace error: string = '';
  @Trace writeError: string = '';
  @Trace pendingId: string = '';
  @Trace saving: boolean = false;
  @Trace confirmationId: string = '';
  @Trace needsSync: boolean = false;
  private owner: string = '';
  private generation: number = 0;
  private active: boolean = false;
  private read: ReadCancellation | null = null;
  private pending: PendingSubscription | null = null;
  private confirmationAfterRead: string = '';
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
    this.items = [];
    this.loaded = false;
    this.error = '';
    this.writeError = '';
    this.pending = null;
    this.pendingId = '';
    this.saving = false;
    this.confirmationId = '';
    this.confirmationAfterRead = '';
    this.needsSync = false;
    this.active = false;
  }

  setActive(active: boolean): void {
    if (active === this.active) { return; }
    this.active = active;
    if (!active) {
      this.cancelRead();
      this.confirmationId = '';
    } else if (this.owner.length > 0 && this.pending === null) {
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
    if (this.owner.length === 0 || this.busy || this.pending !== null) { return; }
    if (this.repository.pushSubscriptions === undefined) {
      this.error = '当前版本暂不支持场次订阅。';
      return;
    }
    const generation: number = this.generation;
    const read: ReadCancellation = new ReadCancellation();
    this.read = read;
    this.busy = true;
    this.error = '';
    try {
      const summaries: AssignmentSummary[] = await this.repository.assignments(read);
      const list: PushSubscriptionList = await this.repository.pushSubscriptions(read);
      if (generation !== this.generation || this.read !== read || read.cancelled) { return; }
      const rows: PushSubscriptionItem[] = [];
      summaries.forEach((assignment: AssignmentSummary) => {
        const saved: PushSubscriptionItem | undefined = list.items.find((item: PushSubscriptionItem) =>
          item.assignmentId === assignment.id);
        if (assignment.status === 'cancelled' && saved?.subscribed !== true) { return; }
        const row: PushSubscriptionItem = new PushSubscriptionItem();
        row.assignmentId = assignment.id;
        row.title = assignment.title;
        row.available = assignment.status !== 'cancelled';
        if (saved !== undefined) {
          row.subscribed = saved.subscribed;
          row.pushEnabled = saved.pushEnabled;
          row.revision = saved.revision;
        }
        rows.push(row);
      });
      list.items.forEach((saved: PushSubscriptionItem) => {
        if (!saved.subscribed || rows.some((row: PushSubscriptionItem) => row.assignmentId === saved.assignmentId)) { return; }
        const historical: PushSubscriptionItem = new PushSubscriptionItem();
        historical.assignmentId = saved.assignmentId;
        historical.title = saved.title;
        historical.subscribed = saved.subscribed;
        historical.pushEnabled = saved.pushEnabled;
        historical.revision = saved.revision;
        historical.available = false;
        rows.push(historical);
      });
      this.items = rows;
      this.loaded = true;
      if (this.needsSync) { this.writeError = ''; }
      this.needsSync = false;
      if (this.confirmationAfterRead.length > 0) {
        const target: PushSubscriptionItem | null = this.item(this.confirmationAfterRead);
        if (this.active && target?.available && target.subscribed && !target.pushEnabled) {
          this.confirmationId = target.assignmentId;
        }
        this.confirmationAfterRead = '';
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

  item(id: string): PushSubscriptionItem | null {
    return this.items.find((item: PushSubscriptionItem) => item.assignmentId === id) ?? null;
  }

  dismissConfirmation(): void { this.confirmationId = ''; }

  async subscribe(id: string): Promise<boolean> {
    const row: PushSubscriptionItem | null = this.item(id);
    if (row === null || !row.available || row.subscribed) { return false; }
    return this.begin(row, true, false);
  }

  requestNotifications(id: string): void {
    const row: PushSubscriptionItem | null = this.item(id);
    if (this.active && !this.needsSync && this.error.length === 0 && this.pending === null &&
      row?.available && row.subscribed && !row.pushEnabled) {
      this.confirmationId = id;
    }
  }

  async confirmNotifications(id: string): Promise<boolean> {
    if (this.confirmationId !== id) { return false; }
    this.confirmationId = '';
    const row: PushSubscriptionItem | null = this.item(id);
    return row !== null && row.available && row.subscribed ? this.begin(row, true, true) : false;
  }

  async unsubscribe(id: string): Promise<boolean> {
    const row: PushSubscriptionItem | null = this.item(id);
    if (row === null || !row.subscribed) { return false; }
    this.confirmationId = '';
    return this.begin(row, false, false);
  }

  private async begin(row: PushSubscriptionItem, subscribed: boolean, pushEnabled: boolean): Promise<boolean> {
    if (this.owner.length === 0 || this.busy || this.needsSync || this.error.length > 0 ||
      this.pending !== null || this.repository.updatePushSubscription === undefined) {
      return false;
    }
    this.cancelRead();
    this.pending = new PendingSubscription(row.assignmentId,
      new PushSubscriptionCommand(this.identity(), subscribed, pushEnabled, row.revision));
    this.pendingId = row.assignmentId;
    return this.retry();
  }

  async retry(): Promise<boolean> {
    const pending: PendingSubscription | null = this.pending;
    if (pending === null || this.saving || this.owner.length === 0 ||
      this.repository.updatePushSubscription === undefined) { return false; }
    const generation: number = this.generation;
    this.saving = true;
    this.writeError = '';
    try {
      const receipt: PushSubscription = await this.repository.updatePushSubscription(pending.assignmentId, pending.command);
      if (generation !== this.generation || this.pending !== pending) { return false; }
      if (receipt.assignmentId !== pending.assignmentId || receipt.subscribed !== pending.command.subscribed ||
        receipt.pushEnabled !== pending.command.pushEnabled || receipt.revision <= pending.command.expectedRevision) {
        throw new GameFailure('CONTRACT_ERROR', '订阅结果尚未确认，请重试确认。');
      }
      this.pending = null;
      this.pendingId = '';
      // An idempotent receipt may predate a later update on another device. It confirms
      // this command, never the current subscription. Publish only a fresh server read.
      this.needsSync = true;
      this.items = [];
      this.loaded = false;
      this.confirmationAfterRead = receipt.subscribed && !receipt.pushEnabled ? receipt.assignmentId : '';
      await this.refresh();
      if (generation !== this.generation) { return false; }
      if (this.needsSync) { this.writeError = '操作已保存，当前订阅状态尚未同步，请重新读取。'; }
      return true;
    } catch (error) {
      if (generation !== this.generation || this.pending !== pending) { return false; }
      if (this.sessionFailure(error as Object)) { this.rejectSession(error as Object); return false; }
      this.writeError = this.message(error as Object);
      if (error instanceof GameFailure && error.status >= 400 && error.status < 500 &&
        error.status !== 408 && error.status !== 429) {
        this.pending = null;
        this.pendingId = '';
        void this.refresh();
      }
      return false;
    } finally {
      if (generation === this.generation) { this.saving = false; }
    }
  }
}
