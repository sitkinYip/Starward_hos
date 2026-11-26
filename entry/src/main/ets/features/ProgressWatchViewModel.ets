import { GameRepository } from '../business/GameRepository';
import { GameFailure } from '../business/models';
import {
  PROGRESS_EVENT_KINDS, ProgressWatch, ProgressWatchCommand, ProgressWatchDetail, ProgressWatchList
} from '../business/ProgressWatch';
import { ReadCancellation } from '../business/ReadCancellation';
import { createRequestIdentity } from '../platform/RequestIdentity';

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
  private pending: ProgressWatchCommand | null = null;
  private readonly repository: GameRepository;
  private readonly rejectSession: (error: Object) => void;

  constructor(repository: GameRepository, rejectSession: (error: Object) => void) {
    this.repository = repository;
    this.rejectSession = rejectSession;
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
      if (this.accessRead === read) { this.settingsVisible = (list?.items.length ?? 0) > 0; }
    } catch (error) {
      if (this.accessRead === read) { this.rejectSession(error as Object); }
    } finally {
      if (this.accessRead === read) { this.accessRead = null; }
    }
  }

  openPage(id: string, active: boolean): void {
    this.closePage();
    this.selectedId = id;
    this.setPageActive(active);
  }

  setPageActive(active: boolean): void {
    if (active === this.pageActive) { return; }
    this.pageActive = active;
    if (active) {
      void this.refresh();
    } else {
      this.cancelRead();
      this.detail = null;
      this.items = [];
    }
  }

  closePage(): void {
    this.generation++;
    this.pageActive = false;
    this.cancelRead();
    this.pending = null;
    this.retryPending = false;
    this.detail = null;
    this.items = [];
    this.draft = [];
    this.selectedId = '';
    this.saving = false;
    this.readError = '';
    this.writeError = '';
  }

  private cancelRead(): void {
    this.read?.cancel();
    this.read = null;
    this.loading = false;
  }

  select(id: string): void {
    if (id.length === 0 || this.saving || !this.pageActive) { return; }
    this.cancelRead();
    if (id !== this.selectedId) {
      this.pending = null;
      this.retryPending = false;
      this.writeError = '';
      this.detail = null;
      this.draft = [];
      this.selectedId = id;
    }
    void this.refresh();
  }

  async refresh(): Promise<void> {
    if (!this.pageActive || this.owner.length === 0 || this.loading || this.saving || this.pending !== null) { return; }
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
      this.items = list.items;
      const selected: ProgressWatch | undefined = this.selectedId.length > 0 ?
        list.items.find((item: ProgressWatch) => item.id === this.selectedId) : list.items[0];
      if (selected === undefined) {
        this.detail = null;
        this.readError = '该场次的进度授权已失效。';
        return;
      }
      this.selectedId = selected.id;
      const detail: ProgressWatchDetail = await this.repository.progressWatch(selected.id, read);
      if (this.read === read) { this.accept(detail); }
    } catch (error) {
      if (this.read !== read) { return; }
      this.detail = null;
      if (error instanceof GameFailure && error.status === 404) {
        this.items = this.items.filter((item: ProgressWatch) => item.id !== this.selectedId);
      }
      this.readError = this.errorMessage(error as Object);
      this.rejectSession(error as Object);
    } finally {
      if (this.read === read) {
        this.read = null;
        this.loading = false;
      }
    }
  }

  private accept(detail: ProgressWatchDetail, resetDraft: boolean = false): void {
    if (resetDraft || this.detail?.watch.id !== detail.watch.id || this.detail?.watch.revision !== detail.watch.revision) {
      this.draft = detail.watch.eventKinds.slice();
    }
    this.detail = detail;
  }

  private errorMessage(error: Object): string {
    return error instanceof Error && error.message.length > 0 ? error.message : '暂时无法读取场次进度，请重试。';
  }

  choose(kind: string, checked: boolean): void {
    if (this.saving || this.pending !== null || !PROGRESS_EVENT_KINDS.includes(kind)) { return; }
    this.draft = PROGRESS_EVENT_KINDS.filter((item: string) => item === kind ? checked : this.draft.includes(item));
  }

  saveSelection(): Promise<void> {
    if (this.draft.length === 0) { return Promise.resolve(); }
    return this.update(true, this.detail?.watch.pushEnabled ?? false, this.draft);
  }

  unsubscribe(): Promise<void> { return this.update(false, false, []); }

  setPush(id: string, revision: number, enabled: boolean): Promise<void> {
    const watch: ProgressWatch | undefined = this.detail?.watch;
    if (watch === undefined || watch.id !== id || watch.revision !== revision || !watch.subscribed) {
      return Promise.resolve();
    }
    return this.update(true, enabled, watch.eventKinds);
  }

  private update(subscribed: boolean, pushEnabled: boolean, eventKinds: string[]): Promise<void> {
    if (!this.pageActive || this.saving || this.loading || this.detail === null || this.pending !== null) {
      return Promise.resolve();
    }
    this.pending = new ProgressWatchCommand(createRequestIdentity(), this.detail.watch.revision,
      subscribed, pushEnabled, eventKinds);
    return this.retrySave();
  }

  async retrySave(): Promise<void> {
    const command: ProgressWatchCommand | null = this.pending;
    if (!this.pageActive || command === null || this.saving || this.repository.updateProgressWatch === undefined) { return; }
    const generation: number = this.generation;
    const id: string = this.selectedId;
    this.saving = true;
    this.retryPending = false;
    this.writeError = '';
    let reload: boolean = false;
    try {
      const detail: ProgressWatchDetail = await this.repository.updateProgressWatch(id, command);
      if (generation !== this.generation) { return; }
      this.pending = null;
      if (this.pageActive) { this.accept(detail, true); }
      reload = this.items.length === 0;
    } catch (error) {
      if (generation !== this.generation) { return; }
      const failure: Object = error as Object;
      this.writeError = this.errorMessage(failure);
      this.rejectSession(failure);
      if (generation !== this.generation) { return; }
      const status: number = failure instanceof GameFailure ? failure.status : 0;
      this.retryPending = status === 0 || status >= 500;
      if (!this.retryPending) { this.pending = null; }
      reload = status === 404 || status === 409;
    } finally {
      if (generation === this.generation) {
        this.saving = false;
        if (reload) { void this.refresh(); }
      }
    }
  }
}
