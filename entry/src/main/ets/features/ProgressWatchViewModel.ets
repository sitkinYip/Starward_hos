import { GameRepository } from '../business/GameRepository';
import { GameFailure, isPlayerSessionFailure } from '../business/models';
import {
  PROGRESS_EVENT_KINDS, ProgressWatch, ProgressWatchCommand, ProgressWatchDetail, ProgressWatchList
} from '../business/ProgressWatch';
import { ReadCancellation } from '../business/ReadCancellation';
import { createRequestIdentity } from '../platform/RequestIdentity';

const GRANT_UNAVAILABLE: string = '该场次的进度授权已失效。';
const MAX_TIMEOUT: number = 2147483647;

class ProgressWatchWrite {
  readonly command: ProgressWatchCommand;
  readonly resetDraft: boolean;

  constructor(command: ProgressWatchCommand, resetDraft: boolean) {
    this.command = command;
    this.resetDraft = resetDraft;
  }
}

function sameEvents(left: string[], right: string[]): boolean {
  return left.length === right.length && left.every((event: string) => right.includes(event));
}

@ObservedV2
export class ProgressWatchViewModel {
  @Trace settingsVisible: boolean = false;
  @Trace items: ProgressWatch[] = [];
  @Trace detail: ProgressWatchDetail | null = null;
  @Trace selectedId: string = '';
  @Trace draft: string[] = [];
  @Trace loading: boolean = false;
  @Trace saving: boolean = false;
  @Trace retryPending: boolean = false;
  @Trace readError: string = '';
  @Trace writeError: string = '';
  private owner: string = '';
  private generation: number = 0;
  private pageActive: boolean = false;
  private read: ReadCancellation | null = null;
  private accessRead: ReadCancellation | null = null;
  private pending: ProgressWatchWrite | null = null;
  private pushedTarget: string = '';
  private savedSelection: string[] | null = null;
  private settingsExpiryTimer: number = -1;
  private pageExpiryTimer: number = -1;
  private selectedExpiresAt: number | null = null;
  private readonly repository: GameRepository;
  private readonly rejectSession: (error: Object) => void;

  constructor(repository: GameRepository, rejectSession: (error: Object) => void) {
    this.repository = repository;
    this.rejectSession = rejectSession;
  }

  hasUnsavedSelection(): boolean {
    const watch: ProgressWatch | undefined = this.detail?.watch;
    return watch !== undefined && !sameEvents(this.draft, watch.eventKinds);
  }

  bindOwner(owner: string): void {
    if (owner === this.owner) { return; }
    this.owner = owner;
    this.closePage();
    this.setSettingsActive(false);
  }

  setSettingsActive(active: boolean): void {
    this.accessRead?.cancel();
    this.accessRead = null;
    clearTimeout(this.settingsExpiryTimer);
    this.settingsVisible = false;
    if (active && this.owner.length > 0 && this.repository.progressWatches !== undefined) {
      const read: ReadCancellation = new ReadCancellation();
      this.accessRead = read;
      void this.checkAccess(read);
    }
  }

  private async checkAccess(read: ReadCancellation): Promise<void> {
    try {
      const list: ProgressWatchList | undefined = await this.repository.progressWatches?.(read);
      if (this.accessRead === read) {
        let expiresAt: number = 0;
        for (const item of list?.items ?? []) {
          const expiry: number = Date.parse(item.expiresAt);
          if (expiry > expiresAt) { expiresAt = expiry; }
        }
        this.watchSettingsExpiry(expiresAt);
      }
    } catch (error) {
      if (this.accessRead === read && isPlayerSessionFailure(error as Object)) {
        this.rejectSession(error as Object);
      }
    } finally {
      if (this.accessRead === read) { this.accessRead = null; }
    }
  }

  private watchSettingsExpiry(expiresAt: number): void {
    const remaining: number = expiresAt - Date.now();
    this.settingsVisible = remaining > 0;
    if (this.settingsVisible) {
      this.settingsExpiryTimer = setTimeout(() => this.watchSettingsExpiry(expiresAt), Math.min(remaining, MAX_TIMEOUT));
    }
  }

  openPage(active: boolean): void {
    const target: string = this.pushedTarget;
    this.closePage();
    this.selectedId = target;
    this.setPageActive(active);
  }

  setPageActive(active: boolean): void {
    if (active === this.pageActive) { return; }
    this.pageActive = active;
    if (active) {
      this.watchPageExpiry();
      if (!this.openPushedTarget()) { void this.refresh(); }
    } else {
      this.cancelRead();
      this.detail = null;
      this.items = [];
      this.watchPageExpiry();
    }
  }

  closePage(): void {
    this.generation++;
    this.pageActive = false;
    this.cancelRead();
    this.items = [];
    this.pushedTarget = '';
    this.clearSelection();
    clearTimeout(this.pageExpiryTimer);
    this.selectedId = '';
    this.saving = false;
    this.readError = '';
  }

  private cancelRead(): void {
    this.read?.cancel();
    this.read = null;
    this.loading = false;
  }

  selectFromPush(id: string, destinationOnTop: boolean): void {
    if (id.length === 0 || this.owner.length === 0) { return; }
    this.pushedTarget = id;
    if (destinationOnTop) { this.openPushedTarget(); }
  }

  private openPushedTarget(): boolean {
    if (this.pushedTarget.length === 0 || this.saving || !this.pageActive) { return false; }
    const id: string = this.pushedTarget;
    this.pushedTarget = '';
    this.select(id);
    return true;
  }

  select(id: string): void {
    if (id.length === 0 || this.saving || !this.pageActive) { return; }
    this.cancelRead();
    if (id !== this.selectedId) {
      this.clearSelection();
      this.selectedId = id;
      this.watchPageExpiry();
    }
    void this.loadSelection();
  }

  async refresh(): Promise<void> {
    if (this.pending === null) { await this.loadSelection(); }
  }

  private async loadSelection(): Promise<void> {
    if (!this.pageActive || this.owner.length === 0 || this.loading || this.saving) { return; }
    this.watchPageExpiry();
    if (this.repository.progressWatches === undefined || this.repository.progressWatch === undefined) {
      this.readError = '当前服务暂未提供进度订阅。';
      return;
    }
    const read: ReadCancellation = new ReadCancellation();
    this.read = read;
    this.loading = true;
    this.readError = '';
    try {
      const list: ProgressWatchList = await this.repository.progressWatches(read);
      if (this.read !== read) { return; }
      const now: number = Date.now();
      this.items = list.items.filter((item: ProgressWatch) => Date.parse(item.expiresAt) > now);
      const selected: ProgressWatch | undefined = this.selectedId.length > 0 ?
        this.items.find((item: ProgressWatch) => item.id === this.selectedId) : this.items[0];
      if (selected === undefined) {
        this.clearExpiredSelection();
        this.watchPageExpiry();
        return;
      }
      this.selectedId = selected.id;
      this.selectedExpiresAt = Date.parse(selected.expiresAt);
      this.watchPageExpiry();
      if (this.read !== read) { return; }
      const detail: ProgressWatchDetail = await this.repository.progressWatch(selected.id, read);
      if (this.read !== read) { return; }
      this.watchPageExpiry();
      if (this.read === read) { this.accept(detail); }
    } catch (error) {
      if (this.read !== read) { return; }
      this.detail = null;
      if (error instanceof GameFailure && error.status === 404) {
        this.clearExpiredSelection();
        this.watchPageExpiry();
      }
      this.readError = this.errorMessage(error as Object);
      if (isPlayerSessionFailure(error as Object)) { this.rejectSession(error as Object); }
    } finally {
      if (this.read === read) {
        this.read = null;
        this.loading = false;
      }
    }
  }

  private clearSelection(): void {
    this.selectedExpiresAt = null;
    this.pending = null;
    this.retryPending = false;
    this.writeError = '';
    this.detail = null;
    this.savedSelection = null;
    this.draft = [];
  }

  private clearExpiredSelection(): void {
    this.clearSelection();
    this.items = this.items.filter((item: ProgressWatch) => item.id !== this.selectedId);
    this.readError = GRANT_UNAVAILABLE;
  }

  private watchPageExpiry(): void {
    clearTimeout(this.pageExpiryTimer);
    const now: number = Date.now();
    if (this.selectedExpiresAt !== null && this.selectedExpiresAt <= now) {
      this.cancelRead();
      this.clearExpiredSelection();
    }
    let nextExpiry: number = this.selectedExpiresAt ?? Number.POSITIVE_INFINITY;
    const validItems: ProgressWatch[] = this.items.filter((item: ProgressWatch) => {
      const expiry: number = Date.parse(item.expiresAt);
      if (expiry > now) {
        nextExpiry = Math.min(nextExpiry, expiry);
        return true;
      }
      return false;
    });
    if (validItems.length !== this.items.length) { this.items = validItems; }
    if (Number.isFinite(nextExpiry)) {
      this.pageExpiryTimer = setTimeout(() => this.watchPageExpiry(), Math.min(nextExpiry - now, MAX_TIMEOUT));
    }
  }

  private accept(detail: ProgressWatchDetail, resetDraft: boolean = false): void {
    this.selectedExpiresAt = Date.parse(detail.watch.expiresAt);
    if (!(this.selectedExpiresAt > Date.now())) {
      this.clearExpiredSelection();
      this.watchPageExpiry();
      return;
    }
    if (resetDraft || this.savedSelection === null || sameEvents(this.draft, this.savedSelection)) {
      this.draft = detail.watch.eventKinds.slice();
    }
    this.savedSelection = detail.watch.eventKinds.slice();
    this.items = this.items.map((item: ProgressWatch) => item.id === detail.watch.id ? detail.watch : item);
    this.detail = detail;
    this.watchPageExpiry();
  }

  private errorMessage(error: Object): string {
    return error instanceof Error && error.message.length > 0 ? error.message : '暂时无法读取场次进度，请重试。';
  }

  choose(kind: string, checked: boolean): void {
    if (this.detail === null || this.saving || this.pending !== null || !PROGRESS_EVENT_KINDS.includes(kind)) { return; }
    this.draft = PROGRESS_EVENT_KINDS.filter((item: string) => item === kind ? checked : this.draft.includes(item));
  }

  saveSelection(): Promise<void> {
    if (this.draft.length === 0) { return Promise.resolve(); }
    return this.update(true, this.detail?.watch.pushEnabled ?? false, this.draft);
  }

  unsubscribe(): Promise<void> { return this.update(false, false, []); }

  setPush(id: string, revision: number, enabled: boolean): Promise<void> {
    const watch: ProgressWatch | undefined = this.detail?.watch;
    if (watch === undefined || watch.id !== id || watch.revision !== revision || !watch.subscribed ||
      (enabled && (this.hasUnsavedSelection() || this.detail?.pushAvailable !== true))) {
      return Promise.resolve();
    }
    return this.update(true, enabled, watch.eventKinds, false);
  }

  private update(subscribed: boolean, pushEnabled: boolean, eventKinds: string[], resetDraft: boolean = true): Promise<void> {
    this.watchPageExpiry();
    if (!this.pageActive || this.saving || this.loading || this.detail === null || this.pending !== null) {
      return Promise.resolve();
    }
    this.pending = new ProgressWatchWrite(new ProgressWatchCommand(createRequestIdentity(), this.detail.watch.revision,
      subscribed, pushEnabled, eventKinds), resetDraft);
    return this.retrySave();
  }

  async retrySave(): Promise<void> {
    this.watchPageExpiry();
    const write: ProgressWatchWrite | null = this.pending;
    if (!this.pageActive || write === null || this.saving || this.loading ||
      this.repository.updateProgressWatch === undefined) { return; }
    const generation: number = this.generation;
    const id: string = this.selectedId;
    this.saving = true;
    this.retryPending = false;
    this.writeError = '';
    let reload: boolean = false;
    try {
      const detail: ProgressWatchDetail = await this.repository.updateProgressWatch(id, write.command);
      if (generation !== this.generation) { return; }
      this.watchPageExpiry();
      if (this.pending !== write) { return; }
      this.pending = null;
      if (this.pageActive) { this.accept(detail, write.resetDraft); }
      else if (write.resetDraft) { this.savedSelection = null; }
      reload = this.items.length === 0;
    } catch (error) {
      if (generation !== this.generation) { return; }
      const failure: Object = error as Object;
      if (isPlayerSessionFailure(failure)) { this.rejectSession(failure); }
      if (generation !== this.generation) { return; }
      this.watchPageExpiry();
      if (this.pending !== write) { return; }
      this.writeError = this.errorMessage(failure);
      const status: number = failure instanceof GameFailure ? failure.status : 0;
      this.retryPending = status === 0 || status >= 500;
      if (!this.retryPending) { this.pending = null; }
      if (status === 404) {
        this.clearExpiredSelection();
        this.watchPageExpiry();
      }
      reload = status === 404 || status === 409;
    } finally {
      if (generation === this.generation) {
        this.saving = false;
        if (!this.openPushedTarget() && reload) { void this.refresh(); }
      }
    }
  }
}
