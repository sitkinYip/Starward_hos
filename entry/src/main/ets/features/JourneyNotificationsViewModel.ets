import { GameNotification } from '../business/GameNotification';
import { GameRepository } from '../business/GameRepository';
import { ReadCancellation } from '../business/ReadCancellation';
import { GameFailure } from '../business/models';

const POLL_MS: number = 5000;

@ObservedV2
export class JourneyNotificationsViewModel {
  @Trace entries: GameNotification[] = [];
  @Trace loading: boolean = false;
  @Trace error: string = '';
  @Trace activeNotificationId: string = '';
  @Trace readingId: string = '';
  @Trace readErrorId: string = '';
  @Trace readErrorMessage: string = '';
  @Trace gameplayReady: boolean = false;
  private owner: string = '';
  private generation: number = 0;
  private pending: ReadCancellation | null = null;
  private timer: number = -1;
  private readonly repository: GameRepository;
  private readonly expireSession: (message: string) => void;

  constructor(repository: GameRepository, expireSession: (message: string) => void) {
    this.repository = repository;
    this.expireSession = expireSession;
  }

  get unreadCount(): number {
    return this.entries.filter((note: GameNotification) => note.readAt.length === 0).length;
  }

  get current(): GameNotification | null {
    return this.entries.find((note: GameNotification) => note.id === this.activeNotificationId) ?? null;
  }

  get oldestUnread(): GameNotification | null {
    // The service orders receipts newest-first, including ties.
    for (let index: number = this.entries.length - 1; index >= 0; index--) {
      if (this.entries[index].readAt.length === 0) { return this.entries[index]; }
    }
    return null;
  }

  bindOwner(owner: string): void {
    if (owner === this.owner) { return; }
    this.owner = owner;
    this.generation++;
    this.suspend();
    this.entries = [];
    this.error = '';
    this.readingId = '';
    this.readErrorId = '';
    this.readErrorMessage = '';
  }

  setPolling(active: boolean): void {
    if (active && this.owner.length > 0) {
      if (this.timer === -1) {
        this.timer = setInterval(() => { this.load(false); }, POLL_MS);
      }
    } else if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
      this.gameplayReady = false;
      this.cancelRead();
    }
  }

  suspend(): void {
    this.pauseReads();
    this.close();
  }

  pauseReads(): void {
    this.setPolling(false);
    this.cancelRead();
  }

  open(id: string): void {
    if (this.owner.length > 0 && this.entries.some((note: GameNotification) => note.id === id)) {
      this.activeNotificationId = id;
    }
  }

  close(): void {
    this.activeNotificationId = '';
  }

  async refresh(): Promise<void> {
    await this.load(true);
  }

  async markRead(id: string): Promise<boolean> {
    if (this.owner.length === 0 || this.readingId.length > 0) { return false; }
    const note: GameNotification | undefined = this.entries.find((item: GameNotification) => item.id === id);
    if (note === undefined) { return false; }
    if (note.readAt.length > 0) { return true; }

    // Supersede a GET started before the receipt write, so it cannot restore an old unread state.
    this.cancelRead();
    const generation: number = this.generation;
    this.readingId = id;
    this.readErrorId = '';
    this.readErrorMessage = '';
    try {
      const readAt: string = await this.repository.readNotification(id);
      if (generation !== this.generation) { return false; }
      this.entries = this.entries.map((item: GameNotification) => item.id === id ? item.withReadAt(readAt) : item);
      return true;
    } catch (error) {
      if (generation === this.generation && !this.endExpiredSession(error as Object)) {
        this.readErrorId = id;
        this.readErrorMessage = this.message(error as Object, '已读状态暂时无法保存，请重试。');
      }
      return false;
    } finally {
      if (generation === this.generation) { this.readingId = ''; }
    }
  }

  private async load(manual: boolean): Promise<void> {
    if (this.owner.length === 0 || this.pending !== null || this.readingId.length > 0) { return; }
    const attempt: ReadCancellation = new ReadCancellation();
    this.pending = attempt;
    if (manual) {
      this.loading = true;
      this.error = '';
    }
    try {
      const entries: GameNotification[] = await this.repository.notifications(attempt);
      if (this.pending !== attempt) { return; }
      this.entries = entries;
      this.error = '';
      if (!manual && this.timer !== -1) { this.gameplayReady = true; }
      if (this.activeNotificationId.length > 0 &&
        !entries.some((note: GameNotification) => note.id === this.activeNotificationId)) { this.close(); }
    } catch (error) {
      if (this.pending === attempt && !this.endExpiredSession(error as Object) && manual) {
        this.error = this.message(error as Object, '来信暂时无法读取，请重试。');
      }
    } finally {
      if (this.pending === attempt) {
        this.pending = null;
        this.loading = false;
      }
    }
  }

  private cancelRead(): void {
    const pending: ReadCancellation | null = this.pending;
    this.pending = null;
    pending?.cancel();
    this.loading = false;
  }

  private endExpiredSession(error: Object): boolean {
    if (!(error instanceof GameFailure) || (error.status !== 401 && error.code !== 'ACCOUNT_DISABLED' &&
      error.code !== 'PASSWORD_CHANGE_REQUIRED')) { return false; }
    this.bindOwner('');
    this.expireSession(this.message(error, '请重新登录。'));
    return true;
  }

  private message(error: Object, fallback: string): string {
    return error instanceof Error && error.message.length > 0 ? error.message : fallback;
  }
}
